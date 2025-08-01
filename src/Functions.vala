using Gee;

namespace SwaySettings {
    private errordomain ThumbnailerError { FAILED; }

    public delegate bool BoolFunc<G> (G data);

    public class Functions {

        public static void iter_listbox_children<G> (Gtk.ListBox listbox, BoolFunc<G> func) {
            unowned Gtk.Widget ? widget = listbox.get_first_child ();
            if (widget == null) {
                return;
            }
            do {
                if (func(widget)) {
                    return;
                }
                widget = widget.get_next_sibling ();
            } while (widget != null && widget != listbox.get_first_child ());
        }

        public delegate void Delegate_walk_func (FileInfo file_info, File file);

        public static int walk_through_dir (string path, Delegate_walk_func func) {
            try {
                var directory = File.new_for_path (path);
                if (!directory.query_exists ()) return 1;

                string[] attributes = {
                    FileAttribute.STANDARD_NAME,
                    FileAttribute.STANDARD_TYPE,
                    FileAttribute.STANDARD_IS_BACKUP,
                    FileAttribute.STANDARD_IS_SYMLINK,
                    FileAttribute.STANDARD_IS_HIDDEN,
                };
                var enumerator = directory.enumerate_children (
                    string.joinv (",", attributes), 0);
                FileInfo file_prop;
                while ((file_prop = enumerator.next_file ()) != null) {
                    func (file_prop, directory);
                }
            } catch (Error e) {
                print ("Error: %s\n", e.message);
                return 1;
            }
            return 0;
        }

        public static File check_settings_folder_exists (string file_name) {
            string base_path = Path.build_path (Path.DIR_SEPARATOR_S,
                Environment.get_user_config_dir (), "sway", ".generated_settings");
            // Checks if directory exists. Creates one if none
            if (!FileUtils.test (base_path, FileTest.IS_DIR)) {
                try {
                    var file = File.new_for_path (base_path);
                    file.make_directory ();
                } catch (Error e) {
                    print ("Error: %s\n", e.message);
                }
            }
            // Checks if file exists. Creates one if none
            var file = File.new_for_path (
                Path.build_path (Path.DIR_SEPARATOR_S, base_path, file_name));
            if (!file.query_exists ()) {
                try {
                    file.create (FileCreateFlags.NONE);
                } catch (Error e) {
                    print ("Error: %s\n", e.message);
                    Process.exit (1);
                }
            }
            return file;
        }

        public static void write_settings (string file_name, string[] lines) {
            try {
                var file = check_settings_folder_exists (file_name);
                var fos = file.replace (null,
                                        false,
                                        FileCreateFlags.REPLACE_DESTINATION,
                                        null);
                var dos = new DataOutputStream (fos);
                dos.put_string (
                    "# GENERATED BY SWAYSETTINGS. DON'T MODIFY THIS FILE!\n");
                foreach (string line in lines) {
                    dos.put_string (line);
                }
            } catch (Error e) {
                print ("Error: %s\n", e.message);
                Process.exit (1);
            }
        }

        public static bool is_swaync_installed () {
            return GLib.Environment.find_program_in_path ("swaync") != null;
        }

        public static string get_swaync_config_path () {
            string[] paths = {};
            paths += Path.build_path (Path.DIR_SEPARATOR.to_string (),
                                      GLib.Environment.get_user_config_dir (),
                                      "swaync/config.json");
            foreach (var path in GLib.Environment.get_system_config_dirs ()) {
                paths += Path.build_path (Path.DIR_SEPARATOR.to_string (),
                                          path, "swaync/config.json");
            }

            string path = "";
            foreach (string try_path in paths) {
                if (File.new_for_path (try_path).query_exists ()) {
                    path = try_path;
                    break;
                }
            }
            return path;
        }

        public static bool extract_symlink (ref string path) {
            bool is_symlink = false;
            while (FileUtils.test (path, FileTest.IS_SYMLINK)) {
                try {
                    path = FileUtils.read_link (path);
                    is_symlink = true;
                } catch (Error e) {
                    warning ("Could not read link for path: %s", path);
                    break;
                }
            }
            return is_symlink;
        }

        private delegate Type TypeFunc ();

        /** https://gitlab.gnome.org/GNOME/vala/-/issues/412 */
        public static Type get_proxy_gtype<T> () {
            Quark proxy_quark = Quark.from_string ("vala-dbus-proxy-type");
            return ((TypeFunc) (typeof (T).get_qdata (proxy_quark)))();
        }

        public static string ? set_gsetting (Settings settings,
                                             string name,
                                             Variant value) {
            if (!settings.settings_schema.has_key (name)) {
                stderr.printf ("GSchema key \"%s\" not found!\n", name);
                return null;
            }

            var v_type = settings.settings_schema.get_key (name).get_value_type ();
            if (!v_type.equal (value.get_type ())) {
                stderr.printf ("Set GSettings error: Set value type not equal to gsettings type\n");
                return null;
            }

            switch (value.get_type_string ()) {
                case "i":
                    int32 val = value.get_int32 ();
                    settings.set_int (name, val);
                    return val.to_string ();
                case "b":
                    bool val = value.get_boolean ();
                    settings.set_boolean (name, val);
                    return val.to_string ();
                case "s":
                    string val = value.get_string ();
                    settings.set_string (name, val);
                    return val;
                case "as":
                    string[] val = value.get_strv ();
                    settings.set_strv (name, val);
                    return string.joinv (", ", val);
            }
            return null;
        }

        public static Variant ? get_gsetting (Settings settings,
                                              string name,
                                              VariantType type) {
            if (!settings.settings_schema.has_key (name)) return null;
            var v_type = settings.settings_schema.get_key (name).get_value_type ();
            if (!v_type.equal (type)) {
                stderr.printf (
                    "Set GSettings error:" +
                    " Set value type \"%s\" not equal to gsettings type \"%s\"\n",
                    type, v_type);
                return null;
            }
            return settings.get_value (name);
        }

        public static string ? generate_thumbnail (string p,
                                                   bool delete_past = false) throws Error {
            File file = File.new_for_path (p);
            string path = file.get_uri ();
            string checksum = Checksum.compute_for_string (ChecksumType.MD5, path, path.length);
            // Only use large thumbnails to match the widget size
            string checksum_path = "%s/thumbnails/large/%s.png".printf (
                Environment.get_user_cache_dir (), checksum);

            File sum_file = File.new_for_path (checksum_path);
            bool exists = sum_file.query_exists ();
            // Remove the old file
            if (delete_past && exists) {
                sum_file.delete ();
                exists = false;
            }
            if (!exists) {
                string output;
                string error;
                bool status = Process.spawn_command_line_sync (
                    "gdk-pixbuf-thumbnailer \"%s\" \"%s\"".printf (p, checksum_path),
                    out output, out error);
                if (!status || error.length > 0) {
                    throw new ThumbnailerError.FAILED (error);
                }
            }

            return checksum_path;
        }

        public static bool set_wallpaper (string file_path,
                                          Settings self_settings) {
            if (file_path == null) return false;
            try {
                string dest_path = Path.build_path (
                    Path.DIR_SEPARATOR_S,
                    Environment.get_user_config_dir (),
                    "swaysettings-wallpaper");

                File file = File.new_for_path (file_path);
                File file_dest = File.new_for_path (dest_path);

                if (!file.query_exists ()) {
                    stderr.printf (
                        "File %s not found or permissions missing",
                        file_path);
                    return false;
                }

                file.copy (file_dest, FileCopyFlags.OVERWRITE);
                Functions.generate_thumbnail (dest_path, true);

                Functions.set_gsetting (self_settings,
                                        Constants.SETTINGS_WALLPAPER_PATH,
                                        file_path);

                if (Utils.wallpaper_application_registered ()) {
                    Utils.Config config = Utils.Config() {
                        path = file_path,
                        scale_mode = Utils.get_scale_mode_gschema (self_settings),
                    };
                    Utils.wallpaper_application.activate_action (Constants.WALLPAPER_ACTION_NAME, config);
                }
            } catch (Error e) {
                stderr.printf ("%s\n", e.message);
                return false;
            }

            return true;
        }

        public static Adw.AccentColor get_accent_color (Settings ? settings) {
            int color_enum = GDesktop.AccentColor.BLUE;
            if (settings != null) {
                SettingsSchema schema = settings.settings_schema;
                if (schema != null && schema.has_key ("accent-color")) {
                    color_enum = settings?.get_enum ("accent-color");
                }
            }
            Adw.AccentColor color;
            switch (color_enum) {
                default:
                case GDesktop.AccentColor.BLUE:
                    color = Adw.AccentColor.BLUE;
                    break;
                case GDesktop.AccentColor.TEAL:
                    color = Adw.AccentColor.TEAL;
                    break;
                case GDesktop.AccentColor.GREEN:
                    color = Adw.AccentColor.GREEN;
                    break;
                case GDesktop.AccentColor.YELLOW:
                    color = Adw.AccentColor.YELLOW;
                    break;
                case GDesktop.AccentColor.ORANGE:
                    color = Adw.AccentColor.ORANGE;
                    break;
                case GDesktop.AccentColor.RED:
                    color = Adw.AccentColor.RED;
                    break;
                case GDesktop.AccentColor.PINK:
                    color = Adw.AccentColor.PINK;
                    break;
                case GDesktop.AccentColor.PURPLE:
                    color = Adw.AccentColor.PURPLE;
                    break;
                case GDesktop.AccentColor.SLATE:
                    color = Adw.AccentColor.SLATE;
                    break;
            }
            return color;
        }
    }
}
