using Gee;

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

        private Wallpaper[] wallpapers = get_system_wallpapers ();

        IPC ipc;

        public override int clamp_max {
            get {
                return 1200;
            }
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

            wallpaper_box.add (get_wallpaper_container ("System Wallpapers"));

            content_box.show_all ();
            return content_box;
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

                file.copy (file_dest, GLib.FileCopyFlags.OVERWRITE);
                Functions.set_gsetting (self_settings, "wallpaper-path", file_path);

                Functions.generate_thumbnail (dest_path, true);

                ipc.run_command ("output * bg %s fill".printf (dest_path));
            } catch (Error e) {
                stderr.printf ("%s\n", e.message);
            }
        }

        Hdy.PreferencesGroup get_wallpaper_container (string title) {
            var group = new Hdy.PreferencesGroup ();
            group.title = title;

            var row = new Hdy.PreferencesRow () {
                activatable = false,
            };
            group.add (row);

            if (wallpapers.length == 0) {
                var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 24) {
                    sensitive = false,
                    vexpand = true,
                    valign = Gtk.Align.CENTER,
                    margin = SPACING,
                };
                var img = new Gtk.Image.from_icon_name (
                    "image-missing-symbolic",
                    Gtk.IconSize.INVALID) {
                    pixel_size = 128,
                    opacity = 0.5,
                };
                box.add (img);
                box.add (new Gtk.Label ("No wallpapers found..."));
                row.add (box);
                return group;
            }

            Gtk.FlowBox flow_box = new Gtk.FlowBox () {
                max_children_per_line = 8,
                min_children_per_line = 1,
                homogeneous = true,
                margin = SPACING,
                activate_on_single_click = true,
                selection_mode = Gtk.SelectionMode.SINGLE,
                row_spacing = SPACING,
                column_spacing = SPACING,
            };
            row.add (flow_box);

            add_images.begin (wallpapers, flow_box, () => {
                flow_box.child_activated.connect ((widget) => {
                    ThumbnailImage img = (ThumbnailImage) widget.get_child ();
                    if (img.image_path != null) {
                        set_wallpaper (img.wallpaper.path);
                        preview_image.refresh_image ();
                    }
                });
            });
            return group;
        }

        async void add_images (owned Wallpaper[] paths, Gtk.FlowBox flow_box) {
            Variant ? wallpaper_path = Functions.get_gsetting (self_settings,
                                                               "wallpaper-path",
                                                               VariantType.STRING);
            string ? path = wallpaper_path != null ? wallpaper_path.get_string () : null;

            bool checked_folder_exists = false;
            foreach (var wp in paths) {
                var item = new ThumbnailImage.batch (
                    wp,
                    LIST_IMAGE_HEIGHT, LIST_IMAGE_WIDTH,
                    ref checked_folder_exists, 0);
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

        private static Wallpaper[] get_system_wallpapers () {
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
                        case GLib.FileType.REGULAR:
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

                            Wallpaper wp = Wallpaper ();
                            wp.path = Path.build_path (
                                Path.DIR_SEPARATOR_S,
                                path,
                                file_info.get_name ());
                            try {
                                string[] required = {
                                    FileAttribute.THUMBNAIL_PATH,
                                    FileAttribute.THUMBNAIL_IS_VALID
                                };
                                var info = File.new_for_path (wp.path).query_info (
                                    string.joinv (",", required),
                                    GLib.FileQueryInfoFlags.NONE);
                                string thumb_path = info.get_attribute_as_string (
                                    FileAttribute.THUMBNAIL_PATH);
                                bool thumb_valid = info.get_attribute_boolean (
                                    FileAttribute.THUMBNAIL_IS_VALID);
                                wp.thumbnail_path = thumb_path;
                                wp.thumbnail_valid = thumb_valid;
                            } catch (Error e) {
                                print ("Error: %s\n", e.message);
                                wp.thumbnail_valid = false;
                            }
                            wallpaper_paths += wp;
                            break;
                        case GLib.FileType.DIRECTORY:
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
