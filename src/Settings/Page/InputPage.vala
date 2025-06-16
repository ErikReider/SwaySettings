using Gee;

namespace SwaySettings {
    public class InputPageSection {
        public string ?title;
        public Gtk.Widget widget;

        public InputPageSection (Gtk.Widget widget,
                                 string ?title = null) {
            this.widget = widget;
            this.title = title;
        }
    }

    public class InputPageOption {
        public string ?title;
        public ArrayList<Gtk.Widget> widgets;

        public InputPageOption (ArrayList<Gtk.Widget> widgets,
                                string ?title = null) {
            this.widgets = widgets;
            this.title = title;
        }
    }

    public abstract class InputPage : PageScroll, IIpcPage {
        public IPC ipc { get; set; }

        InputDevice device;
        HashMap<string, Language> languages;

        public abstract InputTypes input_type { get; }

        protected InputPage (SettingsItem item,
                             Adw.NavigationPage page,
                             IPC ipc) {
            base (item, page);
            this.ipc = ipc;
        }

        public virtual ArrayList<InputPageSection> get_top_sections () {
            return new ArrayList<InputPageSection> ();
        }

        public virtual InputPageOption get_options () {
            return new InputPageOption (new ArrayList<Gtk.Widget> ());
        }

        public override Gtk.Widget set_child () {
            if (input_type == InputTypes.KEYBOARD) {
                languages = get_languages ();
            } else {
                languages = new HashMap<string, Language> ();
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
                    var pref_group = new Adw.PreferencesGroup ();
                    pref_group.set_title (section.title ?? "");
                    pref_group.add (section.widget);
                    box.append (pref_group);
                }
            }

            var options = get_options ();
            if (options.widgets.size > 0) {
                var pref_group = new Adw.PreferencesGroup ();
                pref_group.set_title (options.title ?? "");
                foreach (var option in options.widgets) {
                    if (option != null) pref_group.add (option);
                }
                box.append (pref_group);
            }

            return box;
        }

        HashMap<string, Language> get_languages () {
            string path = "/usr/share/X11/xkb/rules/evdev.xml";
            string xpath_q = "/xkbConfigRegistry/layoutList/layout/configItem";

            var languages = new HashMap<string, Language> ();
            unowned Xml.Doc doc = Xml.Parser.parse_file (path);
            if (doc == null) {
                stderr.printf ("File %s not found or permissions missing",
                               path);
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
                            lang.short_description = child.get_content ();
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
            Json.Node ipc_output = ipc.get_reply (SwayCommands.GET_INPUTS);
            if (ipc_output.get_node_type () == Json.NodeType.ARRAY) {
                foreach (var node in ipc_output.get_array ().get_elements ()) {
                    if (node.get_node_type () != Json.NodeType.OBJECT) continue;
                    unowned Json.Object ?obj = node.get_object ();
                    if (obj == null) continue;

                    InputTypes type = InputTypes.parse_string (
                        obj.get_string_member ("type") ?? "");
                    if (input_type != type || type == InputTypes.NEITHER) {
                        continue;
                    }
                    // Skip if the Mouse / Touchpad doesn't have "accel_speed"
                    // Example would be a keyboard that reports as a mouse
                    if ((type == InputTypes.POINTER ||
                         type == InputTypes.TOUCHPAD)) {
                        if (obj.get_member ("libinput")
                            ?.get_object ()
                            ?.has_member ("accel_speed") == false) {
                            continue;
                        }
                    }

                    this.device = get_device_settings (obj, type);
                    return true;
                }
            }
            device = new InputDevice ("", input_type);
            return false;
        }

        InputDevice get_device_settings (Json.Object ?obj,
                                         InputTypes type) {
            InputDevice device = new InputDevice (
                obj.get_string_member ("identifier"), type);
            switch (type) {
                case InputTypes.KEYBOARD:
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
                case InputTypes.POINTER:
                case InputTypes.TOUCHPAD:
                    unowned Json.Node ?lib = obj.get_member ("libinput");
                    if (lib == null
                        || lib.get_node_type () != Json.NodeType.OBJECT) {
                        break;
                    }
                    device.data = (InputData) Json.gobject_deserialize (
                        typeof (InputData), lib);

                    // Get scroll factor
                    unowned Json.Node ?node = obj.get_member ("scroll_factor");
                    if (node != null && node.get_value_type () == Type.DOUBLE) {
                        double scroll_factor = node.get_double ();
                        device.scroll_factor = (float) scroll_factor;
                    }
                    break;
                default:
                    break;
            }

            return device;
        }

        void write_new_settings (string str) {
            ipc.run_command (str);
            string file_name;
            switch (device.input_type) {
                case InputTypes.POINTER :
                    file_name = Strings.SETTINGS_FOLDER_INPUT_POINTER;
                    break;
                case InputTypes.TOUCHPAD:
                    file_name = Strings.SETTINGS_FOLDER_INPUT_TOUCHPAD;
                    break;
                case InputTypes.KEYBOARD:
                    file_name = Strings.SETTINGS_FOLDER_INPUT_KEYBOARD;
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
                var cmd = "input type:%s xkb_layout \"%s\"".printf (type,
                                                                    langs);
                write_new_settings (cmd);
            },
                                             (order_list_selector) => {
                var dialog = new KeyboardInputSelector (
                    languages,
                    device.data.xkb_layout_names,
                    order_list_selector);
                dialog.present (get_root ());
            });
            ols.sensitive = languages.size > 0;
            return ols;
        }

        // scroll_factor
        public Gtk.Widget get_scroll_factor () {
            var row = new ListSlider ("Scroll Factor",
                                      device.scroll_factor,
                                      0.0, 10, 1,
                                      (slider) => {
                var value = (float) slider.get_value ();
                device.scroll_factor = value;
                var str_value = value.to_string ().replace (",", ".");
                write_new_settings (
                    "input type:%s scroll_factor %s".printf (
                        device.input_type.parse (), str_value));
                return false;
            });
            row.add_mark (1.0, Gtk.PositionType.TOP);
            return row;
        }

        // natural_scroll
        public Gtk.Widget get_natural_scroll () {
            return new ListSwitch ("Natural Scrolling",
                                   device.data.natural_scroll.to_bool (),
                                   (value) => {
                device.data.natural_scroll = BoolEnum.from_bool (value);
                write_new_settings (
                    "input type:%s natural_scroll %s".printf (
                        device.input_type.parse (), value.to_string ()));
                return false;
            });
        }

        // accel_profile
        public Gtk.Widget get_accel_profile () {
            return new ListComboEnum ("Acceleration Profile",
                                      device.data.accel_profile,
                                      typeof (AccelProfiles),
                                      (index) => {
                var profile = (AccelProfiles) index;
                device.data.accel_profile = profile;
                write_new_settings (
                    "input type:%s accel_profile %s".printf (
                        device.input_type.parse (), profile.parse ()));
            });
        }

        // pointer_accel
        public Gtk.Widget get_pointer_accel () {
            const double min = -1.0;
            const double max = 1.0;
            const double step = 0.1;
            var row = new ListSlider ("Pointer Acceleration",
                                      device.data.accel_speed,
                                      min, max, step,
                                      (slider) => {
                var value = (float) slider.get_value ();
                device.data.accel_speed = value;
                var str_value = value.to_string ().replace (",", ".");
                write_new_settings (
                    "input type:%s pointer_accel %s".printf (
                        device.input_type.parse (), str_value));
                return false;
            });
            row.add_mark (0.0, Gtk.PositionType.TOP);
            return row;
        }

        // Disable while typing
        public Gtk.Widget get_dwt () {
            return new ListSwitch ("Disable While Typing",
                                   device.data.dwt.to_bool (),
                                   (value) => {
                device.data.dwt = BoolEnum.from_bool (value);
                write_new_settings (
                    "input type:%s dwt %s".printf (device.input_type.parse (),
                                                   value.to_string ()));
                return false;
            });
        }

        // Disable on external mouse
        public Gtk.Widget get_state_widget () {
            return new ListComboEnum ("State",
                                      device.data.send_events,
                                      typeof (Events),
                                      (index) => {
                var event = (Events) index;
                device.data.send_events = event;
                write_new_settings (
                    "input type:%s events %s".printf (
                        device.input_type.parse (), event.parse ()));
            });
        }

        // Tap to click
        public Gtk.Widget get_tap () {
            return new ListSwitch ("Tap to Click",
                                   device.data.tap.to_bool (),
                                   (value) => {
                device.data.tap = BoolEnum.from_bool (value);
                write_new_settings (
                    "input type:%s tap %s".printf (device.input_type.parse (),
                                                   value.to_string ()));
                return false;
            });
        }

        // Click method
        public Gtk.Widget get_click_method () {
            return new ListComboEnum ("Click Method",
                                      device.data.click_method,
                                      typeof (ClickMethods),
                                      (index) => {
                var profile = (ClickMethods) index;
                device.data.click_method = profile;
                write_new_settings (
                    "input type:%s click_method %s".printf (
                        device.input_type.parse (), profile.parse ()));
            });
        }

        // Scroll method
        public Gtk.Widget get_scroll_method () {
            return new ListComboEnum ("Scroll Method",
                                      device.data.scroll_method,
                                      typeof (ScrollMethods),
                                      (index) => {
                var profile = (ScrollMethods) index;
                device.data.scroll_method = profile;
                write_new_settings (
                    "input type:%s scroll_method %s".printf (
                        device.input_type.parse (), profile.parse ()));
            });
        }
    }
}
