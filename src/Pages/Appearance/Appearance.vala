/* window.vala
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
    public class Appearance_Page : Page_Tabbed {

        public Appearance_Page (string label, Hdy.Deck deck) {
            base (label, deck);
        }

        public override TabItem[] tabs () {
            TabItem[] tabs = {
                new TabItem ("Background", background_tab ()),
                new TabItem ("Themes", theme_tab ()),
            };
            return tabs;
        }

        Gtk.Widget background_tab () {
            var item_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            item_box.expand = true;
            var preview_image = new Gtk.Image ();
            preview_image.show_all ();
            preview_image.icon_name = "folder";
            preview_image.pixel_size = 128;
            preview_image.halign = Gtk.Align.CENTER;
            preview_image.valign = Gtk.Align.START;

            var wallpaper_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            wallpaper_box.expand = true;

            // Custom wallpapers
            var custom_header = new Gtk.Label ("Custom Wallpapers");
            var custom_flow_box = new Gtk.FlowBox ();
            custom_flow_box.max_children_per_line = 8;
            custom_flow_box.min_children_per_line = 1;

            for (var i = 0; i < 40; i++) {
                custom_flow_box.add (new Gtk.Label (i.to_string ()));
            }

            wallpaper_box.add (custom_header);
            wallpaper_box.add (custom_flow_box);

            // Standard wallpapers
            var wallp_header = new Gtk.Label ("Standard Wallpapers");
            var wallp_flow_box = new Gtk.FlowBox ();
            wallp_flow_box.max_children_per_line = 8;
            wallp_flow_box.min_children_per_line = 1;
            for (var i = 0; i < 40; i++) {
                wallp_flow_box.add (new Gtk.Label (i.to_string ()));
            }

            wallpaper_box.add (wallp_header);
            wallpaper_box.add (wallp_flow_box);




            wallpaper_box.show_all ();

            item_box.add (preview_image);
            item_box.add (get_scroll_widget (wallpaper_box, 1280, int.MAX));
            item_box.show_all ();
            return item_box;
        }

        Gtk.Widget theme_tab () {
            var list_box = new Gtk.ListBox ();
            list_box.get_style_context ().add_class ("content");

            var gtk_theme_expander = new Hdy.ComboRow ();
            gtk_theme_expander.set_title ("GTK Theme");

            ListStore liststore = new ListStore (typeof (Hdy.ValueObject));
            string current_theme = get_current_gtk_theme ("gtk-theme");
            ArrayList<string> gtk_themes = get_gtk_themes ();
            int selected_index = 0;
            for (int i = 0; i < gtk_themes.size; i++) {
                var theme_name = gtk_themes[i];
                liststore.append (new Hdy.ValueObject (theme_name));
                if (current_theme == theme_name) selected_index = i;
            }

            gtk_theme_expander.bind_name_model ((ListModel) liststore, (item) => {
                return ((Hdy.ValueObject)item).get_string ();
            });
            gtk_theme_expander.set_selected_index (selected_index);
            gtk_theme_expander.notify["selected-index"].connect ((sender, property) => {
                var theme = gtk_themes.get (((Hdy.ComboRow)sender).get_selected_index ());
                set_gtk_theme ("gtk-theme", theme);
            });

            list_box.add (gtk_theme_expander);
            return get_scroll_widget (list_box);
        }

        void set_gtk_theme (string type, string theme_name) {
            Posix.system ("gsettings set org.gnome.desktop.interface " + type + " '" + theme_name + "'");
        }

        string get_current_gtk_theme (string type) {
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

        ArrayList<string> get_gtk_themes () {
            ArrayList<string> dirs = new ArrayList<string>.wrap ((GLib.Environment.get_system_data_dirs ()));

            dirs.add (GLib.Environment.get_user_data_dir ());
            for (var i = 0; i < dirs.size; i++) {
                string item = dirs[i];
                dirs[i] = item + (item[item.length - 1] == '/' ? "" : "/") + "themes";
            }
            dirs.add (GLib.Environment.get_home_dir () + "/.themes");
            var paths = dirs.filter ((path) => GLib.FileUtils.test (path, GLib.FileTest.IS_DIR));

            var themes = new ArrayList<string>.wrap ({ "Adwaita", "HighContrast", "HighContrastInverse" });

            var min_ver = Gtk.get_minor_version ();
            if (min_ver % 2 != 0) min_ver++;

            paths.foreach ((path) => {
                try {
                    var directory = File.new_for_path (path);
                    var enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);
                    FileInfo file_prop;
                    while ((file_prop = enumerator.next_file ()) != null) {
                        string name = file_prop.get_name ();
                        var new_path = path + "/" + name + "/gtk-3.";
                        var file_v3 = File.new_for_path (new_path + "0/gtk.css");
                        var file_min_ver = File.new_for_path (new_path + min_ver.to_string () + "/gtk.css");
                        if (file_v3.query_exists () || file_min_ver.query_exists ()) {
                            if (!themes.contains (name)) themes.add (name);
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
    }
}
