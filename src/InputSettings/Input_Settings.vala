using Gee;

namespace SwaySettings {
    public enum Input_Types {
        NEITHER,
        POINTER,
        TOUCHPAD,
        KEYBOARD;

        public string parse () {
            switch (this) {
                case POINTER:
                    return "pointer";
                case TOUCHPAD:
                    return "touchpad";
                case KEYBOARD:
                    return "keyboard";
                case NEITHER:
                default:
                    return "neither";
            }
        }

        public static Input_Types parse_string (string value) {
            switch (value) {
                case "pointer":
                    return POINTER;
                case "touchpad":
                    return TOUCHPAD;
                case "keyboard":
                    return KEYBOARD;
                case "neither":
                default:
                    return NEITHER;
            }
        }
    }

    public class Language : StringType {
        public string name;
        public string shortDescription;
        public string description;

        public bool is_valid () {
            bool n_valid = name != null && name.length > 0;
            bool sd_valid = shortDescription != null && shortDescription.length > 0;
            bool d_valid = description != null && description.length > 0;
            return n_valid && sd_valid && d_valid;
        }

        public override string to_string () {
            return description;
        }
    }

    public enum BoolEnum {
        DISABLED, ENABLED;

        public string parse () {
            switch (this) {
                case ENABLED:
                    return "enabled";
                default:
                    return "disabled";
            }
        }

        public static BoolEnum parse_string (string value) {
            switch (value) {
                case "enabled":
                    return ENABLED;
                default:
                    return DISABLED;
            }
        }

        public bool to_bool () {
            switch (this) {
                case ENABLED:
                    return true;
                default:
                    return false;
            }
        }

        public static BoolEnum from_bool (bool value) {
            return value ? ENABLED : DISABLED;
        }
    }

    public enum Accel_Profiles {
        ADAPTIVE, FLAT;

        public static Accel_Profiles parse_string (string value) {
            switch (value) {
                case "flat":
                    return FLAT;
                default:
                    return ADAPTIVE;
            }
        }

        public string parse () {
            switch (this) {
                case FLAT:
                    return "flat";
                case ADAPTIVE:
                default:
                    return "adaptive";
            }
        }

        public string get_line () {
            return @"accel_profile $(parse ())";
        }
    }

    public enum Scroll_Methods {
        TWO_FINGER, NONE, EDGE, ON_BUTTON_DOWN;

        public static Scroll_Methods parse_string (string value) {
            switch (value) {
                case "edge":
                    return EDGE;
                case "on_button_down":
                    return ON_BUTTON_DOWN;
                case "none":
                    return NONE;
                case "two_finger":
                default:
                    return TWO_FINGER;
            }
        }

        public string parse () {
            switch (this) {
                case NONE:
                    return "none";
                case EDGE:
                    return "edge";
                case ON_BUTTON_DOWN:
                    return "on_button_down";
                case TWO_FINGER:
                default:
                    return "two_finger";
            }
        }

        public string get_line () {
            return @"scroll_method $(parse ())";
        }
    }

    public enum Click_Methods {
        BUTTON_AREAS, CLICKFINGER, NONE;

        public string parse () {
            switch (this) {
                case CLICKFINGER:
                    return "clickfinger";
                case NONE:
                    return "none";
                case BUTTON_AREAS:
                default:
                    return "button_areas";
            }
        }

        public static Click_Methods parse_string (string value) {
            switch (value) {
                case "clickfinger":
                    return CLICKFINGER;
                case "none":
                    return NONE;
                case "button_areas":
                default:
                    return BUTTON_AREAS;
            }
        }

        public string get_line () {
            return @"click_method $(parse ())";
        }
    }

    public enum Tap_Button_Maps {
        LRM, LMR;

        public static Tap_Button_Maps parse_string (string value) {
            switch (value) {
                case "lmr":
                    return LMR;
                case "lrm":
                default:
                    return LRM;
            }
        }

        public string parse () {
            switch (this) {
                case LMR:
                    return "lmr";
                case LRM:
                default:
                    return "lrm";
            }
        }

        public string get_line () {
            return @"tap_button_map $(parse ())";
        }
    }

    public enum Events {
        ENABLED, DISABLED, DISABLED_ON_EXTERNAL_MOUSE;

        public static Events parse_string (string value) {
            switch (value.down ()) {
                case "disabled_on_external_mouse":
                    return DISABLED_ON_EXTERNAL_MOUSE;
                case "disabled":
                    return DISABLED;
                case "enabled":
                default:
                    return ENABLED;
            }
        }

        public string parse () {
            switch (this) {
                case DISABLED_ON_EXTERNAL_MOUSE:
                    return "disabled_on_external_mouse";
                case DISABLED:
                    return "disabled";
                case ENABLED:
                default:
                    return "enabled";
            }
        }

        public string get_line () {
            return @"events $(parse())";
        }
    }

    public class Input_Device : Object {
        public Input_Types input_type {
            get; private set; default = Input_Types.NEITHER;
        }
        public Input_Data data;
        public string identifier { get; private set; }
        public float scroll_factor { get; set; default = 1.0f; }

        public Input_Device (string identifier,
                             Input_Types type) {
            this.identifier = identifier;
            this.input_type = type;
            this.data = new Input_Data ();
        }

        public string[] get_settings () {
            string[] lines = { @"input type:$(input_type.parse()) {\n" };
            foreach (string line in get_type_settings ()) {
                lines += get_string_line (line);
            }
            lines += "}\n";
            return lines;
        }

        private string get_string_line (string line) {
            return @"\t$(line)\n";
        }

        private string[] get_type_settings () {
            string[] settings_list = {};

            switch (input_type) {
                case Input_Types.KEYBOARD:
                    // xkb_layout_names
                    string[] array = {};
                    foreach (var lang in data.xkb_layout_names) {
                        array += lang.name;
                    }
                    string languages = string.joinv (", ", array);
                    settings_list += (@"xkb_layout \"$(languages)\"");
                    break;
                case Input_Types.POINTER:
                case Input_Types.TOUCHPAD:
                    // events
                    settings_list += data.send_events.get_line ();
                    // pointer_accel
                    settings_list += @"pointer_accel $(data.accel_speed)";
                    // accel_profile
                    settings_list += data.accel_profile.get_line ();
                    // natural_scroll
                    settings_list +=
                        @"natural_scroll $(data.natural_scroll.parse ())";
                    // left_handed
                    settings_list +=
                        @"left_handed $(data.left_handed.parse ())";
                    // scroll_factor
                    settings_list += @"scroll_factor $(scroll_factor)";
                    // middle_emulation
                    settings_list +=
                        @"middle_emulation $(data.middle_emulation.parse ())";

                    if (Input_Types.TOUCHPAD == input_type) {
                        // scroll_method
                        settings_list += data.scroll_method.get_line ();
                        // dwt
                        settings_list += @"dwt $(data.dwt.parse ())";
                        // tap
                        settings_list += @"tap $(data.tap.parse ())";
                        // tap_button_map
                        settings_list += data.tap_button_map.get_line ();
                        // click_method
                        settings_list += data.click_method.get_line ();
                    }
                    break;
                default:
                    break;
            }
            return settings_list;
        }
    }

    public class Input_Data : Object, Json.Serializable {
        // Pointer and touchpad
        public Accel_Profiles accel_profile {
            get; set; default = Accel_Profiles.ADAPTIVE;
        }
        public Events send_events {
            get; set; default = Events.ENABLED;
        }
        public BoolEnum dwt {
            get; set; default = BoolEnum.DISABLED;
        }
        public BoolEnum left_handed {
            get; set; default = BoolEnum.DISABLED;
        }
        public BoolEnum natural_scroll {
            get; set; default = BoolEnum.DISABLED;
        }
        public BoolEnum middle_emulation {
            get; set; default = BoolEnum.DISABLED;
        }
        public BoolEnum tap {
            get; set; default = BoolEnum.DISABLED;
        }
        public float accel_speed {
            get; set; default = 0;
        }
        public Click_Methods click_method {
            get; set; default = Click_Methods.CLICKFINGER;
        }
        public Scroll_Methods scroll_method {
            get; set; default = Scroll_Methods.TWO_FINGER;
        }
        public Tap_Button_Maps tap_button_map {
            get; set; default = Tap_Button_Maps.LRM;
        }

        // Keyboard
        public ArrayList<Language> xkb_layout_names = new ArrayList<Language>();

        public override bool deserialize_property (string property_name,
                                                   out Value value,
                                                   ParamSpec pspec,
                                                   Json.Node node) {
            switch (node.get_value_type ()) {
                case Type.BOOLEAN:
                    value = node.get_boolean ();
                    return true;
                case Type.INT64:
                    value = node.get_int ();
                    return true;
                case Type.DOUBLE:
                    value = node.get_double ();
                    return true;
            }
            return default_deserialize_property (property_name,
                                                 out value,
                                                 pspec,
                                                 node);
        }

        public override Json.Node serialize_property (string property_name,
                                                      Value value,
                                                      ParamSpec pspec) {
            var node = new Json.Node (Json.NodeType.VALUE);
            switch (value.type_name ()) {
                case "SwaySettingsBoolEnum":
                    BoolEnum casted = (BoolEnum) value.get_enum ();
                    node.set_string (casted.parse ());
                    break;
                case "SwaySettingsClick_Methods":
                    Click_Methods casted = (Click_Methods) value.get_enum ();
                    node.set_string (casted.parse ());
                    break;
                case "SwaySettingsScroll_Methods":
                    Scroll_Methods casted = (Scroll_Methods) value.get_enum ();
                    node.set_string (casted.parse ());
                    break;
                case "SwaySettingsTap_Button_Maps":
                    Tap_Button_Maps casted = (Tap_Button_Maps) value.get_enum ();
                    node.set_string (casted.parse ());
                    break;
                case "SwaySettingsAccel_Profiles":
                    Accel_Profiles casted = (Accel_Profiles) value.get_enum ();
                    node.set_string (casted.parse ());
                    break;
                case "gchararray":
                    string ? casted = value.get_string ();
                    if (casted != null) {
                        node.set_string (casted);
                    }
                    break;
                case "gboolean" :
                    bool ? casted = value.get_boolean ();
                    if (casted != null) {
                        node.set_boolean (casted);
                    }
                    break;
                case "gint64" :
                    int64 ? casted = (int64 ? ) value.get_int64 ();
                    if (casted != null) {
                        node.set_int (casted);
                    }
                    break;
                case "gfloat":
                    float ? casted = (float ? ) value.get_float ();
                    if (casted != null) {
                        node.set_double (casted);
                    }
                    break;
                case "gdouble":
                    double ? casted = (double ? ) value.get_double ();
                    if (casted != null) {
                        node.set_double (casted);
                    }
                    break;
                default:
                    return default_serialize_property (property_name,
                                                       value,
                                                       pspec);
            }
            return node;
        }
    }
}
