using Gee;

namespace SwaySettings {
    public class Trackpad_Widget : Input_Page {

        public Trackpad_Widget (string label, Hdy.Deck deck, IPC ipc) {
            base (label, deck, ipc);
        }

        public override SwaySettings.Input_Types input_type {
            get {
                return Input_Types.touchpad;
            }
        }

        public override ArrayList<Gtk.Widget> get_options () {
            return new ArrayList<Gtk.Widget>.wrap ({
                get_scroll_factor (),
                get_natural_scroll (),
                get_tap (),
                get_click_method (),
                get_dwt (),
                get_doem (),
                get_accel_profile (),
                get_pointer_accel (),
            });
        }
    }
}
