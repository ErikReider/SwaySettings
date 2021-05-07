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
    public class Mouse_Page : Page_Tabbed {
        Input_Device mouse = Input_Device ();
        Input_Device touchpad = Input_Device ();
        bool has_pointer = false;
        bool has_touchpad = false;

        public Mouse_Page (string label, Hdy.Deck deck) {
            base (label, deck, "No input devices detected...");
        }

        public override Page_Tab[] tabs () {
            init_input_devices ();
            Page_Tab[] tabs = {};
            if (has_pointer) tabs += new Mouse_Widget ("Mouse", mouse);
            if (has_touchpad) tabs += new Trackpad_Widget ("Touchpad", touchpad);
            return tabs;
        }

        void init_input_devices () {
            var ipc_output = Functions.run_sway_ipc (Functions.Sway_IPC.get_inputs).get_array ();
            foreach (var elem in ipc_output.get_elements ()) {
                var obj = elem.get_object ();
                Input_Types type = Input_Types.parse_string (obj.get_string_member ("type") ?? "");
                if (Input_Types.NEITHER == type) continue;
                if (Input_Types.pointer == type) {
                    if (has_pointer) continue;
                    has_pointer = true;
                }
                if (Input_Types.touchpad == type) {
                    if (has_touchpad) continue;
                    has_touchpad = true;
                }
                get_device_settings (obj, type);
            }
        }

        void get_device_settings (Json.Object ? obj, Input_Types type) {
            var device = Input_Device ();
            device.type = type;
            device.identifier = obj.get_string_member ("identifier");
            device.settings = new Inp_Dev_Settings ();
            var lib = obj.get_object_member ("libinput");
            // Used to get the default values
            var defs = new Inp_Dev_Settings ();

            // send_events
            var send_events_string = lib.get_string_member_with_default ("send_events", "enabled");
            device.settings.send_events = Inp_Dev_Settings.Input_events.parse (send_events_string);
            // pointer_accel
            device.settings.pointer_accel = (float) lib.get_double_member_with_default ("accel_speed", 0);
            // accel_profile
            var accel_profile_string = lib.get_string_member_with_default ("accel_profile", "adaptive");
            device.settings.accel_profile = Inp_Dev_Settings.accel_profiles.parse (accel_profile_string);
            // natural_scroll
            var natural_scroll_string = lib.get_string_member_with_default ("natural_scroll", "disabled");
            device.settings.natural_scroll = Inp_Dev_Settings.parse (natural_scroll_string);
            // left_handed
            var left_handed_string = lib.get_string_member_with_default ("left_handed", "disabled");
            device.settings.left_handed = Inp_Dev_Settings.parse (left_handed_string);
            // scroll_factor
            var scroll_factor_double = obj.get_double_member_with_default ("scroll_factor", (double) defs.scroll_factor);
            device.settings.scroll_factor = (float) scroll_factor_double;
            // middle_emulation
            var middle_emulation_string = lib.get_string_member_with_default ("middle_emulation", "disabled");
            device.settings.middle_emulation = Inp_Dev_Settings.parse (middle_emulation_string);

            if (type == Input_Types.pointer) {
                mouse = device;
            } else if (type == Input_Types.touchpad) {
                // scroll_method
                var scroll_method_string = lib.get_string_member_with_default ("scroll_method", "two_finger");
                device.settings.scroll_method = Inp_Dev_Settings.scroll_methods.parse (scroll_method_string);

                touchpad = device;
            }
        }
    }

    public abstract class Input_Tab : Page_Tab {
        private Input_Device input_dev;

        string input_type;

        protected Input_Tab (string tab_name, Input_Types input_type, Input_Device input_dev) {
            base (tab_name);
            this.input_type = Input_Types.parse_enum (input_type);
            this.input_dev = input_dev;

            this.add (Page.get_scroll_widget (create_mouse_settings ()));
        }

        Gtk.Widget create_mouse_settings () {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            var list_box = new Gtk.ListBox ();
            list_box.get_style_context ().add_class ("content");

            var options = get_options ();
            foreach (var option in options) {
                if (option != null) list_box.add (option);
            }

            box.add (list_box);
            return box;
        }

        public abstract ArrayList<Gtk.Widget> get_options ();

        void write_new_settings (string str) {
            Functions.set_sway_ipc_value (str);
            Functions.write_settings (Strings.settings_folder_input_pointer, input_dev.get_settings ());
        }

        // pointer_accel
        public Gtk.Widget get_pointer_accel () {
            var row = new List_Slider ("Mouse Sensitivity", input_dev.settings.pointer_accel,
                                       -1.0, 1.0, 0.1, (slider) => {
                var value = (float) slider.get_value ();
                input_dev.settings.pointer_accel = value;
                var str_value = value.to_string().replace(",", ".");
                write_new_settings (@"input type:$(input_type) pointer_accel $(str_value)");
                return false;
            });
            row.add_mark (0.0, Gtk.PositionType.TOP);
            return row;
        }

        // scroll_factor
        public Gtk.Widget get_scroll_factor () {
            var row = new List_Slider ("Scroll Factor", input_dev.settings.scroll_factor,
                                       0.0, 10, 1, (slider) => {
                var value = (float) slider.get_value ();
                input_dev.settings.scroll_factor = value;
                var str_value = value.to_string().replace(",", ".");
                write_new_settings (@"input type:$(input_type) scroll_factor $(str_value)");
                return false;
            });
            row.add_mark (1.0, Gtk.PositionType.TOP);
            return row;
        }

        // natural_scroll
        public Gtk.Widget get_natural_scroll () {
            var row = new List_Switch ("Natural Scrolling", input_dev.settings.natural_scroll, (value) => {
                input_dev.settings.natural_scroll = value;
                write_new_settings (@"input type:$(input_type) natural_scroll $(value)");
                return false;
            });
            return row;
        }

        // accel_profile
        public Gtk.Widget get_accel_profile () {
            var row = new List_Combo_Enum ("Acceleration Profile",
                                           input_dev.settings.accel_profile,
                                           typeof (Inp_Dev_Settings.accel_profiles),
                                           (index) => {
                var profile = (Inp_Dev_Settings.accel_profiles)index;
                input_dev.settings.accel_profile = profile;
                write_new_settings (@"input type:$(input_type) accel_profile $(Inp_Dev_Settings.accel_profiles.parse_enum(profile))");
            });
            return row;
        }
    }

    public enum Input_Types {
        pointer,
        touchpad,
        NEITHER;

        public static string parse_enum (Input_Types val) {
            EnumClass enumc = (EnumClass) typeof (Input_Types).class_ref ();
            return enumc.get_value_by_name (val.to_string ()).value_nick;
        }

        public static Input_Types parse_string (string val) {
            EnumClass enumc = (EnumClass) typeof (Input_Types).class_ref ();
            unowned EnumValue ? eval = enumc.get_value_by_nick (val);
            if (eval == null) return Input_Types.NEITHER;
            return (Input_Types) eval.value;
        }
    }

    public struct Input_Device {
        string identifier;
        Input_Types type;
        Inp_Dev_Settings settings;

        public Array<string> get_settings () {
            Array<string> lines = new Array<string>();
            lines.append_val (@"input type:$(Input_Types.parse_enum(type)) {\n");
            var settings_lines = get_type_settings ();
            foreach (string line in settings_lines.data) {
                lines.append_val (line);
            }
            lines.append_val ("}\n");
            return lines;
        }

        private string get_string_line (string line) {
            return @"\t$(line)\n";
        }

        private Array<string> get_type_settings () {
            Array<string> settings_list = new Array<string>();
            // events
            settings_list.append_val (get_string_line (Inp_Dev_Settings.Input_events.get_line (settings.send_events)));
            // pointer_accel
            settings_list.append_val (get_string_line (@"pointer_accel $(settings.pointer_accel)"));
            // accel_profile
            settings_list.append_val (get_string_line (Inp_Dev_Settings.accel_profiles.get_line (settings.accel_profile)));
            // natural_scroll
            settings_list.append_val (get_string_line (@"natural_scroll $(Inp_Dev_Settings.parse_bool(settings.natural_scroll))"));
            // left_handed
            settings_list.append_val (get_string_line (@"left_handed $(Inp_Dev_Settings.parse_bool(settings.left_handed))"));
            // scroll_factor
            settings_list.append_val (get_string_line (@"scroll_factor $(settings.scroll_factor)"));
            // middle_emulation
            settings_list.append_val (get_string_line (@"middle_emulation $(Inp_Dev_Settings.parse_bool(settings.middle_emulation))"));
            if (Input_Types.touchpad == type) {
                // scroll_method
                settings_list.append_val (get_string_line (Inp_Dev_Settings.scroll_methods.get_line (settings.scroll_method)));
                // dwt
                settings_list.append_val (get_string_line (@"dwt $(Inp_Dev_Settings.parse_bool(settings.dwt))"));
                // tap
                settings_list.append_val (get_string_line (@"tap $(Inp_Dev_Settings.parse_bool(settings.tap))"));
                // tap_button_map
                settings_list.append_val (get_string_line (Inp_Dev_Settings.tap_button_maps.get_line (settings.tap_button_map)));
                // click_method
                settings_list.append_val (get_string_line (Inp_Dev_Settings.click_methods.get_line (settings.click_method)));
            }
            return settings_list;
        }
    }

    public class Inp_Dev_Settings {
        public accel_profiles accel_profile = accel_profiles.adaptive;
        public bool dwt = false;
        public Input_events send_events = Input_events.enabled;
        public bool left_handed = false;
        public bool natural_scroll = false;
        public float pointer_accel = 0;
        public float scroll_factor = 1;
        public bool middle_emulation = false;
        public bool tap = false;
        public click_methods click_method = click_methods.clickfinger;
        public scroll_methods scroll_method = scroll_methods.two_finger;
        public tap_button_maps tap_button_map = tap_button_maps.lrm;

        public static bool parse (string value) {
            return value == "enabled" ? true : false;
        }

        public static string parse_bool (bool value) {
            return value ? "enabled" : "disabled";
        }

        public enum accel_profiles {
            adaptive, flat;

            public static accel_profiles parse (string value) {
                if (value == "flat") return flat;
                return adaptive;
            }

            public static string parse_enum (accel_profiles profile) {
                if (profile == flat) return "flat";
                return "adaptive";
            }

            public static string get_line (accel_profiles val) {
                string value = val == accel_profiles.flat ? "flat" : "adaptive";
                return @"accel_profile $(value)";
            }
        }
        public enum Input_events {
            enabled, disabled, disabled_on_external_mouse, toggle;

            public static Input_events parse (string value) {
                if (value == "disabled") return disabled;
                else if (value == "disabled_on_external_mouse") return disabled_on_external_mouse;
                return enabled;
            }

            public static string get_line (Input_events val) {
                string value = "enabled";
                if (val == Input_events.disabled) value = "disabled";
                else if (val == Input_events.disabled_on_external_mouse) value = "disabled_on_external_mouse";
                return @"events $(value)";
            }
        }
        public enum scroll_methods {
            none, two_finger, edge, on_button_down;

            public static scroll_methods parse (string value) {
                if (value == "two_finger") return two_finger;
                if (value == "edge") return edge;
                if (value == "on_button_down") return on_button_down;
                return none;
            }

            public static string get_line (scroll_methods val) {
                string value = "two_finger";
                if (val == scroll_methods.none) value = "none";
                else if (val == scroll_methods.on_button_down) value = "on_button_down";
                else if (val == scroll_methods.edge) value = "edge";
                return @"scroll_method $(value)";
            }
        }
        public enum click_methods {
            none, button_areas, clickfinger;

            public static click_methods parse (string value) {
                if (value == "button_areas") return button_areas;
                if (value == "click_finger") return clickfinger;
                return none;
            }

            public static string get_line (click_methods val) {
                string value = "clickfinger";
                if (val == click_methods.none) value = "none";
                else if (val == click_methods.button_areas) value = "button_areas";
                return @"click_method $(value)";
            }
        }
        public enum tap_button_maps {
            lrm, lmr;

            public static tap_button_maps parse (string value) {
                if (value == "lrm") return lrm;
                return lmr;
            }

            public static string get_line (tap_button_maps val) {
                string value = val == tap_button_maps.lrm ? "lrm" : "lmr";
                return @"tap_button_map $(value)";
            }
        }
    }
}
