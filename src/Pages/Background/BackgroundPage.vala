namespace SwaySettings {
    public struct Wallpaper {
        string path;
        string thumbnail_path;
        bool thumbnail_valid;
    }

    public class BackgroundPage : PageScroll {
        private ThumbnailImage preview_image;
        private const int PREVIEW_IMAGE_HEIGHT = 216;
        private const int PREVIEW_IMAGE_WIDTH = 384;
        private const int LIST_IMAGE_HEIGHT = 135;
        private const int LIST_IMAGE_WIDTH = 180;

        private const int SPACING = 16;

        private static Wallpaper current_wallpaper = Wallpaper () {
            path = Path.build_path (Path.DIR_SEPARATOR_S,
                                    Environment.get_user_cache_dir (),
                                    "wallpaper"),
            thumbnail_path = "",
            thumbnail_valid = false,
        };

        private Gtk.FlowBox ? user_flow_box;
        private Gtk.FlowBox ? sys_flow_box;

        IPC ipc;

        public override int clamp_max {
            get {
                return 1200;
            }
        }

        construct {
            self_settings.changed[Constants.SETTINGS_USER_WALLPAPERS]
             .connect (on_user_wallpapers_change);
        }

        ~BackgroundPage () {
            self_settings.changed[Constants.SETTINGS_USER_WALLPAPERS]
             .disconnect (on_user_wallpapers_change);
        }

        public BackgroundPage (SettingsItem item, Hdy.Deck deck, IPC ipc) {
            base (item, deck);
            this.ipc = ipc;
        }

        public override Gtk.Widget set_child () {
            Gtk.Box content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);

            preview_image = new ThumbnailImage (current_wallpaper,
                                                PREVIEW_IMAGE_HEIGHT,
                                                PREVIEW_IMAGE_WIDTH) {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.START,
                expand = false,
                width_request = PREVIEW_IMAGE_WIDTH,
                height_request = PREVIEW_IMAGE_HEIGHT,
            };
            content_box.add (preview_image);

            preview_image.refresh_image ();

            Gtk.Box wallpaper_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 16);
            content_box.add (wallpaper_box);

            // User Wallpapers
            Hdy.PreferencesGroup user_wallpapers = get_wallpaper_container (
                "User Wallpapers", get_user_wallpapers (), out user_flow_box, true);
            wallpaper_box.add (user_wallpapers);

            // System Wallpapers
            Hdy.PreferencesGroup sys_wallpapers = get_wallpaper_container (
                "System Wallpapers", get_system_wallpapers (), out sys_flow_box);
            wallpaper_box.add (sys_wallpapers);

            content_box.show_all ();
            return content_box;
        }

        // TODO: Don't refresh, manually check the diff?
        private void on_user_wallpapers_change () {
            this.on_refresh ();
        }

        private void refresh_selected_wallpaper (string selected_path) {
            // string selected_path = preview_image.wallpaper.path;
            preview_image.refresh_image ();
            Gtk.FlowBox[] boxes = { user_flow_box, sys_flow_box };
            foreach (Gtk.FlowBox flow_box in boxes) {
                if (flow_box == null) continue;
                flow_box.unselect_all ();
                var children = (List<weak Gtk.FlowBoxChild>) flow_box.get_children ();
                foreach (Gtk.FlowBoxChild child in children) {
                    ThumbnailImage img = (ThumbnailImage) child.get_child ();
                    if (selected_path == img.wallpaper.path) {
                        flow_box.select_child (child);
                        continue;
                    }
                }
            }
        }

        private void set_wallpaper (string file_path) {
            if (file_path == null) return;
            try {
                string dest_path = Path.build_path (
                    Path.DIR_SEPARATOR_S,
                    Environment.get_user_cache_dir (),
                    "wallpaper");

                File file = File.new_for_path (file_path);
                File file_dest = File.new_for_path (dest_path);

                if (!file.query_exists ()) {
                    stderr.printf (
                        "File %s not found or permissions missing",
                        file_path);
                    return;
                }

                file.copy (file_dest, FileCopyFlags.OVERWRITE);
                Functions.set_gsetting (self_settings,
                                        Constants.SETTINGS_WALLPAPER_PATH,
                                        file_path);

                Functions.generate_thumbnail (dest_path, true);

                ipc.run_command ("output * bg %s fill".printf (dest_path));
            } catch (Error e) {
                stderr.printf ("%s\n", e.message);
            }
        }

        private void add_user_wallpaper () {
            var image_chooser = new Gtk.FileChooserNative (
                "Select Image",
                (Gtk.Window) get_toplevel (),
                Gtk.FileChooserAction.OPEN,
                "_Open",
                "_Cancel");
            // Only show images
            var filter = new Gtk.FileFilter ();
            filter.add_mime_type ("image/*");
            filter.add_pixbuf_formats ();
            image_chooser.set_filter (filter);
            // Run and get result
            int res = image_chooser.run ();
            string path = image_chooser.get_filename ();
            if (res == Gtk.ResponseType.ACCEPT && path != null) {
                int w, h;
                Gdk.PixbufFormat ? format = Gdk.Pixbuf.get_file_info (
                    path, out w, out h);
                string[] paths = get_user_wallpaper_paths ();
                if (format != null && !(path in paths)) {
                    paths += path;
                    Functions.set_gsetting (self_settings,
                                            Constants.SETTINGS_USER_WALLPAPERS,
                                            new Variant.strv (paths));
                }
            }
            image_chooser.destroy ();
        }

        private void remove_user_wallpaper (Wallpaper wallpaper) {
            string[] paths = get_user_wallpaper_paths ();
            if (wallpaper.path in paths) {
                string[] wallpapers = {};
                foreach (string path in paths) {
                    if (path != wallpaper.path) {
                        wallpapers += path;
                    }
                }
                Functions.set_gsetting (self_settings,
                                        Constants.SETTINGS_USER_WALLPAPERS,
                                        new Variant.strv (wallpapers));
            }
        }

        Hdy.PreferencesGroup get_wallpaper_container (string title,
                                                      Wallpaper[] wallpapers,
                                                      out Gtk.FlowBox ? flow_box,
                                                      bool add_button = false) {
            var group = new Hdy.PreferencesGroup ();
            group.title = title;

            // Adds a Add Image Button
            if (add_button) {
                var add_row = new Hdy.PreferencesRow () {
                    activatable = false,
                    can_focus = false,
                };
                var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                    halign = Gtk.Align.CENTER,
                    margin = SPACING,
                };
                var button = new Gtk.Button.with_label ("Add Wallpaper");
                button.clicked.connect (this.add_user_wallpaper);
                box.add (button);
                add_row.add (box);
                group.add (add_row);
            }

            var row = new Hdy.PreferencesRow () {
                activatable = false,
                can_focus = false,
            };
            group.add (row);

            if (wallpapers.length == 0) {
                var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                    sensitive = false,
                    vexpand = true,
                    valign = Gtk.Align.CENTER,
                    margin = SPACING,
                };
                var img = new Gtk.Image.from_icon_name (
                    "image-missing-symbolic",
                    Gtk.IconSize.INVALID) {
                    pixel_size = 96,
                    opacity = 0.75,
                };
                box.add (img);
                box.add (new Gtk.Label ("No wallpapers found..."));
                row.add (box);
                flow_box = null;
                return group;
            }

            flow_box = new Gtk.FlowBox () {
                max_children_per_line = 8,
                min_children_per_line = 1,
                homogeneous = true,
                margin = SPACING,
                activate_on_single_click = true,
                selection_mode = Gtk.SelectionMode.SINGLE,
                row_spacing = SPACING,
                column_spacing = SPACING,
            };
            flow_box.child_activated.connect ((widget) => {
                unowned Gtk.Widget? child = widget.get_child ();
                if (!(child is ThumbnailImage)) return;
                ThumbnailImage img = (ThumbnailImage) child;
                if (img.image_path != null) {
                    set_wallpaper (img.wallpaper.path);
                    refresh_selected_wallpaper (img.wallpaper.path);
                }
            });
            row.add (flow_box);

            add_images.begin (wallpapers, flow_box, add_button);
            return group;
        }

        async void add_images (owned Wallpaper[] paths, Gtk.FlowBox flow_box, bool remove_button) {
            Variant ? wallpaper_path = Functions.get_gsetting (
                self_settings,
                Constants.SETTINGS_WALLPAPER_PATH,
                VariantType.STRING);
            string ? path = wallpaper_path != null ? wallpaper_path.get_string () : null;

            bool checked_folder_exists = false;
            foreach (var wp in paths) {
                var item = new ThumbnailImage.batch (
                    wp,
                    LIST_IMAGE_HEIGHT, LIST_IMAGE_WIDTH,
                    ref checked_folder_exists,
                    remove_button,
                    0);
                item.on_remove_click.connect (remove_user_wallpaper);
                var f_child = new Gtk.FlowBoxChild () {
                    valign = Gtk.Align.CENTER,
                    halign = Gtk.Align.CENTER,
                };
                f_child.add (item);
                f_child.show_all ();
                f_child.get_style_context ().add_class ("background-flowbox-child");

                flow_box.add (f_child);
                if (wp.path == path) flow_box.select_child (f_child);
                Idle.add (add_images.callback);
                yield;
            }
        }

        private Wallpaper get_wallpaper_from_path (string path) {
            Wallpaper wp = Wallpaper ();
            wp.path = path;
            try {
                string[] required = {
                    FileAttribute.THUMBNAIL_PATH,
                    FileAttribute.THUMBNAIL_IS_VALID
                };
                var info = File.new_for_path (wp.path).query_info (
                    string.joinv (",", required),
                    FileQueryInfoFlags.NONE);
                string thumb_path = info.get_attribute_as_string (
                    FileAttribute.THUMBNAIL_PATH);
                bool thumb_valid = info.get_attribute_boolean (
                    FileAttribute.THUMBNAIL_IS_VALID);
                wp.thumbnail_path = thumb_path;
                wp.thumbnail_valid = thumb_valid;
            } catch (Error e) {
                stderr.printf ("Error: %s\n", e.message);
                wp.thumbnail_valid = false;
            }
            return wp;
        }

        private string[] get_user_wallpaper_paths () {
            Variant ? variant = Functions.get_gsetting (
                self_settings,
                Constants.SETTINGS_USER_WALLPAPERS,
                VariantType.STRING_ARRAY);
            if (variant == null
                || !variant.get_type ().equal (VariantType.STRING_ARRAY)) {
                return {};
            }
            return variant.dup_strv ();
        }

        private Wallpaper[] get_user_wallpapers () {
            Wallpaper[] wallpapers = {};
            string[] paths = get_user_wallpaper_paths ();
            foreach (string path in paths) {
                wallpapers += get_wallpaper_from_path (path);
            }
            return wallpapers;
        }

        private Wallpaper[] get_system_wallpapers () {
            string[] default_paths = {
                "/usr/share/backgrounds",
                "/usr/share/wallpapers",
                "/usr/local/share/wallpapers",
                "/usr/local/share/backgrounds",
            };

            string[] formats = { "jpg" };
            Gdk.Pixbuf.get_formats ().foreach ((fmt) => formats += fmt.get_name ());

            Wallpaper[] wallpaper_paths = {};
            for (int i = 0; i < default_paths.length; i++) {
                string path = default_paths[i];
                Functions.walk_through_dir (path, (file_info, file) => {
                    switch (file_info.get_file_type ()) {
                        case FileType.REGULAR:
                            if (file_info.get_is_hidden ()
                                || file_info.get_is_backup ()
                                || file_info.get_is_symlink ()) {
                                return;
                            }
                            string name = file_info.get_name ();
                            string suffix = name.slice (
                                name.last_index_of_char ('.') + 1,
                                name.length);
                            if (!(suffix in formats)) return;

                            string wp_path = Path.build_path (
                                Path.DIR_SEPARATOR_S,
                                path,
                                file_info.get_name ());
                            wallpaper_paths += get_wallpaper_from_path (wp_path);
                            break;
                        case FileType.DIRECTORY:
                            default_paths += Path.build_path (
                                Path.DIR_SEPARATOR_S,
                                path,
                                file_info.get_name ());
                            break;
                        default:
                            break;
                    }
                });
            }
            return wallpaper_paths;
        }
    }
}
