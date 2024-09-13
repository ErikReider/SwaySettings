namespace SwaySettings {
    public class ThumbnailImage : Adw.Bin {
        private Utils.ScaleModes scaling_mode;
        private Gtk.Picture picture;
        public string ? image_path;
        public Wallpaper wallpaper;
        public int width;
        public int height;
        public bool have_remove_button = false;

        public signal void on_remove_click (Wallpaper wp);

        construct {
            picture = new Gtk.Picture () {
                content_fit = Gtk.ContentFit.COVER,
                can_shrink = true,
                vexpand = true,
                hexpand = true,
            };

            // Clip the corners to make them rounded
            add_css_class ("thumbnail-image");
        }

        public ThumbnailImage (Wallpaper wallpaper,
                               int height,
                               int width,
                               Utils.ScaleModes scaling_mode,
                               int margin = 8) {
            this.wallpaper = wallpaper;
            this.width = width;
            this.height = height;
            this.scaling_mode = scaling_mode;
            set_scaling_mode ();
            set_request ();

            this.margin_top = margin;
            this.margin_bottom = margin;
            this.margin_start = margin;
            this.margin_end = margin;

            set_child (picture);

            refresh_image.begin ();
        }

        public ThumbnailImage.batch (Wallpaper wallpaper,
                                     int height,
                                     int width,
                                     Utils.ScaleModes scaling_mode,
                                     ref bool checked_folder_exists,
                                     bool have_remove_button,
                                     int margin = 8) {
            this.wallpaper = wallpaper;
            this.width = width;
            this.height = height;
            this.scaling_mode = scaling_mode;
            this.have_remove_button = have_remove_button;
            set_scaling_mode ();
            set_request ();

            this.margin_top = margin;
            this.margin_bottom = margin;
            this.margin_start = margin;
            this.margin_end = margin;

            if (have_remove_button) {
                var overlay = new Gtk.Overlay ();
                var button = new Gtk.Button.from_icon_name ("window-close-symbolic") {
                    halign = Gtk.Align.END,
                    valign = Gtk.Align.START,
                    has_frame = false,
                };
                button.add_css_class ("circular");
                button.add_css_class ("img-remove-button");
                button.clicked.connect (() => on_remove_click (this.wallpaper));
                set_child (overlay);
                overlay.set_child (picture);
                overlay.add_overlay (button);
            } else {
                set_child (picture);
            }

            if (!checked_folder_exists) {
                check_folder_exist ();
                checked_folder_exists = true;
            }

            refresh_image.begin ();
        }

        private void set_scaling_mode () {
            switch (scaling_mode) {
                case Utils.ScaleModes.FILL:
                    picture.content_fit = Gtk.ContentFit.COVER;
                    break;
                case Utils.ScaleModes.STRETCH:
                    picture.content_fit = Gtk.ContentFit.FILL;
                    break;
                case Utils.ScaleModes.FIT:
                    picture.content_fit = Gtk.ContentFit.CONTAIN;
                    break;
                case Utils.ScaleModes.CENTER:
                    picture.content_fit = Gtk.ContentFit.SCALE_DOWN;
                    break;
            }

        }

        private void set_request () {
            width_request = width;
            height_request = height;
            picture.width_request = width;
            picture.height_request = height;
        }

        public async void refresh_image() {
            // Load the images in the background without blocking the main thread
            var data = new ThumbnailThread (image_path, wallpaper, width, height,
                refresh_image.callback);
            new Thread<void> (wallpaper.path, data.begin);
            yield;

            image_path = data.image_path;
            picture.set_paintable (data.texture);
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
    }

    private class ThumbnailThread {
        public string ? image_path;
        public Gdk.Texture ? texture;

        Wallpaper wallpaper;
        int width;
        int height;
        SourceFunc callback;

        public ThumbnailThread(string ? image_path,
                               Wallpaper wallpaper,
                               int width, int height,
                               SourceFunc callback) {
            this.image_path = image_path;
            this.wallpaper = wallpaper;
            this.width = width;
            this.height = height;
            this.callback = callback;
        }

        public void begin() {
            if (wallpaper.thumbnail_valid && wallpaper.thumbnail_path != null) {
                image_path = wallpaper.thumbnail_path;
                show_image ();
            } else {
                generate_thumbnail ();
            }

            Idle.add((owned) callback);
        }

        private void generate_thumbnail () {
            try {
                image_path = Functions.generate_thumbnail (wallpaper.path);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
                image_path = wallpaper.path;
            }
            show_image ();
        }

        private void show_image () {
            try {
                Gdk.Pixbuf pixbuf = new Gdk.Pixbuf.from_file_at_scale (
                    image_path, width, height, true);

                texture = Gdk.Texture.for_pixbuf (pixbuf);
            } catch (Error e) {
                stderr.printf ("Set Image Error: %s\n", e.message);
            }
        }
    }
}
