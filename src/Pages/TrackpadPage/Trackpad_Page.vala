using Gee;

namespace SwaySettings {
    public class Trackpad_Page : Input_Page {

        public Trackpad_Page (string label, Hdy.Deck deck, IPC ipc) {
            base (label, deck, ipc);
        }

        public override SwaySettings.Input_Types input_type {
            get {
                return Input_Types.TOUCHPAD;
            }
        }

        public override Input_Page_Option get_options () {
            return new Input_Page_Option (new ArrayList<Gtk.Widget>.wrap ({
                get_state_widget (),
                get_scroll_factor (),
                get_natural_scroll (),
                get_tap (),
                get_click_method (),
                get_dwt (),
                get_accel_profile (),
                get_pointer_accel (),
            }), "General");
        }
    }
}
