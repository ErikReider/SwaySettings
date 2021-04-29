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
    [GtkTemplate (ui = "/org/erikreider/swaysettings/Window/Window.ui")]
    public class Window : Hdy.ApplicationWindow {
        [GtkChild]
        unowned Hdy.Deck deck;
        [GtkChild]
        unowned Gtk.FlowBox flow_box;
        [GtkChild]
        unowned Gtk.Box page_box;

        public Window (Gtk.Application app) {
            Object (application: app);

            SettingsItem[] items = {
                SettingsItem ("preferences-desktop-wallpaper", new Appearance_Page ("Appearance", deck)),
                SettingsItem ("input-mouse", new Mouse_Page ("Inputs", deck)),
                SettingsItem ("input-mouse", new Default_Apps ("Default Apps", deck)),
            };

            flow_box.child_activated.connect ((child) => {
                var item = (Item) child;
                page_box.remove (page_box.get_children ().nth_data (0));
                page_box.add (item.settings_item.page);
                deck.navigate (Hdy.NavigationDirection.FORWARD);
            });

            foreach (var item in items) {
                create_setting (item);
            }

            flow_box.show_all ();
        }

        void create_setting (SettingsItem settings_item) {
            var item = new Item (settings_item.page.label, settings_item.image, settings_item);
            flow_box.add (item);
        }
    }

    public struct SettingsItem {
        string image;
        Page page;

        SettingsItem (string image, Page page) {
            this.image = image;
            this.page = page;
        }
    }
}
