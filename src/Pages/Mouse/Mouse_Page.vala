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
    public class Mouse_Widget : Page_Tab {
        private Input_Device mouse;

        // pointer_accel
        List_Slider accel_slider;
        // scroll_factor
        List_Slider scroll_factor_slider;
        // natural_scroll
        List_Switch natural_scroll_switch;
        // accel_profile
        List_Combo_Enum accel_profile_row;

        public delegate Gtk.Widget DelegateWidget (Gtk.Widget widget);

        public Mouse_Widget (string tab_name, DelegateWidget widget, Input_Device mouse) {
            base (tab_name, widget);
            this.mouse = mouse;
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
            accel_slider = new List_Slider ("Mouse Sensitivity", -1.0, 1.0, 0.1, (event, slider) => {
                var value = (float) slider.get_value ();
                mouse.settings.pointer_accel = value;
                write_new_settings (@"input type:pointer pointer_accel $(value)");
                return false;
            });
            list_box.add (accel_slider);

            // scroll_factor
            scroll_factor_slider = new List_Slider ("Scroll Factor", 0.0, 10, 0.1, (event, slider) => {
                var value = (float) slider.get_value ();
                mouse.settings.scroll_factor = value;
                write_new_settings (@"input type:pointer scroll_factor $(value)");
                return false;
            });
            list_box.add (scroll_factor_slider);

            // natural_scroll
            natural_scroll_switch = new List_Switch ("Natural Scrolling", (value) => {
                mouse.settings.natural_scroll = value;
                write_new_settings (@"input type:pointer natural_scroll $(value)");
                return false;
            });
            list_box.add (natural_scroll_switch);

            // accel_profile
            accel_profile_row = new List_Combo_Enum ("Acceleration Profile", typeof (Inp_Dev_Settings.accel_profiles), () => {
                if (mouse.settings == null) return;
                var profile = (Inp_Dev_Settings.accel_profiles)accel_profile_row.get_selected_index ();
                mouse.settings.accel_profile = profile;
                write_new_settings (@"input type:pointer accel_profile $(Inp_Dev_Settings.accel_profiles.parse_enum(profile))");
            });
            list_box.add (accel_profile_row);

            box.add (list_box);
            return box;
        }

        void apply_settings_to_widget () {
            // pointer_accel
            accel_slider.set_value (mouse.settings.pointer_accel);
            // scroll_factor
            scroll_factor_slider.set_value (mouse.settings.scroll_factor);
            // natural_scroll
            natural_scroll_switch.set_active (mouse.settings.natural_scroll);
            // accel_profile
            accel_profile_row.set_selected_from_enum (mouse.settings.accel_profile);
        }

        void write_new_settings (string str) {
            Functions.set_sway_ipc_value (str);
            Functions.write_settings (Strings.settings_folder_input_pointer, mouse.get_settings ());
        }
    }
}
