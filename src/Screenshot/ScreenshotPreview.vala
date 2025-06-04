private class AnimationProgress : Object {
    public double progress { get; set; }

    public AnimationProgress (double progress) {
        Object (progress: progress);
    }
}

public class ScreenshotPreview : Gtk.Fixed {
    public const uint ANIMATION_DURATION = 300;
    public const uint TIMEOUT_S = 10;

    private unowned ScreenshotWindow window;

    private Gtk.Overlay overlay;
    private Gtk.Picture picture;

    private Adw.TimedAnimation animation;
    private Adw.AnimationTarget target;

    private Cairo.Rectangle init_rect;
    private Cairo.Rectangle dst_rect;

    private Gtk.GestureClick overlay_click = new Gtk.GestureClick ();
    private Gtk.EventControllerMotion motion_controller =
        new Gtk.EventControllerMotion ();

    private AnimationProgress animation_progress = new AnimationProgress (0.0);

    private int hide_id = -1;

    public ScreenshotPreview (ScreenshotWindow window) {
        this.window = window;

        overlay = new Gtk.Overlay ();
        overlay.add_css_class ("screenshot-preview");
        overlay.set_overflow (Gtk.Overflow.HIDDEN);
        overlay.set_cursor_from_name ("pointer");
        overlay.add_controller (overlay_click);
        overlay_click.released.connect (picture_button_click_cb);
        overlay.add_controller (motion_controller);
        motion_controller.enter.connect (remove_timer);
        motion_controller.leave.connect (add_timer);
        put (overlay, 0, 0);

        picture = new Gtk.Picture ();
        picture.add_css_class ("screenshot-preview-picture");
        overlay.set_child (picture);

        Gtk.Image image_overlay =
            new Gtk.Image.from_icon_name ("text-editor-symbolic");
        image_overlay.add_css_class ("screenshot-image-overlay");
        image_overlay.set_pixel_size (32);
        image_overlay.set_valign (Gtk.Align.FILL);
        image_overlay.set_halign (Gtk.Align.FILL);
        image_overlay.set_vexpand (true);
        image_overlay.set_hexpand (true);
        overlay.add_overlay (image_overlay);

        Adw.HeaderBar header_bar = new Adw.HeaderBar ();
        animation_progress.bind_property ("progress",
                                          header_bar, "opacity",
                                          BindingFlags.SYNC_CREATE);
        header_bar.set_show_title (false);
        header_bar.set_show_back_button (false);
        header_bar.add_css_class ("flat");
        header_bar.set_hexpand (true);
        header_bar.set_halign (Gtk.Align.FILL);
        header_bar.set_vexpand (false);
        header_bar.set_valign (Gtk.Align.START);
        overlay.add_overlay (header_bar);

        bool left_aligned;
        header_bar.set_decoration_layout (get_decoration_layout (
                                              out left_aligned));

        Gtk.Button save_button =
            new Gtk.Button.from_icon_name ("document-save-symbolic");
        save_button.add_css_class ("circular");
        save_button.add_css_class ("flat");
        save_button.set_halign (Gtk.Align.END);
        save_button.clicked.connect (save_button_click_cb);
        if (left_aligned) {
            header_bar.pack_end (save_button);
        } else {
            header_bar.pack_start (save_button);
        }

        Gtk.Button copy_button =
            new Gtk.Button.from_icon_name ("edit-copy-symbolic");
        copy_button.add_css_class ("circular");
        copy_button.add_css_class ("flat");
        copy_button.set_halign (Gtk.Align.END);
        copy_button.clicked.connect (copy_button_click_cb);
        if (left_aligned) {
            header_bar.pack_end (copy_button);
        } else {
            header_bar.pack_start (copy_button);
        }

        target = new Adw.CallbackAnimationTarget (animate_value_cb);
        animation = new Adw.TimedAnimation (this, 0.0, 1.0, ANIMATION_DURATION,
                                            target);
        animation.set_easing (Adw.Easing.EASE_IN);
        animation.done.connect (() => {
            Gtk.Border margin = overlay.get_style_context ().get_margin ();
            Cairo.Rectangle rect = Cairo.Rectangle () {
                x = dst_rect.x - margin.right,
                y = dst_rect.y - margin.bottom,
                width = dst_rect.width,
                height = dst_rect.height,
            };
            set_input_region (rect);

            add_timer ();
        });

        map.connect (begin);
    }

    private void add_timer () {
        remove_timer ();
        hide_id = (int) Timeout.add_seconds_once (TIMEOUT_S, () => {
            hide_id = -1;
            // TODO:
            print ("TIMEOUT!\n");
        });
    }

    private void remove_timer () {
        if (hide_id > -1) {
            Source.remove (hide_id);
            hide_id = -1;
        }
    }

    private string ? get_decoration_layout (out bool left_aligned) {
        left_aligned = false;

        unowned Gtk.Settings?g_settings = Gtk.Settings.get_default ();
        if (g_settings == null) {
            return null;
        }

        string decoration = g_settings.gtk_decoration_layout;
        if (!decoration.contains (":")) {
            return null;
        }

        string[] split = decoration.split (":");
        string start = "";
        string end = "";
        if ("close" in split[0]) {
            start = "close";
            left_aligned = true;
        }
        if ("close" in split[1]) {
            end = "close";
            left_aligned = false;
        }

        if (start.length + end.length == 0) {
            return null;
        }
        return "%s:%s".printf (start, end);
    }

    private void begin () {
        Graphene.Rect rect = Graphene.Rect ().init (
            (int) start_x, (int) start_y,
            (int) offset_x, (int) offset_y);

        init_rect = Cairo.Rectangle () {
            x = rect.get_x () - window.monitor.geometry.x,
            y = rect.get_y () - window.monitor.geometry.y,
            width = rect.get_width (),
            height = rect.get_height (),
        };

        const double MON_SCALE = 0.1;
        double max_preview_size_width =
            Math.fmax (window.monitor.geometry.width * MON_SCALE, 300);
        double max_preview_size_height =
            Math.fmax (window.monitor.geometry.height * MON_SCALE, 300);

        double dst_width = init_rect.width;
        double dst_height = init_rect.height;
        double ratio = init_rect.width / init_rect.height;
        if (ratio > 1.0) {
            // Wide
            double scale = dst_width / max_preview_size_width;
            dst_height = (init_rect.height / scale);
        } else if (ratio < 1.0) {
            // Tall
            double scale = dst_height / max_preview_size_height;
            dst_width = (init_rect.width / scale);
        }
        dst_width = Math.fmin (dst_width, max_preview_size_width);
        dst_height = Math.fmin (dst_height, max_preview_size_height);

        dst_rect = Cairo.Rectangle () {
            x = window.monitor.geometry.width - dst_width,
            y = window.monitor.geometry.height - dst_height,
            width = dst_width,
            height = dst_height,
        };

        animation.play ();
    }

    private void animate_value_cb (double value) {
        this.animation_progress.progress = value;

        Gtk.Border margin = overlay.get_style_context ().get_margin ();

        double width = Adw.lerp (init_rect.width, dst_rect.width, value);
        double height = Adw.lerp (init_rect.height, dst_rect.height, value);
        double x = Adw.lerp (init_rect.x, dst_rect.x - margin.right, value);
        double y = Adw.lerp (init_rect.y, dst_rect.y - margin.bottom, value);

        move (overlay, x - margin.left, y - margin.top);
        overlay.set_size_request (
            (int) width + margin.left + margin.right,
            (int) height + margin.top + margin.bottom);

        set_input_region (null);
    }

    private void set_input_region (Cairo.Rectangle ?rect) {
        // The input region should only cover the preview window
        unowned Gdk.Surface ?surface = window.get_surface ();
        if (surface != null) {
            Cairo.RectangleInt rect_int;
            if (rect != null) {
                rect_int = Cairo.RectangleInt () {
                    x = (int) rect.x,
                    y = (int) rect.y,
                    width = (int) rect.width,
                    height = (int) rect.height,
                };
            } else {
                rect_int = Cairo.RectangleInt () {
                    x = 0, y = 0, width = 0, height = 0,
                };
            }
            Cairo.Region region = new Cairo.Region.rectangle (rect_int);
            surface.set_input_region (region);
        }
    }

    // TODO:
    private void picture_button_click_cb (int n_press,
                                          double x,
                                          double y) {
        print ("PIC CLICK!\n");
    }

    // TODO:
    private void save_button_click_cb (Gtk.Button button) {
        print ("Save CLICK!\n");
    }

    // TODO:
    private void copy_button_click_cb (Gtk.Button button) {
        print ("Copy CLICK!\n");
    }

    public bool set_texture (Gdk.Texture ?texture) {
        if (texture == null) {
            return false;
        }

        picture.set_paintable (texture);
        picture.set_content_fit (Gtk.ContentFit.CONTAIN);
        return true;
    }
}
