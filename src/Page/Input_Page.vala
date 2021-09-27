using Gee;

namespace SwaySettings {

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

    public class Input_Page_Section {
        public string ? title;
        public Gtk.Widget widget;

        public Input_Page_Section (Gtk.Widget widget, string ? title = null) {
            this.widget = widget;
            this.title = title;
        }
    }

    public class Input_Page_Option {
        public string ? title;
        public ArrayList<Gtk.Widget> widgets;

        public Input_Page_Option (ArrayList<Gtk.Widget> widgets,
                                  string ? title = null) {
            this.widgets = widgets;
            this.title = title;
        }
    }

    public abstract class Input_Page : Page_Scroll {
        Input_Device device;
        HashMap<string, Language> languages;

        public abstract Input_Types input_type { get; }

        protected Input_Page (string label, Hdy.Deck deck, IPC ipc) {
            base (label, deck, ipc);
        }

        public virtual ArrayList<Input_Page_Section> get_top_sections () {
            return new ArrayList<Input_Page_Section> ();
        }

        public virtual Input_Page_Option get_options () {
            return new Input_Page_Option (new ArrayList<Gtk.Widget> ());
        }

        public override Gtk.Widget set_child () {
            if (input_type == Input_Types.keyboard) {
                languages = get_languages ();
            } else {
                languages = new HashMap<string, Language>();
            }

            bool has_type = init_input_devices ();

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 32);
            // Disables all controls when there's no device detected
            // or when no languages could be found for the keyboard page
            if (!has_type) {
                box.set_sensitive (false);
            }

            var top_sections = get_top_sections ();
            for (int i = 0; i < top_sections.size; i++) {
                var section = top_sections[i];
                if (section != null) {
                    var pref_group = new Hdy.PreferencesGroup ();
                    pref_group.set_title (section.title ?? "");
                    pref_group.add (section.widget);
                    box.add (pref_group);
                }
            }

            var options = get_options ();
            if (options.widgets.size > 0) {
                var pref_group = new Hdy.PreferencesGroup ();
                pref_group.set_title (options.title ?? "");
                foreach (var option in options.widgets) {
                    if (option != null) pref_group.add (option);
                }
                box.add (pref_group);
            }

            return box;
        }

        HashMap<string, Language> get_languages () {
            string path = "/usr/share/X11/xkb/rules/evdev.xml";
            string xpath_q = "/xkbConfigRegistry/layoutList/layout/configItem";

            var languages = new HashMap<string, Language> ();
            unowned Xml.Doc doc = Xml.Parser.parse_file (path);
            if (doc == null) {
                stderr.printf ("File %s not found or permissions missing", path);
                return languages;
            }

            Xml.XPath.Context context = new Xml.XPath.Context (doc);
            unowned Xml.XPath.Object object = context.eval (xpath_q);

            if (object.type != Xml.XPath.ObjectType.NODESET) {
                stderr.printf ("Object is not of type Node Set");
                return languages;
            }

            for (var i = 0; i < object.nodesetval->length (); i++) {
                unowned Xml.Node node = object.nodesetval->item (i);
                var lang = new Language ();
                unowned Xml.Node child = node.children;
                while ((child = child.next) != null) {
                    switch (child.name) {
                        case "name":
                            lang.name = child.get_content ();
                            break;
                        case "shortDescription":
                            lang.shortDescription = child.get_content ();
                            break;
                        case "description":
                            lang.description = child.get_content ();
                            break;
                        default:
                            break;
                    }
                }
                if (lang.is_valid ()) languages[lang.description] = lang;
            }
            return languages;
        }

        bool init_input_devices () {
            Json.Node ipc_output = ipc.get_reply (Sway_commands.GET_IMPUTS);
            if (ipc_output.get_node_type () == Json.NodeType.ARRAY) {
                foreach (var elem in ipc_output.get_array ().get_elements ()) {
                    var obj = elem.get_object ();
                    Input_Types type = Input_Types.parse_string (obj.get_string_member ("type") ?? "");
                    if (input_type != type) continue;
                    get_device_settings (obj, type);
                    return true;
                }
            }
            device = new Input_Device ("", input_type);
            return false;
        }

        void get_device_settings (Json.Object ? obj, Input_Types type) {
            var device = new Input_Device (obj.get_string_member ("identifier"), type);
            switch (type) {
                case Input_Types.keyboard:
                    // xkb_layout_names
                    device.settings.xkb_layout_names.clear ();
                    if (obj.has_member ("xkb_layout_names")) {
                        var layouts = obj.get_array_member ("xkb_layout_names");
                        if (layouts != null) {
                            for (uint i = 0; i < layouts.get_length (); i++) {
                                string lang = layouts.get_string_element (i);
                                if (languages.has_key (lang)) {
                                    Language language = languages.get (lang);
                                    if (language == null) continue;
                                    device.settings.xkb_layout_names.add (language);
                                }
                            }
                        }
                    }
                    break;
                case Input_Types.pointer:
                case Input_Types.touchpad:
                    var lib = obj.get_object_member ("libinput");
                    // Used to get the default values
                    var defs = new Inp_Dev_Settings ();

                    // send_events
                    var send_events_string = lib.get_string_member_with_default ("send_events", "enabled");
                    device.settings.doem = Inp_Dev_Settings.Doem.parse (send_events_string);
                    // pointer_accel
                    device.settings.pointer_accel = (float) lib.get_double_member_with_default ("accel_speed", 0);
                    // accel_profile
                    var accel_profile_string = lib.get_string_member_with_default ("accel_profile", "adaptive");
                    device.settings.accel_profile = Inp_Dev_Settings.accel_profiles.parse_string (accel_profile_string);
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
                    // scroll_method
                    var scroll_method_string = lib.get_string_member_with_default ("scroll_method", "two_finger");
                    device.settings.scroll_method = Inp_Dev_Settings.scroll_methods.parse (scroll_method_string);
                    break;
                default:
                    break;
            }

            this.device = device;
        }

        void write_new_settings (string str) {
            ipc.run_command (str);
            string file_name;
            switch (device.type) {
                case Input_Types.pointer:
                    file_name = Strings.settings_folder_input_pointer;
                    break;
                case Input_Types.touchpad:
                    file_name = Strings.settings_folder_input_touchpad;
                    break;
                case Input_Types.keyboard:
                    file_name = Strings.settings_folder_input_keyboard;
                    break;
                default:
                    return;
            }
            Functions.write_settings (file_name, device.get_settings ());
        }

        // Keyboard input language
        public Gtk.Widget get_keyboard_language () {
            var osl = new OrderListSelector (device.settings.xkb_layout_names,
                                             (list) => {
                device.settings.xkb_layout_names = (ArrayList<Language>) list;
                string[] array = {};
                foreach (var item in list) {
                    Language lang = (Language) item;
                    if (lang != null) array += lang.name;
                }
                var cmd = @"input type:$(device.type.parse ()) xkb_layout \"$(string.joinv (", ", array))\"";
                write_new_settings (cmd);
            }, (order_list_selector) => {
                var window = (SwaySettings.Window)get_toplevel ();
                new KeyboardInputSelector (
                    window,
                    languages,
                    device.settings.xkb_layout_names,
                    order_list_selector);
            });
            osl.sensitive = languages.size > 0;
            return osl;
        }

        // scroll_factor
        public Gtk.Widget get_scroll_factor () {
            var row = new List_Slider ("Scroll Factor",
                                       device.settings.scroll_factor,
                                       0.0, 10, 1,
                                       (slider) => {
                var value = (float) slider.get_value ();
                device.settings.scroll_factor = value;
                var str_value = value.to_string ().replace (",", ".");
                write_new_settings (@"input type:$(device.type.parse ()) scroll_factor $(str_value)");
                return false;
            });
            row.add_mark (1.0, Gtk.PositionType.TOP);
            return row;
        }

        // natural_scroll
        public Gtk.Widget get_natural_scroll () {
            return new List_Switch ("Natural Scrolling",
                                    device.settings.natural_scroll,
                                    (value) => {
                device.settings.natural_scroll = value;
                write_new_settings (@"input type:$(device.type.parse ()) natural_scroll $(value)");
                return false;
            });
        }

        // accel_profile
        public Gtk.Widget get_accel_profile () {
            return new List_Combo_Enum ("Acceleration Profile",
                                        device.settings.accel_profile,
                                        typeof (Inp_Dev_Settings.accel_profiles),
                                        (index) => {
                var profile = (Inp_Dev_Settings.accel_profiles) index;
                device.settings.accel_profile = profile;
                write_new_settings (@"input type:$(device.type.parse ()) accel_profile $(profile.parse())");
            });
        }

        // pointer_accel
        public Gtk.Widget get_pointer_accel () {
            var row = new List_Slider ("Pointer Acceleration",
                                       device.settings.pointer_accel,
                                       -1.0, 1.0, 0.1,
                                       (slider) => {
                var value = (float) slider.get_value ();
                device.settings.pointer_accel = value;
                var str_value = value.to_string ().replace (",", ".");
                write_new_settings (@"input type:$(device.type.parse ()) pointer_accel $(str_value)");
                return false;
            });
            row.add_mark (0.0, Gtk.PositionType.TOP);
            return row;
        }

        // Disable while typing
        public Gtk.Widget get_dwt () {
            return new List_Switch ("Disable While Typing",
                                    device.settings.dwt,
                                    (value) => {
                device.settings.dwt = value;
                write_new_settings (@"input type:$(device.type.parse ()) dwt $(value)");
                return false;
            });
        }

        // Disable on external mouse
        public Gtk.Widget get_doem () {
            return new List_Switch ("Disable On External Mouse",
                                    device.settings.doem.value,
                                    (value) => {
                var val = new Inp_Dev_Settings.Doem (value);
                device.settings.doem = val;
                write_new_settings (@"input type:$(device.type.parse ()) events $(val.get_value())");
                return false;
            });
        }

        // Tap to click
        public Gtk.Widget get_tap () {
            return new List_Switch ("Tap to Click",
                                    device.settings.tap,
                                    (value) => {
                device.settings.tap = value;
                write_new_settings (@"input type:$(device.type.parse ()) tap $(value)");
                return false;
            });
        }

        // Click method
        public Gtk.Widget get_click_method () {
            return new List_Combo_Enum ("Click Method",
                                        device.settings.click_method,
                                        typeof (Inp_Dev_Settings.click_methods),
                                        (index) => {
                var profile = (Inp_Dev_Settings.click_methods) index;
                device.settings.click_method = profile;
                write_new_settings (@"input type:$(device.type.parse ()) click_method $(profile.parse())");
            });
        }
    }
}
