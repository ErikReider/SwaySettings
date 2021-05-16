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
    [GtkTemplate (ui = "/org/erikreider/swaysettings/Window/Window.ui")]
    public class Window : Hdy.ApplicationWindow {
        [GtkChild]
        unowned Hdy.Deck deck;
        [GtkChild]
        unowned Gtk.Box content_box;
        [GtkChild]
        unowned Gtk.Box page_box;

        public Window (Gtk.Application app) {
            Object (application: app);

            try {
                Gtk.CssProvider css_provider = new Gtk.CssProvider ();
                css_provider.load_from_path ("src/style.css");
                Gtk.StyleContext.
                 add_provider_for_screen (Gdk.Screen.get_default (),
                                          css_provider,
                                          Gtk.STYLE_PROVIDER_PRIORITY_USER);
            } catch (Error e) {
                print ("Error: %s\n", e.message);
            }

            ArrayList<SettingsCategory ? > items =
                new ArrayList<SettingsCategory ? >.wrap ({
                SettingsCategory ("Desktop", {
                    SettingsItem ("preferences-desktop-wallpaper",
                                  new Appearance_Page ("Appearance", deck)),

                    SettingsItem ("applications-other",
                                  new Apps ("Applications", deck)),
                }),
                SettingsCategory ("Hardware", {
                    SettingsItem ("input-mouse",
                                  new Mouse_Page ("Inputs", deck)),
                }),
            });

            for (int index = 0; index < items.size; index++) {
                var category = items[index];
                var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                if (index % 2 == 0) box.get_style_context ().add_class ("view");

                var title = new Gtk.Label (category.title);
                title.get_style_context ().add_class ("category-title");

                title.xalign = 0.0f;
                int margin = 8;
                title.set_margin_top (margin);
                title.set_margin_start (margin);
                title.set_margin_bottom (2);
                title.set_margin_end (margin);

                var flow_box = new Gtk.FlowBox ();
                flow_box.vexpand = false;
                flow_box.min_children_per_line = 3;
                flow_box.max_children_per_line = 7;
                flow_box.selection_mode = Gtk.SelectionMode.NONE;
                flow_box.child_activated.connect ((child) => {
                    page_box.remove (page_box.get_children ().nth_data (0));
                    page_box.add (((Item) child).settings_item.page);
                    deck.navigate (Hdy.NavigationDirection.FORWARD);
                });
                foreach (var settings_item in category.items) {
                    var item = new Item (settings_item.page.label,
                                         settings_item.image,
                                         settings_item);
                    flow_box.add (item);
                }

                box.add (title);
                box.add (flow_box);
                content_box.add (box);
            }

            content_box.show_all ();
        }
    }

    struct SettingsCategory {
        string title;
        SettingsItem[] items;

        public SettingsCategory (string title, SettingsItem[] items) {
            this.title = title;
            this.items = items;
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
