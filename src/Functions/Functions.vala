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

        public static void scale_image_widget (ref Gtk.Image img, string file_path, int wanted_width, int wanted_height) {
            try {
                Gdk.Pixbuf pix_buf = new Gdk.Pixbuf.from_file_at_size (file_path, wanted_width, wanted_height);
                img.set_from_pixbuf (pix_buf);
            } catch (Error e) {
                print ("Error: %s\n", e.message);
            }
        }

        public delegate void Delegate_walk_func (FileInfo file_info);

        public static int walk_through_dir (string path, Delegate_walk_func func) {
            try {
                var directory = File.new_for_path (path);
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
            Posix.system ("gsettings set org.gnome.desktop.interface " + type + " '" + theme_name + "'");
        }

        public static string get_current_gtk_theme (string type) {
            string ls_stdout, ls_stderr;
            int ls_status;
            string cmd = "gsettings get org.gnome.desktop.interface " + type;
            try {
                Process.spawn_command_line_sync (cmd, out ls_stdout, out ls_stderr, out ls_status);
            } catch (Error e) {
                print ("Error: %s\n", e.message);
            }
            return ls_stdout.split ("'")[1];
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
                                var exists = theme_file.query_exists () && theme_cache.query_exists();
                                if (exists && GLib.FileType.REGULAR == file_type) {
                                    themes.add (name);
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
            ArrayList<string> default_paths = new ArrayList<string>.wrap ({ "/usr/share/backgrounds" });

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

        public static void set_wallpaper (string path) {
            if (path == null) return;
            Posix.system (@"cp $(path) $(Environment.get_home_dir())/.cache/wallpaper");
            Posix.system (@"swaymsg \"output * bg $(Environment.get_home_dir())/.cache/wallpaper fill\"");
        }
    }
}
