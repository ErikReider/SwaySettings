namespace SwaySettings {
    public class ThumbnailImage : Gtk.Box {

        public Granite.AsyncImage image;

        public string image_path;

        public int height;
        public int width;
        public Wallpaper wp;


        public ThumbnailImage (Wallpaper wp,
                               int height,
                               int width,
                               ref bool checked_folder_exists) {
            this.wp = wp;
            this.height = height;
            this.width = width;

            if (!checked_folder_exists) {
                check_folder_exist ();
                checked_folder_exists = true;
            }

            if (wp.thumbnail_valid && wp.thumbnail_path != null) {
                this.image_path = wp.thumbnail_path;
                show_image.begin ();
            } else {
                generate_thumbnail ();
            }
        }

        private void check_folder_exist () {
            try {
                string[] folders = {
                    GLib.Environment.get_user_cache_dir (),
                    "thumbnails",
                    "large"
                };

                string allpath = string.joinv (
                    Path.DIR_SEPARATOR.to_string (),
                    folders);
                if (File.new_for_path (allpath).query_exists ()) return;

                string path = "";
                foreach (string part in folders) {
                    path = Path.build_path (Path.DIR_SEPARATOR.to_string (),
                                            path, part);
                    var dir = File.new_for_path (path);
                    if (!dir.query_exists ()) {
                        dir.make_directory ();
                    }
                }
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        private void generate_thumbnail () {
            try {
                string path = File.new_for_path (wp.path).get_uri ();
                string checksum = GLib.Checksum.compute_for_string (GLib.ChecksumType.MD5, path, path.length);
                string checksum_path = @"$(Environment.get_user_cache_dir ())/thumbnails/large/$(checksum).png";

                if (!File.new_for_path (checksum_path).query_exists ()) {
                    string output;
                    string error;
                    bool status = Process.spawn_command_line_sync (
                        @"gdk-pixbuf-thumbnailer \"$(wp.path)\" \"$(checksum_path)\"",
                        out output, out error);
                    if (!status || error.length > 0) return;
                }
                this.image_path = checksum_path;
                show_image.begin ();
            } catch (Error e) {
                stderr.printf (e.message + "\n");
                this.hide ();
            }
        }

        private async void show_image () {
            image = new Granite.AsyncImage (false, false);
            image.get_style_context ().add_class ("background-image-item");
            image.set_size_request (width, height);
            this.add (image);
            this.show_all ();

            File file = File.new_for_path (image_path);
            try {
                yield image.set_from_file_async (file, width, height, true);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
                this.hide ();
            }
        }
    }
}
