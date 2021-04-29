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

namespace SwaySettings {
    [GtkTemplate (ui = "/org/erikreider/swaysettings/Item/Item.ui")]
    public class Item : Gtk.FlowBoxChild {

        public SettingsItem settings_item;

        [GtkChild]
        public unowned Gtk.Image btn_image;
        [GtkChild]
        public unowned Gtk.Label btn_label;


        public Item (string text, string icon_name, SettingsItem settings_item) {
            Object ();
            this.settings_item = settings_item;

            btn_label.set_text (text);
            if (icon_name != "") btn_image.set_from_icon_name (icon_name, Gtk.IconSize.DIALOG);

            show_all ();
        }
    }
}
