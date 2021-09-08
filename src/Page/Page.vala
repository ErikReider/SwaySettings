using Gee;

namespace SwaySettings {
    [GtkTemplate (ui = "/org/erikreider/swaysettings/Page/Page.ui")]
    public abstract class Page : Gtk.Bin {

        [GtkChild]
        public unowned Gtk.Box root_box;
        [GtkChild]
        public unowned Gtk.Button back_button;
        [GtkChild]
        public unowned Gtk.Label title;
        [GtkChild]
        public unowned Gtk.ButtonBox button_box;

        public string label;

        public IPC ipc;

        protected Page (string label, Hdy.Deck deck, IPC ipc) {
            Object ();
            this.ipc = ipc;
            this.label = label;
            title.set_text (this.label);
            back_button.clicked.connect (() => {
                deck.navigate (Hdy.NavigationDirection.BACK);
            });
            deck.child_switched.connect ((deck_child_index) => {
                if (deck_child_index == 0) on_back (deck);
            });
        }

        public virtual void on_back (Hdy.Deck deck) {
        }

        public static Gtk.Container get_scroll_widget (Gtk.Widget widget, bool have_margin = true, bool shadow = false,
                                                       int clamp_max = 600, int clamp_tight = 400) {
            var scrolled_window = new Gtk.ScrolledWindow (null, null);
            if (shadow) scrolled_window.shadow_type = Gtk.ShadowType.IN;
            scrolled_window.expand = true;
            var clamp = new Hdy.Clamp ();
            clamp.maximum_size = clamp_max;
            clamp.tightening_threshold = clamp_tight;
            clamp.orientation = Gtk.Orientation.HORIZONTAL;
            if (have_margin) {
                int margin = 8;
                clamp.set_margin_top (margin);
                clamp.set_margin_start (margin);
                clamp.set_margin_bottom (margin);
                clamp.set_margin_end (margin);
            }

            clamp.add (widget);
            scrolled_window.add (clamp);
            scrolled_window.show_all ();
            return scrolled_window;
        }
    }

    public abstract class Page_Scroll : Page {

        public virtual bool have_margin {
            get {
                return true;
            }
        }
        public virtual bool shadow {
            get {
                return false;
            }
        }
        public virtual int clamp_max {
            get {
                return 600;
            }
        }
        public virtual int clamp_tight {
            get {
                return 400;
            }
        }

        protected Page_Scroll (string label, Hdy.Deck deck, IPC ipc) {
            base (label, deck, ipc);
            root_box.add (get_scroll_widget (
                              set_child (),
                              have_margin,
                              shadow,
                              clamp_max,
                              clamp_tight));
        }

        public void refresh () {
            foreach (var child in root_box.get_children ()) {
                root_box.remove (child);
            }
            root_box.add (get_scroll_widget (
                              set_child (),
                              have_margin,
                              shadow,
                              clamp_max,
                              clamp_tight));
        }

        public abstract Gtk.Widget set_child ();
    }

    public abstract class Page_Tabbed : Page {

        public Gtk.Stack stack;

        protected Page_Tabbed (string label,
                               Hdy.Deck deck,
                               IPC ipc,
                               string no_tabs_text = "Nothing here...") {
            base (label, deck, ipc);

            stack = new Gtk.Stack ();
            stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
            var stack_switcher = new Gtk.StackSwitcher ();
            // stack_switcher.button_release_event.connect ((widget) => {
            // subtitle.set_text (stack.visible_child_name);
            // return false;
            // });
            stack_switcher.stack = stack;
            stack_switcher.set_halign (Gtk.Align.CENTER);
            stack_switcher.set_margin_top (8);
            stack_switcher.set_margin_start (8);
            stack_switcher.set_margin_bottom (8);
            stack_switcher.set_margin_end (8);

            // stack.set_margin_top (margin);
            // stack.set_margin_start (margin);
            // stack.set_margin_bottom (margin);
            // stack.set_margin_end (margin);

            root_box.add (stack_switcher);
            root_box.add (stack);
            root_box.show_all ();

            var all_tabs = tabs ();
            if (all_tabs.length < 1) {
                stack.add (new Gtk.Label (no_tabs_text));
                stack.show_all ();
            } else {
                foreach (var tab in all_tabs) {
                    stack.add_titled (tab, tab.tab_name, tab.tab_name);
                }
                if (all_tabs.length == 1) {
                    stack_switcher.visible = false;
                    title.set_text (stack.visible_child_name);
                }
            }
        }

        public override void on_back (Hdy.Deck deck) {
            stack.set_visible_child (stack.get_children ().nth_data (0));
        }

        public abstract Page_Tab[] tabs ();
    }

    public abstract class Page_Tab : Gtk.Box {
        public string tab_name;

        public IPC ipc;

        protected Page_Tab (string tab_name, IPC ipc) {
            Object ();
            this.ipc = ipc;

            this.orientation = Gtk.Orientation.VERTICAL;
            this.spacing = 0;
            this.expand = true;

            this.tab_name = tab_name;
            this.show_all ();
        }
    }
    public abstract class Input_Page : Page_Scroll {
        Input_Device device;
        bool has_type = false;

        public abstract Input_Types input_type { get; }

        protected Input_Page (string label, Hdy.Deck deck, IPC ipc) {
            base (label, deck, ipc);
        }

        public abstract ArrayList<Gtk.Widget> get_options ();

        public override Gtk.Widget set_child () {
            init_input_devices ();

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            if (!has_type) box.set_sensitive (false);

            var list_box = new Gtk.ListBox ();
            list_box.get_style_context ().add_class ("content");

            var options = get_options ();
            foreach (var option in options) {
                if (option != null) list_box.add (option);
            }

            box.add (list_box);
            return box;
        }

        void init_input_devices () {
            var ipc_output = ipc.get_reply (Sway_commands.GET_IMPUTS).get_array ();
            foreach (var elem in ipc_output.get_elements ()) {
                var obj = elem.get_object ();
                Input_Types type = Input_Types.parse_string (obj.get_string_member ("type") ?? "");
                if (input_type != type) continue;
                has_type = true;
                get_device_settings (obj, type);
                return;
            }
            if (device == null) device = new Input_Device ("", input_type);
        }

        void get_device_settings (Json.Object ? obj, Input_Types type) {
            var device = new Input_Device (obj.get_string_member ("identifier"), type);
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

            if (type == Input_Types.touchpad) {
                // scroll_method
                var scroll_method_string = lib.get_string_member_with_default ("scroll_method", "two_finger");
                device.settings.scroll_method = Inp_Dev_Settings.scroll_methods.parse (scroll_method_string);
            }
            this.device = device;
        }

        void write_new_settings (string str) {
            ipc.run_command (str);
            string file_name = Strings.settings_folder_input_pointer;
            if (device.type == Input_Types.touchpad) {
                file_name = Strings.settings_folder_input_touchpad;
            }
            Functions.write_settings (file_name, device.get_settings ());
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
