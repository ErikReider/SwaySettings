using Gee;

namespace SwaySettings {
    public class Mouse_Page : Page_Tabbed {
        Input_Device mouse = Input_Device ();
        Input_Device touchpad = Input_Device ();
        bool has_pointer = false;
        bool has_touchpad = false;

        public Mouse_Page (string label, Hdy.Deck deck, IPC ipc) {
            base (label, deck, ipc, "No input devices detected...");
        }

        public override Page_Tab[] tabs () {
            init_input_devices ();
            Page_Tab[] tabs = {};
            if (has_pointer) tabs += new Mouse_Widget ("Mouse", mouse, ipc);
            if (has_touchpad) tabs += new Trackpad_Widget ("Touchpad", touchpad, ipc);
            return tabs;
        }

        void init_input_devices () {
            var ipc_output = ipc.get_reply (Sway_commands.GET_IMPUTS).get_array ();
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

        protected Input_Tab (string tab_name,
                             Input_Types input_type,
                             Input_Device input_dev, IPC ipc) {
            base (tab_name, ipc);

            this.input_type = input_type.parse ();
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
            ipc.run_command (str);
            string file_name = Strings.settings_folder_input_pointer;
            if (input_dev.type == Input_Types.touchpad) {
                file_name = Strings.settings_folder_input_touchpad;
            }
            Functions.write_settings (file_name, input_dev.get_settings ());
        }

        // scroll_factor
        public Gtk.Widget get_scroll_factor () {
            var row = new List_Slider ("Scroll Factor",
                                       input_dev.settings.scroll_factor,
                                       0.0, 10, 1,
                                       (slider) => {
                var value = (float) slider.get_value ();
                input_dev.settings.scroll_factor = value;
                var str_value = value.to_string ().replace (",", ".");
                write_new_settings (@"input type:$(input_type) scroll_factor $(str_value)");
                return false;
            });
            row.add_mark (1.0, Gtk.PositionType.TOP);
            return row;
        }

        // natural_scroll
        public Gtk.Widget get_natural_scroll () {
            return new List_Switch ("Natural Scrolling",
                                    input_dev.settings.natural_scroll,
                                    (value) => {
                input_dev.settings.natural_scroll = value;
                write_new_settings (@"input type:$(input_type) natural_scroll $(value)");
                return false;
            });
        }

        // accel_profile
        public Gtk.Widget get_accel_profile () {
            return new List_Combo_Enum ("Acceleration Profile",
                                        input_dev.settings.accel_profile,
                                        typeof (Inp_Dev_Settings.accel_profiles),
                                        (index) => {
                var profile = (Inp_Dev_Settings.accel_profiles) index;
                input_dev.settings.accel_profile = profile;
                write_new_settings (@"input type:$(input_type) accel_profile $(profile.parse())");
            });
        }

        // pointer_accel
        public Gtk.Widget get_pointer_accel () {
            var row = new List_Slider ("Pointer Acceleration",
                                       input_dev.settings.pointer_accel,
                                       -1.0, 1.0, 0.1,
                                       (slider) => {
                var value = (float) slider.get_value ();
                input_dev.settings.pointer_accel = value;
                var str_value = value.to_string ().replace (",", ".");
                write_new_settings (@"input type:$(input_type) pointer_accel $(str_value)");
                return false;
            });
            row.add_mark (0.0, Gtk.PositionType.TOP);
            return row;
        }

        // Disable while typing
        public Gtk.Widget get_dwt () {
            return new List_Switch ("Disable While Typing",
                                    input_dev.settings.dwt,
                                    (value) => {
                input_dev.settings.dwt = value;
                write_new_settings (@"input type:$(input_type) dwt $(value)");
                return false;
            });
        }

        // Disable on external mouse
        public Gtk.Widget get_doem () {
            return new List_Switch ("Disable On External Mouse",
                                    input_dev.settings.doem.value,
                                    (value) => {
                var val = new Inp_Dev_Settings.Doem (value);
                input_dev.settings.doem = val;
                write_new_settings (@"input type:$(input_type) events $(val.get_value())");
                return false;
            });
        }

        // Tap to click
        public Gtk.Widget get_tap () {
            return new List_Switch ("Tap to Click",
                                    input_dev.settings.tap,
                                    (value) => {
                input_dev.settings.tap = value;
                write_new_settings (@"input type:$(input_type) tap $(value)");
                return false;
            });
        }

        // Click method
        public Gtk.Widget get_click_method () {
            return new List_Combo_Enum ("Click Method",
                                        input_dev.settings.click_method,
                                        typeof (Inp_Dev_Settings.click_methods),
                                        (index) => {
                var profile = (Inp_Dev_Settings.click_methods) index;
                input_dev.settings.click_method = profile;
                write_new_settings (@"input type:$(input_type) click_method $(profile.parse())");
            });
        }
    }
}
