namespace SwaySettings {
    public enum ThemeStyle {
        DEFAULT, DARK;

        public string to_string () {
            switch (this) {
                default:
                case DEFAULT:
                    return "Light";
                case DARK:
                    return "Dark";
            }
        }

        public string get_preview_class (bool front) {
            switch (this) {
                default:
                case DEFAULT:
                    if (!front) return "dark";
                    return "light";
                case DARK:
                    return "dark";
            }
        }

        public string get_gsettings_name () {
            switch (this) {
                default:
                case DEFAULT:
                    return "default";
                case DARK:
                    return "prefer-dark";
            }
        }

        public static ThemeStyle from_gsettings (string value) {
            switch (value) {
                default:
                case "default":
                    return DEFAULT;
                case "prefer-dark":
                    return DARK;
            }
        }
    }

    public class ThemePreviewItem : Gtk.ToggleButton {
        Gtk.Overlay overlay;
        Gtk.Picture background;
        Gtk.Fixed fixed;

        const int TINY_WINDOW_HEIGHT = 64;
        const int TINY_WINDOW_WIDTH = 90;

        const int HEIGHT = 140;
        const int WIDTH = 180;

        public ThemeStyle theme_style;

        construct {
            width_request = WIDTH;
            height_request = HEIGHT;
            set_has_frame (false);

            overlay = new Gtk.Overlay ();
            set_child (overlay);

            background = new Gtk.Picture ();
            background.set_content_fit (Gtk.ContentFit.FILL);
            // Fixes the Picture taking up too much space:
            // https://gitlab.gnome.org/GNOME/gtk/-/issues/7092
            Gtk.LayoutManager layout = new Gtk.CenterLayout ();
            background.set_layout_manager (layout);
            overlay.set_child (background);

            fixed = new Gtk.Fixed ();
            overlay.add_overlay (fixed);
        }

        public ThemePreviewItem (ThemeStyle style) {
            this.theme_style = style;

            set_halign (Gtk.Align.CENTER);

            // Rounded corners
            set_overflow (Gtk.Overflow.HIDDEN);
            add_css_class ("theme-preview-item");

            // Add the fake floating windows
            fixed.put (get_tiny_window (false),
                       50,
                       25);
            fixed.put (get_tiny_window (true),
                       20,
                       45);

            draw_background ();
        }

        private void draw_background () {
            try {
                string big_path = "%s/wallpaper".printf (Environment.get_user_cache_dir ());
                string path = Functions.generate_thumbnail (big_path);
                File file = File.new_for_path (path);

                Gly.Image image = new Gly.Loader (file).load ();
                Gly.FrameRequest frame_request = new Gly.FrameRequest ();
                frame_request.set_scale (WIDTH, HEIGHT);
                Gly.Frame frame = image.get_specific_frame (frame_request);
                // Scale the texture
                float new_width, new_height;
                Gdk.Paintable ?paintable
                    = SwaySettings.Functions.gdk_texture_scale (
                            GlyGtk4.frame_get_texture (frame),
                            frame.get_width (), frame.get_height (),
                            WIDTH, HEIGHT,
                            Gsk.ScalingFilter.NEAREST,
                            out new_width, out new_height);
                background.set_paintable (paintable);
            } catch (Error e) {
                stderr.printf (
                    "Could not find wallpaper, using greyscale background instead... %s\n",
                    e.message);
                background.set_paintable (null);
            }
        }

        Gtk.Widget get_tiny_window (bool front) {
            var window = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            window.add_css_class ("window");
            window.add_css_class (theme_style.get_preview_class (front));
            window.add_css_class (front ? "front" : "back");

            var header_bar = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            header_bar.add_css_class ("header-bar");
            header_bar.add_css_class (theme_style.get_preview_class (front));
            window.append (header_bar);

            window.set_size_request (TINY_WINDOW_WIDTH, TINY_WINDOW_HEIGHT);
            return window;
        }
    }
}
