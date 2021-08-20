/* main.vala
 *
 * Copyright 2021 Erik Reider
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gee;

namespace SwaySettings {

    public class Functions {

        static unowned string settings_gnome_desktop = "org.gnome.desktop.interface";

        public static void scale_image_widget (ref Gtk.Image img, string file_path, int wanted_width, int wanted_height) {
            try {
                Gdk.Pixbuf pix_buf = new Gdk.Pixbuf.from_file (file_path);
                pix_buf = pix_buf.scale_simple (wanted_width, wanted_height, Gdk.InterpType.BILINEAR);
                img.set_from_pixbuf (pix_buf);
            } catch (Error e) {
                print ("Error: %s\n", e.message);
            }
        }

        public delegate void Delegate_walk_func (FileInfo file_info);

        public static int walk_through_dir (string path, Delegate_walk_func func) {
            try {
                var directory = File.new_for_path (path);
                if (!directory.query_exists ()) return 1;
                var enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);
                FileInfo file_prop;
                while ((file_prop = enumerator.next_file ()) != null) {
                    func (file_prop);
                }
            } catch (Error e) {
                print ("Error: %s\n", e.message);
                return 1;
            }
            return 0;
        }

        public static void set_gtk_theme (string type, string theme_name) {
            new Settings (settings_gnome_desktop).set_string (type, theme_name);
            // Also set the .config/gtk-3.0/settings.ini (Firefox ignores the gsettings variable)
            string settings_path = @"$(Environment.get_user_config_dir())/gtk-3.0/settings.ini";
            var file = File.new_for_path (settings_path);
            // TODO: Implement alt action instead of skipping
            if (!file.query_exists ()) return;
            try {
                ArrayList<string> theme_data = new ArrayList<string>();

                // Read data
                var dis = new DataInputStream (file.read ());
                string read_line;
                while ((read_line = dis.read_line (null)) != null) {
                    var split = read_line.split ("=");
                    if (split.length > 1) {
                        string ? looking_for = "";
                        switch (type) {
                            case "gtk-theme":
                                looking_for = "gtk-theme-name";
                                break;
                            case "icon-theme":
                                looking_for = "gtk-icon-theme-name";
                                break;
                        }
                        if (split[0] == looking_for) {
                            read_line = @"$(split[0])=$(theme_name)";
                        }
                    }
                    theme_data.add (@"$(read_line)\n");
                }
                dis.close ();

                // Write data
                var fos = file.replace (
                    null,
                    false,
                    FileCreateFlags.REPLACE_DESTINATION,
                    null);
                var dos = new DataOutputStream (fos);
                foreach (string write_line in theme_data) {
                    dos.put_string (write_line);
                }
                dos.close ();
            } catch (Error e) {
                print ("Error: %s\n", e.message);
                Process.exit (1);
            }
        }

        public static string get_current_gtk_theme (string type) {
            return new Settings (settings_gnome_desktop).get_string (type) ?? "";
        }

        public static ArrayList<string> get_gtk_themes (string type) {
            ArrayList<string> dirs = new ArrayList<string>.wrap ((GLib.Environment.get_system_data_dirs ()));

            dirs.add (GLib.Environment.get_user_data_dir ());
            for (var i = 0; i < dirs.size; i++) {
                string item = dirs[i];
                dirs[i] = item + (item[item.length - 1] == '/' ? "" : "/") + type;
            }
            dirs.add (@"$(GLib.Environment.get_home_dir ())/.$(type)");
            var paths = dirs.filter ((path) => GLib.FileUtils.test (path, GLib.FileTest.IS_DIR));

            var themes = new ArrayList<string>();

            var min_ver = Gtk.get_minor_version ();
            if (min_ver % 2 != 0) min_ver++;

            paths.foreach ((path) => {
                try {
                    var directory = File.new_for_path (path);
                    var enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);
                    FileInfo file_prop;
                    while ((file_prop = enumerator.next_file ()) != null) {
                        string name = file_prop.get_name ();
                        string folder_path = @"$(path)/$(name)";
                        if (GLib.FileType.DIRECTORY != file_prop.get_file_type ()) continue;
                        if (path.contains (@"flatpak/exports/share/$(type)")) continue;

                        switch (type) {
                            case "themes":
                                var new_path = @"$(folder_path)/gtk-3.";
                                var file_v3 = File.new_for_path (@"$(new_path)0/gtk.css");
                                var file_min_ver = File.new_for_path (new_path + min_ver.to_string () + "/gtk.css");
                                if (file_v3.query_exists () || file_min_ver.query_exists ()) {
                                    themes.add (name);
                                }
                                break;
                            case "icons":
                                var theme_file = File.new_for_path (@"$(folder_path)/index.theme");
                                var theme_cache = File.new_for_path (@"$(folder_path)/icon-theme.cache");
                                var file_type = theme_file.query_file_type (FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                                var exists = theme_file.query_exists () && theme_cache.query_exists ();
                                if (exists && GLib.FileType.REGULAR == file_type) {
                                    var dir = File.new_for_path (folder_path);
                                    var enu = dir.enumerate_children (FileAttribute.STANDARD_NAME, 0);
                                    FileInfo prop;
                                    bool is_icon = false;
                                    while ((prop = enu.next_file ()) != null) {
                                        if (prop.get_file_type () == GLib.FileType.DIRECTORY) {
                                            string f_name = prop.get_name ().down ();
                                            // validate ex: 384x384 or 16x16
                                            bool valid_res = false;
                                            var name_split = f_name.split ("x");
                                            if (name_split.length == 2) {
                                                valid_res = int.parse (name_split[0]) != 0 && int.parse (name_split[0]) != 0;
                                            }

                                            if (f_name.contains ("scalable") || f_name.contains ("symbolic") || valid_res) {
                                                is_icon = true;
                                                break;
                                            }
                                        }
                                    }
                                    if (is_icon) themes.add (name);
                                }
                                break;
                        }
                    }
                } catch (Error e) {
                    print ("Error: %s\n", e.message);
                }

                return true;
            });
            themes.sort (((a, b) => a > b ? 1 : -1));
            return themes;
        }

        public static ArrayList<string> get_wallpapers () {
            ArrayList<string> default_paths = new ArrayList<string>.wrap ({
                "/usr/share/backgrounds",
                "/usr/share/wallpapers",
                "/usr/local/share/wallpapers",
                "/usr/local/share/backgrounds",
            });

            ArrayList<string> wallpaper_paths = new ArrayList<string>();
            var supported_formats = new ArrayList<string>.wrap ({ "jpg" });

            Gdk.Pixbuf.get_formats ().foreach ((pxfmt) => supported_formats.add (pxfmt.get_name ()));

            for (int i = 0; i < default_paths.size; i++) {
                string path = default_paths[i];
                walk_through_dir (path, (file_info) => {
                    switch (file_info.get_file_type ()) {
                        case GLib.FileType.REGULAR:
                            string name = file_info.get_name ();
                            string suffix = name[name.last_index_of_char ('.') + 1 :];
                            if (supported_formats.contains (suffix)) {
                                wallpaper_paths.add (path + "/" + file_info.get_name ());
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

        public static File check_settings_folder_exists (string file_name) {
            string basePath = GLib.Environment.get_user_config_dir () + "/sway/.generated_settings";
            // Checks if directory exists. Creates one if none
            if (!GLib.FileUtils.test (basePath, GLib.FileTest.IS_DIR)) {
                try {
                    var file = File.new_for_path (basePath);
                    file.make_directory ();
                } catch (Error e) {
                    print ("Error: %s\n", e.message);
                }
            }
            // Checks if file exists. Creates one if none
            var file = File.new_for_path (basePath + @"/$(file_name)");
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

        public static void write_settings (string file_name, Array<string> lines) {
            try {
                var file = check_settings_folder_exists (file_name);
                var fos = file.replace (null,
                                        false,
                                        FileCreateFlags.REPLACE_DESTINATION,
                                        null);
                var dos = new DataOutputStream (fos);
                dos.put_string ("# GENERATED BY SWAYSETTINGS. DON'T MODIFY THIS FILE!\n");
                foreach (string line in lines.data) {
                    dos.put_string (line);
                }
            } catch (Error e) {
                print ("Error: %s\n", e.message);
                Process.exit (1);
            }
        }

        public static void set_default_for_mimes (default_app_data def_data,
                                                  AppInfo selected_app,
                                                  bool web = false) {
            string app_id = selected_app.get_id ();
            string cmd;
            if (web) {
                cmd = @"xdg-settings set default-web-browser $(app_id)";
            } else {
                cmd = @"xdg-mime default $(app_id) $(def_data.mime_type)";
            }

            new Thread<void>("set_default_app", () => {
                Posix.system (cmd);
            });
        }

        public static ArrayList<DesktopAppInfo> get_startup_apps () {
            ArrayList<DesktopAppInfo> apps = new ArrayList<DesktopAppInfo>();
            string auto_start_path = @"$(Environment.get_user_config_dir())/autostart";
            walk_through_dir (auto_start_path, (file_info) => {
                // Implement "X-GNOME-Autostart-enabled" check???
                var app_path = @"$(auto_start_path)/$(file_info.get_name())";
                var app = new DesktopAppInfo.from_filename (app_path);
                if (app == null) return;
                apps.add (app);
            });
            return apps;
        }

        public static async void add_app_to_startup (string filename) {
            string cmd = @"cp $filename $(Environment.get_user_config_dir())/autostart/";
            Posix.system (cmd);
        }

        public static async void remove_app_from_startup (string filename) {
            Posix.system (@"rm $filename");
        }

        public static bool is_swaync_installed () {
            return GLib.Environment.find_program_in_path ("swaync") != null;
        }

        public static string get_style_path () {
            string[] paths = {};
            foreach (var path in GLib.Environment.get_system_config_dirs ()) {
                paths += Path.build_path (Path.DIR_SEPARATOR.to_string (),
                                          path, "swaysettings/style.css");
            }

            string path = "";
            foreach (string try_path in paths) {
                if (File.new_for_path (try_path).query_exists ()) {
                    path = try_path;
                    break;
                }
            }
            if (path == "") {
                stderr.printf ("COULD NOT FIND CSS FILE! REINSTALL THE PACKAGE!\n");
                Process.exit (1);
            }
            return path;
        }
    }
}
