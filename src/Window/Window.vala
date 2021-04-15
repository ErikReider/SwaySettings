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
                new SettingsItem ("", new Appearance_Page ("Appearance", deck)),
                new SettingsItem ("", new Appearance_Page ("Displays", deck)),
                new SettingsItem ("", new Appearance_Page ("General", deck)),
            };

            foreach (var item in items) {
                create_setting (item);
            }

            flow_box.show_all ();
        }

        void create_setting (SettingsItem settingsItem) {
            var item = new Item (settingsItem.page.label);
            flow_box.add (item);

            item.enter_notify_event.connect (() => true);
            item.clicked.connect ((event) => {
                page_box.remove (page_box.get_children ().nth_data (0));
                page_box.add (settingsItem.page);
                deck.navigate (Hdy.NavigationDirection.FORWARD);
            });
        }
    }

    public class SettingsItem {
        public string image;
        public Page page;

        public SettingsItem (string image, Page page) {
            this.image = image;
            this.page = page;
        }
    }
}
