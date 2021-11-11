using Gee;

namespace SwaySettings {
    public struct Wallpaper {
        string path;
        string thumbnail_path;
        bool thumbnail_valid;
    }

    public class Background_Page : Page {

        private Granite.AsyncImage preview_image;
        private int preview_image_height = 216;
        private int preview_image_width = 384;
        // Parent for all wallpaper categories
        private Gtk.Box wallpaper_box;
        private int list_image_height = 144;
        private int list_image_width = 256;

        public Background_Page (string page_name, Hdy.Deck deck, IPC ipc) {
            base (page_name, deck, ipc);
        }

        public override void on_refresh () {
            foreach (var child in content_box.get_children ()) {
                content_box.remove (child);
            }

            preview_image = new Granite.AsyncImage (true, false);
            preview_image.set_size_request (preview_image_width, preview_image_height);
            preview_image.halign = Gtk.Align.CENTER;
            preview_image.valign = Gtk.Align.START;
            preview_image.get_style_context ().add_class ("frame");
            int margin = 24;
            preview_image.set_margin_top (margin - 8);
            preview_image.set_margin_start (margin);
            preview_image.set_margin_bottom (margin);
            preview_image.set_margin_end (margin);
            content_box.add (preview_image);

            wallpaper_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            wallpaper_box.expand = true;
            wallpaper_box.get_style_context ().add_class ("view");

            Gtk.FlowBox system_wallpaper_flow_box = new Gtk.FlowBox ();
            // Adds header and flowbox to wallpaper_box
            get_wallpaper_container (ref system_wallpaper_flow_box, "System Wallpapers");

            content_box.add (Page.get_scroll_widget (wallpaper_box, false, true, int.MAX, int.MAX));

            set_preivew_image ();
            add_wallpapers (get_system_wallpapers (),
                            ref system_wallpaper_flow_box);

            this.show_all ();
        }

        private void set_wallpaper (string file_path) {
            if (file_path == null) return;
            try {
                string dest_path = Path.build_path (
                    "/",
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
                ipc.run_command (@"output * bg $(dest_path) fill");
            } catch (Error e) {
                stderr.printf ("%s\n", e.message);
            }
        }

        void set_preivew_image () {
            string path = @"$(Environment.get_home_dir())/.cache/wallpaper";
            File file = File.new_for_path (path);
            preview_image.set_from_file_async.begin (file,
                                                     preview_image_width,
                                                     preview_image_height,
                                                     true);
        }

        void get_wallpaper_container (ref Gtk.FlowBox flow_box, string title) {
            var header = new Gtk.Label (title);
            Pango.AttrList li = new Pango.AttrList ();
            li.insert (Pango.attr_weight_new (Pango.Weight.BOLD));
            li.insert (new Pango.AttrSize (12288));
            header.set_attributes (li);
            header.xalign = 0.0f;
            flow_box.max_children_per_line = 8;
            flow_box.min_children_per_line = 1;
            flow_box.homogeneous = true;
            flow_box.set_margin_start (4);
            flow_box.set_margin_top (4);
            flow_box.set_margin_end (4);
            flow_box.set_margin_bottom (4);

            flow_box.child_activated.connect ((widget) => {
                ThumbnailImage img = (ThumbnailImage) widget.get_child ();
                if (img.image_path != null) {
                    set_wallpaper (img.wp.path);
                    set_preivew_image ();
                }
            });

            wallpaper_box.add (header);
            wallpaper_box.add (flow_box);
        }

        void add_wallpapers (ArrayList<Wallpaper ? > wallpapers,
                             ref Gtk.FlowBox flow_box) {
            if (wallpapers.size == 0) return;
            add_images.begin (wallpapers, flow_box);
        }

        async void add_images (ArrayList<Wallpaper ? > paths, Gtk.FlowBox flow_box) {
            bool checked_folder_exists = false;
            foreach (var path in paths) {
                var item = new List_Lazy_Image (path, list_image_height, list_image_width, ref checked_folder_exists);
                flow_box.add (item);
                Idle.add (add_images.callback);
                yield;
            }
        }

        ArrayList<Wallpaper ? > get_system_wallpapers () {
            ArrayList<string> default_paths = new ArrayList<string>.wrap ({
                "/usr/share/backgrounds",
                "/usr/share/wallpapers",
                "/usr/local/share/wallpapers",
                "/usr/local/share/backgrounds",
            });

            ArrayList<Wallpaper ? > wallpaper_paths = new ArrayList<Wallpaper ? >();
            var supported_formats = new ArrayList<string>.wrap ({ "jpg" });

            Gdk.Pixbuf.get_formats ().foreach ((pxfmt) => supported_formats.add (pxfmt.get_name ()));

            for (int i = 0; i < default_paths.size; i++) {
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
                            if (supported_formats.contains (suffix)) {
                                Wallpaper wp = Wallpaper ();
                                wp.path = path + "/" + file_info.get_name ();
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
                                }
                                wallpaper_paths.add (wp);
                            }
                            break;
                        case GLib.FileType.DIRECTORY:
                            default_paths.add (path + "/" + file_info.get_name ());
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
