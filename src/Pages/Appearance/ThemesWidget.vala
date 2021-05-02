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
    public class Themes_Widget : Page_Tab {

        private Gtk.ListBox list_box;

        public Themes_Widget (string tab_name) {
            base (tab_name);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            list_box = new Gtk.ListBox ();
            list_box.get_style_context ().add_class ("content");

            gtk_theme ("GTK Application Theme", "gtk-theme", "themes");
            gtk_theme ("GTK Icon Theme", "icon-theme", "icons");

            box.add (list_box);
            box.set_margin_top (8);
            box.set_margin_start (8);
            box.set_margin_bottom (8);
            box.set_margin_end (8);
            box.show_all ();
            this.add (Page.get_scroll_widget (box, false));
        }

        public void gtk_theme (string title, string setting_name, string folder_name) {
            var gtk_theme_expander = new Hdy.ComboRow ();
            gtk_theme_expander.set_title (title);

            ListStore liststore = new ListStore (typeof (Hdy.ValueObject));
            string current_theme = Functions.get_current_gtk_theme (setting_name);
            ArrayList<string> gtk_themes = Functions.get_gtk_themes (folder_name);
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
                Functions.set_gtk_theme (setting_name, theme);
            });

            list_box.add (gtk_theme_expander);
        }
    }
}
