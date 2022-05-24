using Gee;

namespace SwaySettings {
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

        IPC ipc;

        protected Input_Page (string label, Hdy.Deck deck, IPC ipc) {
            base (label, deck);
            this.ipc = ipc;
        }

        public virtual ArrayList<Input_Page_Section> get_top_sections () {
            return new ArrayList<Input_Page_Section> ();
        }

        public virtual Input_Page_Option get_options () {
            return new Input_Page_Option (new ArrayList<Gtk.Widget> ());
        }

        public override Gtk.Widget set_child () {
            if (input_type == Input_Types.KEYBOARD) {
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
                foreach (var node in ipc_output.get_array ().get_elements ()) {
                    if (node.get_node_type () != Json.NodeType.OBJECT) continue;
                    unowned Json.Object ? obj = node.get_object ();
                    if (obj == null) continue;

                    Input_Types type = Input_Types.parse_string (
                        obj.get_string_member ("type") ?? "");
                    if (input_type != type || type == Input_Types.NEITHER) continue;
                    // Skip if the Mouse / Touchpad doesn't have "accel_speed"
                    // Example would be a keyboard that reports as a mouse
                    if ((type == Input_Types.POINTER || type == Input_Types.TOUCHPAD) &&
                        obj.get_member ("libinput") ? .get_object ()
                        ? .has_member ("accel_speed") == false) {
                        continue;
                    }

                    this.device = get_device_settings (obj, type);
                    return true;
                }
            }
            device = new Input_Device ("", input_type);
            return false;
        }

        Input_Device get_device_settings (Json.Object ? obj, Input_Types type) {
            Input_Device device = new Input_Device (
                obj.get_string_member ("identifier"), type);
            switch (type) {
                case Input_Types.KEYBOARD:
                    // xkb_layout_names
                    device.data.xkb_layout_names.clear ();
                    if (obj.has_member ("xkb_layout_names")) {
                        var layouts = obj.get_array_member ("xkb_layout_names");
                        if (layouts != null) {
                            for (uint i = 0; i < layouts.get_length (); i++) {
                                string lang = layouts.get_string_element (i);
                                if (languages.has_key (lang)) {
                                    Language language = languages.get (lang);
                                    if (language == null) continue;
                                    device.data.xkb_layout_names.add (language);
                                }
                            }
                        }
                    }
                    break;
                case Input_Types.POINTER:
                case Input_Types.TOUCHPAD:
                    unowned Json.Node ? lib = obj.get_member ("libinput");
                    if (lib == null
                        || lib.get_node_type () != Json.NodeType.OBJECT) {
                        break;
                    }
                    device.data = (Input_Data) Json.gobject_deserialize (
                        typeof (Input_Data), lib);

                    // Get scroll factor
                    unowned Json.Node ? node = obj.get_member ("scroll_factor");
                    if (node != null && node.get_value_type () == Type.DOUBLE) {
                        double scroll_factor = node.get_double ();
                        device.scroll_factor = (float) scroll_factor;
                    }
                    print ("DATA: %s\n", device.identifier);
                    break;
                default : break;
            }

            return device;
        }

        void write_new_settings (string str) {
            ipc.run_command (str);
            string file_name;
            switch (device.input_type) {
                case Input_Types.POINTER :
                    file_name = Strings.settings_folder_input_pointer;
                    break;
                case Input_Types.TOUCHPAD:
                    file_name = Strings.settings_folder_input_touchpad;
                    break;
                case Input_Types.KEYBOARD:
                    file_name = Strings.settings_folder_input_keyboard;
                    break;
                default:
                    return;
            }
            Functions.write_settings (file_name, device.get_settings ());
        }

        // Keyboard input language
        public Gtk.Widget get_keyboard_language () {
            var ols = new OrderListSelector (device.data.xkb_layout_names,
                                             (list) => {
                device.data.xkb_layout_names = (ArrayList<Language>) list;
                string[] array = {};
                foreach (var item in list) {
                    Language lang = (Language) item;
                    if (lang != null) array += lang.name;
                }

                string type = device.input_type.parse ();
                string langs = string.joinv (", ", array);
                var cmd = @"input type:$(type) xkb_layout \"$(langs)\"";
                write_new_settings (cmd);
            },
                                             (order_list_selector) => {
                new KeyboardInputSelector (
                    (SwaySettings.Window)get_toplevel (),
                    languages,
                    device.data.xkb_layout_names,
                    order_list_selector);
            });
            ols.sensitive = languages.size > 0;
            return ols;
        }

        // scroll_factor
        public Gtk.Widget get_scroll_factor () {
            var row = new List_Slider ("Scroll Factor",
                                       device.scroll_factor,
                                       0.0, 10, 1,
                                       (slider) => {
                var value = (float) slider.get_value ();
                device.scroll_factor = value;
                var str_value = value.to_string ().replace (",", ".");
                write_new_settings (
                    @"input type:$(device.input_type.parse ()) scroll_factor $(str_value)");
                return false;
            });
            row.add_mark (1.0, Gtk.PositionType.TOP);
            return row;
        }

        // natural_scroll
        public Gtk.Widget get_natural_scroll () {
            return new List_Switch ("Natural Scrolling",
                                    device.data.natural_scroll.to_bool (),
                                    (value) => {
                device.data.natural_scroll = BoolEnum.from_bool (value);
                write_new_settings (@"input type:$(device.input_type.parse ()) natural_scroll $(value)");
                return false;
            });
        }

        // accel_profile
        public Gtk.Widget get_accel_profile () {
            return new List_Combo_Enum ("Acceleration Profile",
                                        device.data.accel_profile,
                                        typeof (Accel_Profiles),
                                        (index) => {
                var profile = (Accel_Profiles) index;
                device.data.accel_profile = profile;
                write_new_settings (@"input type:$(device.input_type.parse ()) accel_profile $(profile.parse())");
            });
        }

        // pointer_accel
        public Gtk.Widget get_pointer_accel () {
            var row = new List_Slider ("Pointer Acceleration",
                                       device.data.accel_speed,
                                       -1.0, 1.0, 0.1,
                                       (slider) => {
                var value = (float) slider.get_value ();
                device.data.accel_speed = value;
                var str_value = value.to_string ().replace (",", ".");
                write_new_settings (@"input type:$(device.input_type.parse ()) pointer_accel $(str_value)");
                return false;
            });
            row.add_mark (0.0, Gtk.PositionType.TOP);
            return row;
        }

        // Disable while typing
        public Gtk.Widget get_dwt () {
            return new List_Switch ("Disable While Typing",
                                    device.data.dwt.to_bool (),
                                    (value) => {
                device.data.dwt = BoolEnum.from_bool (value);
                write_new_settings (@"input type:$(device.input_type.parse ()) dwt $(value)");
                return false;
            });
        }

        // Disable on external mouse
        public Gtk.Widget get_state_widget () {
            return new List_Combo_Enum ("State",
                                        device.data.send_events,
                                        typeof (Events),
                                        (index) => {
                var event = (Events) index;
                device.data.send_events = event;
                write_new_settings (@"input type:$(device.input_type.parse ()) events $(event.parse ())");
            });
        }

        // Tap to click
        public Gtk.Widget get_tap () {
            return new List_Switch ("Tap to Click",
                                    device.data.tap.to_bool (),
                                    (value) => {
                device.data.tap = BoolEnum.from_bool (value);
                write_new_settings (@"input type:$(device.input_type.parse ()) tap $(value)");
                return false;
            });
        }

        // Click method
        public Gtk.Widget get_click_method () {
            return new List_Combo_Enum ("Click Method",
                                        device.data.click_method,
                                        typeof (Click_Methods),
                                        (index) => {
                var profile = (Click_Methods) index;
                device.data.click_method = profile;
                write_new_settings (@"input type:$(device.input_type.parse ()) click_method $(profile.parse())");
            });
        }
    }
}
