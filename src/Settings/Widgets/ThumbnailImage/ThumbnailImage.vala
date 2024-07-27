namespace SwaySettings {
    public class ThumbnailImage : Gtk.Box {
        private Gtk.Image image;
        public string ? image_path;
        public Wallpaper wallpaper;
        public int width;
        public int height;
        public bool have_remove_button = false;

        public signal void on_remove_click (Wallpaper wp);

        construct {
            this.halign = Gtk.Align.CENTER;
            this.valign = Gtk.Align.CENTER;

            image = new Gtk.Image () {
                expand = true,
                valign = Gtk.Align.FILL,
                halign = Gtk.Align.FILL,
            };
        }

        public ThumbnailImage (Wallpaper wallpaper,
                               int height,
                               int width,
                               bool stretch = false,
                               int margin = 8) {
            this.wallpaper = wallpaper;
            this.width = width;
            this.height = height;
            set_request ();

            this.margin = margin;

            add (image);
            show_all ();

            ulong realize_handler = 0;
            realize_handler = image.draw.connect (() => {
                image.disconnect (realize_handler);
                realize_handler = 0;
                refresh_image ();
                return false;
            });
        }

        public ThumbnailImage.batch (Wallpaper wallpaper,
                                     int height,
                                     int width,
                                     ref bool checked_folder_exists,
                                     bool have_remove_button,
                                     int margin = 8) {
            this.wallpaper = wallpaper;
            this.width = width;
            this.height = height;
            this.have_remove_button = have_remove_button;
            set_request ();

            this.margin = margin;

            if (have_remove_button) {
                var overlay = new Gtk.Overlay ();
                var button = new Gtk.Button.from_icon_name (
                    "window-close-symbolic", Gtk.IconSize.BUTTON) {
                    halign = Gtk.Align.END,
                    valign = Gtk.Align.START,
                    relief = Gtk.ReliefStyle.NONE,
                };
                button.get_style_context ().add_class ("circular");
                button.get_style_context ().add_class ("img-remove-button");
                button.clicked.connect (() => on_remove_click (this.wallpaper));
                add (overlay);
                overlay.add (image);
                overlay.add_overlay (button);
            } else {
                add (image);
            }
            show_all ();

            if (!checked_folder_exists) {
                check_folder_exist ();
                checked_folder_exists = true;
            }

            ulong realize_handler = 0;
            realize_handler = image.draw.connect (() => {
                image.disconnect (realize_handler);
                realize_handler = 0;
                refresh_image ();
                return false;
            });
        }

        private void set_request () {
            set_size_request (width, height);
            image.set_size_request (width, height);
        }

        public void refresh_image () {
            if (wallpaper.thumbnail_valid && wallpaper.thumbnail_path != null) {
                this.image_path = wallpaper.thumbnail_path;
                show_image.begin ();
            } else {
                generate_thumbnail ();
            }
        }

        // Clip the corners to make them rounded
        public override bool draw (Cairo.Context cr) {
            const double RADIUS = 9;
            const double DEGREES = Math.PI / 180.0;
            int width = get_allocated_width ();
            int height = get_allocated_height ();

            cr.new_sub_path ();
            cr.arc (width - RADIUS, RADIUS, RADIUS, -90 * DEGREES, 0 * DEGREES);
            cr.arc (width - RADIUS, height - RADIUS, RADIUS, 0 * DEGREES, 90 * DEGREES);
            cr.arc (RADIUS, height - RADIUS, RADIUS, 90 * DEGREES, 180 * DEGREES);
            cr.arc (RADIUS, RADIUS, RADIUS, 180 * DEGREES, 270 * DEGREES);
            cr.close_path ();

            cr.set_source_rgb (0, 0, 0);
            cr.clip ();
            cr.paint ();

            return base.draw (cr);
        }

        private void check_folder_exist () {
            try {
                string[] folders = {
                    GLib.Environment.get_user_cache_dir (),
                    "thumbnails",
                    "large"
                };

                string allpath = string.joinv (
                    Path.DIR_SEPARATOR_S,
                    folders);
                if (File.new_for_path (allpath).query_exists ()) return;

                string path = "";
                foreach (string part in folders) {
                    path = Path.build_path (Path.DIR_SEPARATOR_S,
                                            path, part);
                    var dir = File.new_for_path (path);
                    if (!dir.query_exists ()) {
                        dir.make_directory ();
                    }
                }
            } catch (Error e) {
                stderr.printf ("Check Folder Error: %s\n", e.message);
            }
        }

        private void generate_thumbnail () {
            try {
                image_path = Functions.generate_thumbnail (wallpaper.path);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
                image_path = wallpaper.path;
            }
            show_image.begin ();
        }

        private async void show_image () {
            try {
                File file = File.new_for_path (image_path);
                var stream = yield file.read_async ();

                Gdk.Pixbuf pixbuf = yield new Gdk.Pixbuf.from_stream_at_scale_async (
                    stream,
                    width * image.scale_factor,
                    height * image.scale_factor,
                    false);

                var surface = Gdk.cairo_surface_create_from_pixbuf (
                    pixbuf, image.scale_factor, null);
                image.set_from_surface (surface);
            } catch (Error e) {
                stderr.printf ("Set Image Error: %s\n", e.message);
            }
        }
    }
}
