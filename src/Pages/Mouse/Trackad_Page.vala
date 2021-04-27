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
    public class Trackpad_Widget : Page_Tab {

        private Input_Device touchpad;

        // pointer_accel
        Gtk.Scale accel_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, -1.0, 1.0, 0.1);
        // scroll_factor
        Gtk.Scale scroll_factor_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 10, 0.1);
        // natural_scroll
        Gtk.Switch natural_scroll_switch = new Gtk.Switch ();

        public delegate Gtk.Widget DelegateWidget (Gtk.Widget widget);

        public Trackpad_Widget (string tab_name, DelegateWidget widget, Input_Device touchpad) {
            base (tab_name, widget);
            this.touchpad = touchpad;
            apply_settings_to_widget ();
        }

        public override Gtk.Widget init () {
            var widget = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            widget.add (create_mouse_settings ());
            widget.show_all ();

            return widget;
        }

        Gtk.Widget create_mouse_settings () {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            var list_box = new Gtk.ListBox ();
            list_box.get_style_context ().add_class ("content");

            // pointer_accel
            accel_scale.button_release_event.connect ((event) => {
                var value = (float) accel_scale.get_value ();
                touchpad.settings.pointer_accel = value;
                write_new_settings (@"input type:touchpad pointer_accel $(value)");
                return false;
            });
            var accel_scale_item = new List_Item("Mouse sensitivity", accel_scale);
            list_box.add (accel_scale_item);

            // scroll_factor
            scroll_factor_scale.button_release_event.connect ((event) => {
                var value = (float) scroll_factor_scale.get_value ();
                touchpad.settings.scroll_factor = value;
                write_new_settings (@"input type:touchpad scroll_factor $(value)");
                return false;
            });
            var scroll_factor_item = new List_Item("Scroll Factor", scroll_factor_scale);
            list_box.add (scroll_factor_item);

            // natural_scroll
            natural_scroll_switch.state_set.connect ((value) => {
                touchpad.settings.natural_scroll = value;
                write_new_settings (@"input type:touchpad natural_scroll $(value)");
                return false;
            });
            var natural_scroll_action = new List_Item("Natural Scrolling", natural_scroll_switch);
            natural_scroll_switch.halign = Gtk.Align.END;
            natural_scroll_switch.valign = Gtk.Align.CENTER;
            list_box.add (natural_scroll_action);

            box.add (list_box);
            return box;
        }

        void apply_settings_to_widget () {
            accel_scale.set_value (touchpad.settings.pointer_accel);
            scroll_factor_scale.set_value (touchpad.settings.scroll_factor);
            natural_scroll_switch.set_active (touchpad.settings.natural_scroll);
        }

        void write_new_settings (string str) {
            Functions.set_sway_ipc_value (str);
            Functions.write_settings (Strings.settings_folder_input_pointer, touchpad.get_settings ());
        }
    }
}
