[GtkTemplate (ui = "/org/erikreider/swaysettings/ui/ScreenshotList.ui")]
public class ScreenshotList : Adw.Bin {
    private unowned ScreenshotWindow window;

    [GtkChild]
    unowned Gtk.Overlay overlay;

    [GtkChild]
    unowned Gtk.Fixed fixed;

    [GtkChild]
    unowned Gtk.ScrolledWindow scrolled_window;
    [GtkChild]
    unowned Gtk.Viewport viewport;
    [GtkChild]
    unowned Gtk.Box box;

    private bool input_region_dirty = false;

    private uint scroll_bottom_id = 0;
    private double scroll_bottom_value = 0;

    List<ScreenshotPreview> preview_widgets = new List<ScreenshotPreview> ();

    public uint num_screenshots {
        get {
            return preview_widgets.length ();
        }
    }

    public ScreenshotList (ScreenshotWindow window) {
        this.window = window;

        overlay.set_clip_overlay (fixed, false);
        overlay.set_measure_overlay (fixed, true);

        viewport.vadjustment.value_changed.connect (() => {
            // Setting the input region here will cause the region to be
            // outdated due to the new positions not being set yet.
            // So wait until the widget is drawn.
            input_region_dirty = true;
            queue_allocate ();
        });
    }

    protected override void snapshot (Gtk.Snapshot snapshot) {
        // HACK: Fixes fully transparent windows not being mapped
        Gdk.RGBA color = Gdk.RGBA () {
            red = 0,
            green = 0,
            blue = 0,
            alpha = 0,
        };
        snapshot.append_color (color, Graphene.Rect.zero ());

        // Update the input region if dirty
        if (input_region_dirty) {
            input_region_dirty = false;
            set_input_region ();
        }

        base.snapshot (snapshot);
    }

    private Cairo.RectangleInt[] get_rects () {
        Cairo.RectangleInt[] rects = {
            // Empty rect as fallback if there are no previews in the box
            Cairo.RectangleInt () {
                x = 0, y = 0, width = 0, height = 0,
            }
        };

        foreach (ScreenshotPreview preview in preview_widgets) {
            Graphene.Rect out_bounds;
            preview.compute_bounds (this, out out_bounds);
            Cairo.RectangleInt rect = Cairo.RectangleInt () {
                x = (int) out_bounds.get_x (),
                y = (int) out_bounds.get_y (),
                width = (int) out_bounds.get_width (),
                height = (int) out_bounds.get_height (),
            };

            rects += rect;
        }

        // Add the whole scrollbar edge + minWidth region to be able to scroll
        // anywhere without any gaps
        if (rects.length > 0
            && box.get_height () > scrolled_window.get_height ()) {
            Graphene.Rect out_bounds;
            scrolled_window.compute_bounds (this, out out_bounds);
            Cairo.RectangleInt rect = Cairo.RectangleInt () {
                x = (int) out_bounds.get_x (),
                y = (int) out_bounds.get_y (),
                width = (int) out_bounds.get_width (),
                height = (int) out_bounds.get_height (),
            };
            switch (scrolled_window.get_placement ()) {
                case Gtk.CornerType.TOP_LEFT:
                case Gtk.CornerType.BOTTOM_LEFT:
                    // Scroll bar on the right side
                    rect.x += rect.width - ScreenshotPreview.MIN_SIZE;
                    rect.width = ScreenshotPreview.MIN_SIZE;
                    break;
                case Gtk.CornerType.TOP_RIGHT:
                case Gtk.CornerType.BOTTOM_RIGHT:
                    // Scroll bar on the left side
                    rect.width = ScreenshotPreview.MIN_SIZE;
                    break;
            }
            rects += rect;
        }

        return rects;
    }

    public void set_input_region () {
        unowned Gdk.Surface ?surface = window.get_surface ();
        if (surface == null) {
            return;
        }

        // The input region should only cover each preview widget
        Cairo.RectangleInt[] rects = get_rects ();
        surface.set_input_region (new Cairo.Region.rectangles (rects));
    }

    public void add_preview (Graphene.Rect rect) {
        // Take the screenshot and wait
        Gdk.Texture ?texture = grim_screenshot_rect (rect);
        if (texture == null) {
            stderr.printf ("Unable to screenshot!\n");
            return;
        }

        ScreenshotPreview fixed_preview = new ScreenshotPreview.fixed (window);
        ScreenshotPreview list_preview = new ScreenshotPreview.list (window,
                                                                     preview_close_cb);

        Graphene.Rect init_rect = Graphene.Rect ()
                                  .init_from_rect (rect)
                                  .offset (-window.monitor.geometry.x,
                                           -window.monitor.geometry.y);
        Graphene.Rect dst_rect = ScreenshotPreview.calculate_dst_rect (window,
                                                                       init_rect);
        Gtk.Adjustment scroll_start_value = viewport.vadjustment;

        Adw.CallbackAnimationTarget target = new Adw.CallbackAnimationTarget (
            (value) => {
            animate_value_cb (fixed_preview, list_preview,
                              init_rect, dst_rect,
                              scroll_start_value, value);
        });
        Adw.TimedAnimation animation = new Adw.TimedAnimation (this, 0.0, 1.0,
                                                               ANIMATION_DURATION,
                                                               target);
        animation.set_easing (Adw.Easing.EASE_IN);
        animation.done.connect ((value) => {
            list_preview.set_opacity (1.0);

            // Setting the input region here will cause the region to be
            // outdated due to the new positions not being set yet.
            // So wait until the widget is drawn.
            input_region_dirty = true;

            fixed.remove (fixed_preview);

            list_preview.add_timer ();
        });

        fixed_preview.set_texture (texture);
        list_preview.set_texture (texture);

        fixed.put (fixed_preview, init_rect.get_x (), init_rect.get_y ());
        box.append (list_preview);

        preview_widgets.append (list_preview);

        // Ensures the animation starts after GTK recalculates the layout and
        // both widgets are mapped
        Idle.add_once (() => {
            animation.play ();
        });
    }

    private void animate_value_cb (ScreenshotPreview fixed_preview,
                                   ScreenshotPreview list_preview,
                                   Graphene.Rect init_rect,
                                   Graphene.Rect dst_rect,
                                   Gtk.Adjustment scroll_start_adj,
                                   double value) {
        Gtk.Border fixed_margin =
            fixed_preview.get_style_context ().get_margin ();
        Gtk.Border list_margin =
            list_preview.get_style_context ().get_margin ();

        //
        // Fixed Preview Hero animation
        //
        double fixed_width = Adw.lerp (init_rect.get_width (),
                                       dst_rect.get_width (), value);
        double fixed_height = Adw.lerp (init_rect.get_height (),
                                        dst_rect.get_height (), value);
        double fixed_x = Adw.lerp (init_rect.get_x (),
                                   dst_rect.get_x () - fixed_margin.right -
                                   list_margin.right, value);
        double fixed_y = Adw.lerp (init_rect.get_y (),
                                   dst_rect.get_y () - fixed_margin.bottom -
                                   list_margin.bottom, value);

        fixed.move (fixed_preview, fixed_x - fixed_margin.left,
                    fixed_y - fixed_margin.top);

        fixed_preview.set_size_request ((int) fixed_width + fixed_margin.left +
                                        fixed_margin.right,
                                        (int) fixed_height + fixed_margin.top +
                                        fixed_margin.bottom);
        fixed_preview.header_bar.set_opacity (value);

        //
        // List Preview expand animation
        //
        double list_width = dst_rect.get_width () + list_margin.left +
                            list_margin.right;
        double list_height = Adw.lerp (0, dst_rect.get_height (),
                                       value) + list_margin.top +
                             list_margin.bottom;

        list_preview.set_size_request ((int) list_width,
                                       (int) list_height);

        // Scroll to the bottom preview
        double scroll_value = Adw.lerp (scroll_start_adj.value,
                                        scroll_start_adj.upper -
                                        scroll_start_adj.page_size +
                                        list_height,
                                        value);
        scroll_to_bottom (scroll_value);
    }

    private void scroll_to_bottom (double scroll_value) {
        if (scroll_bottom_id != 0) {
            Source.remove (scroll_bottom_id);
            scroll_bottom_id = 0;
        }

        // HACK: To avoid a weird segfault when accessing local variables
        // in the Idle callback...
        scroll_bottom_value = scroll_value;
        // Ensures the scroll happens after GTK recalculates the layout
        scroll_bottom_id = Idle.add_once (() => {
            scroll_bottom_id = 0;
            Gtk.Adjustment vadjustment = viewport.get_vadjustment ();
            vadjustment.set_value (scroll_bottom_value);
        });
    }

    private void preview_close_cb (ScreenshotPreview preview) {
        // TODO: Save image? Maybe a dialog making sure if the user hasn't
        // saved or copied the screenshot?
        box.remove (preview);
        preview_widgets.remove (preview);
        preview.destroy ();

        // Setting the input region here will cause the region to be
        // outdated due to the new positions not being set yet.
        // So wait until the widget is drawn.
        input_region_dirty = true;
        queue_allocate ();

        // Also close the whole application if there are no visible previews left
        try_hide_all (true);
    }
}
