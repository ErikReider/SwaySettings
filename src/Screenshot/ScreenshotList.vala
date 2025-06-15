[GtkTemplate (ui = "/org/erikreider/swaysettings/ui/ScreenshotList.ui")]
public class ScreenshotList : Adw.Bin {
    public const uint ANIMATION_DURATION = 300;

    private unowned ScreenshotWindow window;

    [GtkChild]
    unowned Gtk.Overlay overlay;
    [GtkChild]
    unowned Gtk.Fixed fixed;
    [GtkChild]
    unowned Gtk.Box box;
    [GtkChild]
    unowned Gtk.ScrolledWindow scrolled_window;
    [GtkChild]
    unowned Gtk.Viewport viewport;

    private bool input_region_dirty = false;

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
        ScreenshotPreview preview = new ScreenshotPreview (window, rect,
                                                           animate_value_cb,
                                                           animate_done_cb);
        fixed.put (preview, 0, 0);
        // Take the screenshot and wait
        if (!preview.set_texture (grim_screenshot_rect (rect))) {
            stderr.printf ("Unable to screenshot!\n");
            fixed.remove (preview);
            return;
        }
        preview.start_animation ();
    }

    private Graphene.Size animate_value_cb (ScreenshotPreview preview,
                                            double value) {
        Gtk.Border margin = preview.get_style_context ().get_margin ();

        Graphene.Rect init_rect = preview.init_rect;
        Graphene.Rect dst_rect = preview.dst_rect;

        double width = Adw.lerp (init_rect.get_width (), dst_rect.get_width (),
                                 value);
        double height = Adw.lerp (init_rect.get_height (),
                                  dst_rect.get_height (), value);
        double x = Adw.lerp (init_rect.get_x (),
                             dst_rect.get_x () - margin.right, value);
        double y = Adw.lerp (init_rect.get_y (),
                             dst_rect.get_y () - margin.bottom, value);

        if (preview.parent == fixed) {
            fixed.move (preview, x - margin.left, y - margin.top);
        }

        return Graphene.Size ().init (
            (float) width + margin.left + margin.right,
            (float) height + margin.top + margin.bottom);
    }

    private void animate_done_cb (ScreenshotPreview preview) {
        preview_widgets.append (preview);

        // Setting the input region here will cause the region to be
        // outdated due to the new positions not being set yet.
        // So wait until the widget is drawn.
        input_region_dirty = true;

        fixed.remove (preview);
        box.append (preview);
        viewport.vadjustment.set_value (0.0);
    }
}
