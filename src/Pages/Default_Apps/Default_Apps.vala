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
            new default_app_data ("Web", "x-scheme-handler/http"),
            new default_app_data ("Mail", "x-scheme-handler/mailto"),
            new default_app_data ("Calendar", "text/calendar"),
            new default_app_data ("Music", "audio/x-vorbis+ogg"),
            new default_app_data ("Video", "video/x-ogm+ogg"),
            new default_app_data ("Photos", "image/jpeg"),
        });

        public Default_Apps (string label, Hdy.Deck deck) {
            base (label, deck);
        }

        public override Gtk.Widget set_child () {
            var list_box = new Gtk.ListBox ();
            list_box.selection_mode = Gtk.SelectionMode.NONE;
            list_box.get_style_context ().add_class ("content");
            for (int i = 0; i < mime_types.size; i++) {
                mime_types[i].application_name = Functions.get_default_app (mime_types[i]);
                var row = get_item (mime_types[i]);
                list_box.add (row);
            }
            list_box.show_all ();
            return list_box;
        }

        Hdy.ComboRow get_item (default_app_data apps) {
            var row = new Hdy.ComboRow ();
            row.set_title (apps.category_name);
            ListStore liststore = new ListStore (typeof (Hdy.ValueObject));
            liststore.append (new Hdy.ValueObject (apps.application_name));
            // if (apps.data.length > 0) {
            // int selected_index = 0;
            // for (var i = 0; i < apps.data.length; i++) {
            // print (@"$(apps.data[i].application_name)\n");
            // var mode = monitor_specs.all_modes.data[i];
            // if (mode.to_string () == monitor_specs.mode.to_string ()) selected_index = i;
            // liststore.append (new Hdy.ValueObject (mode.to_string ()));
            // }
            // row.set_selected_index (selected_index);
            // }
            row.bind_name_model ((ListModel) liststore, (item) => ((Hdy.ValueObject)item).get_string ());
            return row;
        }
    }

    public class app_data {
        public string image_url;
        public string application_name;
    }

    public class default_app_data : app_data {
        public string category_name;
        public string mime_type;
        public string default_mime_type = "text/plain";

        public default_app_data (string category_name, string mime_type) {
            this.mime_type = mime_type;
            this.category_name = category_name;
        }
    }
}
