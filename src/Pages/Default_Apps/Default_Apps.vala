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
    public class Default_Apps : Page_Scroll {

        public static ArrayList<default_app_data> mime_types = new ArrayList<default_app_data>.wrap ({
            new default_app_data ("Web Browser", "x-scheme-handler/http"),
            new default_app_data ("Mail Client", "x-scheme-handler/mailto"),
            new default_app_data ("Calendar", "text/calendar"),
            new default_app_data ("Music", "audio/x-vorbis+ogg"),
            new default_app_data ("Video", "video/x-ogm+ogg"),
            new default_app_data ("Photos", "image/jpeg"),
            new default_app_data ("Text Editor", "text/plain"),
            new default_app_data ("File Browser", "inode/directory"),
        });

        public Default_Apps (string label, Hdy.Deck deck) {
            base (label, deck);
        }

        public override Gtk.Widget set_child () {
            var list_box = new Gtk.ListBox ();
            list_box.selection_mode = Gtk.SelectionMode.NONE;
            list_box.get_style_context ().add_class ("content");
            for (int i = 0; i < mime_types.size; i++) {
                var mime = mime_types[i];
                Functions.get_default_app (ref mime);

                Functions.get_apps_from_mime (ref mime);
                var row = get_item (mime);
                list_box.add (row);

                mime_types[i] = mime;
            }
            list_box.show_all ();
            return list_box;
        }

        Gtk.Widget get_item (default_app_data def_app) {
            var chooser = new Gtk.AppChooserButton (def_app.mime_type);
            chooser.show_dialog_item = true;
            chooser.show_default_item = true;
            chooser.changed.connect ((combo_box) => {
                var selected_app = chooser.get_app_info();
                if(selected_app == null) return;
                Functions.set_default_for_mimes (def_app, selected_app, def_app.category_name == "Web");
            });
            return new List_Item(def_app.category_name, chooser, 56);
        }
    }

    public class app_data {
        public AppInfo app_info;

        public app_data.with_info (AppInfo app_info) {
            this.app_info = app_info;
        }
    }

    public class default_app_data : app_data {
        public string category_name;
        public string mime_type;
        public string default_mime_type = "text/plain";
        public string used_mime_type;
        public AppInfo default_app;
        public ArrayList<AppInfo> all_apps = new ArrayList<AppInfo>();

        public default_app_data (string category_name, string mime_type) {
            this.mime_type = mime_type;
            this.category_name = category_name;
        }
    }
}
