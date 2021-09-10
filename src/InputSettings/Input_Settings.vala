using Gee;

namespace SwaySettings {
    public enum Input_Types {
        pointer,
        touchpad,
        keyboard,
        NEITHER;

        public string parse () {
            EnumClass enumc = (EnumClass) typeof (Input_Types).class_ref ();
            return enumc.get_value_by_name (this.to_string ()).value_nick;
        }

        public static Input_Types parse_string (string val) {
            EnumClass enumc = (EnumClass) typeof (Input_Types).class_ref ();
            unowned EnumValue ? eval = enumc.get_value_by_nick (val);
            if (eval == null) return Input_Types.NEITHER;
            return (Input_Types) eval.value;
        }
    }

    public class Input_Device {
        public string identifier;
        public Input_Types type;
        public Inp_Dev_Settings settings;

        public Input_Device (string identifier, Input_Types type) {
            this.identifier = identifier;
            this.type = type;
            this.settings = new Inp_Dev_Settings ();
        }

        public Array<string> get_settings () {
            Array<string> lines = new Array<string>();
            lines.append_val (@"input type:$(type.parse()) {\n");
            var settings_lines = get_type_settings ();
            foreach (string line in settings_lines.data) {
                lines.append_val (get_string_line (line));
            }
            lines.append_val ("}\n");
            return lines;
        }

        private string get_string_line (string line) {
            return @"\t$(line)\n";
        }

        private Array<string> get_type_settings () {
            Array<string> settings_list = new Array<string>();

            switch (type) {
                case Input_Types.keyboard:
                    // xkb_layout_names
                    string[] array = {};
                    foreach (var lang in settings.xkb_layout_names) {
                        array += lang.name;
                    }
                    settings_list.append_val (
                        @"xkb_layout \"$(string.joinv (", ", array))\"");
                    break;
                case Input_Types.pointer:
                case Input_Types.touchpad:
                    // events
                    settings_list.append_val (
                        settings.doem.get_line ());

                    // pointer_accel
                    settings_list.append_val (
                        @"pointer_accel $(settings.pointer_accel)");

                    // accel_profile
                    settings_list.append_val (
                        settings.accel_profile.get_line ());

                    // natural_scroll
                    settings_list.append_val (
                        @"natural_scroll $(Inp_Dev_Settings.parse_bool(settings.natural_scroll))");

                    // left_handed
                    settings_list.append_val (
                        @"left_handed $(Inp_Dev_Settings.parse_bool(settings.left_handed))");

                    // scroll_factor
                    settings_list.append_val (
                        @"scroll_factor $(settings.scroll_factor)");

                    // middle_emulation
                    settings_list.append_val (
                        @"middle_emulation $(Inp_Dev_Settings.parse_bool(settings.middle_emulation))");

                    if (Input_Types.touchpad == type) {
                        // scroll_method
                        settings_list.append_val (
                            settings.scroll_method.get_line ());

                        // dwt
                        settings_list.append_val (
                            @"dwt $(Inp_Dev_Settings.parse_bool(settings.dwt))");

                        // tap
                        settings_list.append_val (
                            @"tap $(Inp_Dev_Settings.parse_bool(settings.tap))");

                        // tap_button_map
                        settings_list.append_val (
                            settings.tap_button_map.get_line ());

                        // click_method
                        settings_list.append_val (
                            settings.click_method.get_line ());
                    }
                    break;
                default:
                    break;
            }
            return settings_list;
        }
    }

    public class Inp_Dev_Settings {
        // Pointer and touchpad
        public accel_profiles accel_profile = accel_profiles.adaptive;
        public bool dwt = false;
        public Doem doem = new Doem (false);
        public bool left_handed = false;
        public bool natural_scroll = false;
        public float pointer_accel = 0;
        public float scroll_factor = 1;
        public bool middle_emulation = false;
        public bool tap = false;
        public click_methods click_method = click_methods.clickfinger;
        public scroll_methods scroll_method = scroll_methods.two_finger;
        public tap_button_maps tap_button_map = tap_button_maps.lrm;

        // Keyboard
        public ArrayList<Language> xkb_layout_names = new ArrayList<Language>();

        public static bool parse (string value) {
            return value == "enabled" ? true : false;
        }

        public static string parse_bool (bool value) {
            return value ? "enabled" : "disabled";
        }

        public enum accel_profiles {
            adaptive, flat;

            public static accel_profiles parse_string (string value) {
                if (value == "flat") return flat;
                return adaptive;
            }

            public string parse () {
                if (this == flat) return "flat";
                return "adaptive";
            }

            public string get_line () {
                string value = (this == flat) ? "flat" : "adaptive";
                return @"accel_profile $(value)";
            }
        }
        // Disable on external mouse
        public class Doem {
            public bool value = false;

            public Doem (bool value) {
                this.value = value;
            }

            public static Doem parse (string value) {
                if (value == "disabled_on_external_mouse") {
                    return new Doem (true);
                }
                return new Doem (false);
            }

            public string get_value () {
                return value ? "disabled_on_external_mouse" : "enabled";
            }

            public string get_line () {
                return @"events $(get_value())";
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

            public string get_line () {
                string value = "two_finger";
                if (this == scroll_methods.none) value = "none";
                else if (this == scroll_methods.on_button_down) value = "on_button_down";
                else if (this == scroll_methods.edge) value = "edge";
                return @"scroll_method $(value)";
            }
        }
        public enum click_methods {
            button_areas, clickfinger;

            public string parse () {
                if (this == button_areas) return "button_areas";
                return "clickfinger";
            }

            public static click_methods parse_string (string value) {
                if (value == "button_areas") return button_areas;
                return clickfinger;
            }

            public string get_line () {
                string value = "clickfinger";
                if (this == click_methods.button_areas) value = "button_areas";
                return @"click_method $(value)";
            }
        }
        public enum tap_button_maps {
            lrm, lmr;

            public static tap_button_maps parse (string value) {
                if (value == "lrm") return lrm;
                return lmr;
            }

            public string get_line () {
                string value = (this == lrm) ? "lrm" : "lmr";
                return @"tap_button_map $(value)";
            }
        }
    }
}
