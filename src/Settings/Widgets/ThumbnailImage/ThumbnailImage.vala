namespace SwaySettings {
    public class ThumbnailImage : Adw.Bin {
        private Utils.ScaleModes scaling_mode;
        private Gtk.Overlay overlay;
        private Gtk.Picture picture;
        private Gtk.Button remove_button;
        private Gtk.Button preview_button;

        public string ?image_path;
        public Wallpaper wallpaper;
        public int width;
        public int height;
        public bool full_size;

        public signal void on_remove_click (Wallpaper wp);
        public signal void on_set_image (bool visible);

        construct {
            overlay = new Gtk.Overlay ();
            set_child (overlay);

            picture = new Gtk.Picture () {
                content_fit = Gtk.ContentFit.COVER,
                can_shrink = true,
                vexpand = true,
                hexpand = true,
            };

            var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2) {
                halign = Gtk.Align.END,
                valign = Gtk.Align.START,
            };
            overlay.add_overlay (button_box);

            // Preview button
            preview_button =
                new Gtk.Button.from_icon_name ("image-x-generic-symbolic") {
                has_frame = false,
                visible = false,
            };
            preview_button.add_css_class ("circular");
            preview_button.add_css_class ("img-remove-button");
            preview_button.clicked.connect (show_preview);
            button_box.append (preview_button);

            // Remove button
            remove_button =
                new Gtk.Button.from_icon_name ("window-close-symbolic") {
                has_frame = false,
                visible = false,
            };
            remove_button.add_css_class ("circular");
            remove_button.add_css_class ("img-remove-button");
            remove_button.clicked.connect (() => {
                on_remove_click (this.wallpaper);
            });
            button_box.append (remove_button);

            // Clip the corners to make them rounded
            add_css_class ("thumbnail-image");
        }

        public ThumbnailImage (Wallpaper wallpaper,
                               int height,
                               int width,
                               Utils.ScaleModes scaling_mode,
                               bool full_size,
                               int margin = 8) {
            this.wallpaper = wallpaper;
            this.width = width;
            this.height = height;
            this.scaling_mode = scaling_mode;
            this.full_size = full_size;
            set_scaling_mode ();
            set_request ();

            this.margin_top = margin;
            this.margin_bottom = margin;
            this.margin_start = margin;
            this.margin_end = margin;

            picture.set_tooltip_text (wallpaper.path);

            refresh_image.begin ();
        }

        /** Doesn't load the Image. You must call `refresh_image ()`. */
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
            set_scaling_mode ();
            set_request ();

            this.margin_top = margin;
            this.margin_bottom = margin;
            this.margin_start = margin;
            this.margin_end = margin;

            picture.set_tooltip_text (wallpaper.path);

            preview_button.set_visible (true);
            remove_button.set_visible (have_remove_button);

            if (!checked_folder_exists) {
                check_folder_exist ();
                checked_folder_exists = true;
            }
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

        public async void refresh_image () {
            overlay.set_child (new Adw.Spinner () {
                width_request = 128,
                height_request = 128,
            });

            // Load the images in the background without blocking the main thread
            var data = new ThumbnailThread (image_path, wallpaper, width,
                                            height, full_size,
                                            refresh_image.callback);

            new Thread<void> (wallpaper.path, data.begin);
            yield;

            image_path = data.image_path;
            picture.set_paintable (data.texture);
            // Replace spinner with picture
            overlay.set_child (picture);

            on_set_image (data.texture != null);
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
                if (File.new_for_path (allpath).query_exists ()) {
                    return;
                }

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

        private void show_preview () {
            Adw.Dialog dialog = new Adw.Dialog () {
                title = "Preview",
                follows_content_size = true,
            };

            var toolbar_view = new Adw.ToolbarView ();
            toolbar_view.set_top_bar_style (Adw.ToolbarStyle.FLAT);
            toolbar_view.set_reveal_top_bars (true);
            dialog.set_child (toolbar_view);

            var image = new ThumbnailImage (wallpaper, -1, -1, scaling_mode,
                                            true, 0);
            image.add_css_class ("no-round");
            toolbar_view.set_content (image);

            Adw.HeaderBar header_bar = new Adw.HeaderBar ();
            toolbar_view.add_top_bar (header_bar);

            Gtk.Button copy_button = new Gtk.Button.from_icon_name ("edit-copy-symbolic");
            copy_button.set_tooltip_text ("Copy to clipboard");
            copy_button.add_css_class ("circular");
            copy_button.add_css_class ("flat");
            copy_button.clicked.connect (() => {
                unowned Gdk.Clipboard clipboard = get_clipboard ();
                if (clipboard == null) {
                    warning ("Could not copy path to clipboard. Clipboard could not be obtained");
                    return;
                }
                clipboard.set_text (wallpaper.path);
            });
            header_bar.pack_end (copy_button);

            dialog.present (get_root ());
        }
    }

    private class ThumbnailThread {
        public string ?image_path;
        public Gdk.Texture ?texture = null;

        Wallpaper wallpaper;
        int width;
        int height;
        bool full_size;
        unowned SourceFunc callback;

        public ThumbnailThread(string ?image_path,
                               Wallpaper wallpaper,
                               int width,
                               int height,
                               bool full_size,
                               SourceFunc callback) {
            this.image_path = image_path;
            this.wallpaper = wallpaper;
            this.width = width;
            this.height = height;
            this.full_size = full_size;
            this.callback = callback;
        }

        public void begin() {
            if (full_size) {
                image_path = wallpaper.path;
                show_image ();
            } else if (wallpaper.thumbnail_valid &&
                       wallpaper.thumbnail_path != null) {
                image_path = wallpaper.thumbnail_path;
                show_image ();
            } else {
                generate_thumbnail ();
            }

            Idle.add (() => callback ());
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
                Gdk.Pixbuf pixbuf;
                if (full_size) {
                    pixbuf = new Gdk.Pixbuf.from_file (image_path);
                } else {
                    pixbuf = new Gdk.Pixbuf.from_file_at_scale (
                        image_path, width, height, true);
                }

                texture = Gdk.Texture.for_pixbuf (pixbuf);
            } catch (Error e) {
                texture = null;
                stderr.printf ("Set Image Error: %s\n", e.message);
            }
        }
    }
}
