using Gee;

namespace SwaySettings {
    public class Mouse_Page : Input_Page {

        public Mouse_Page (string label, Hdy.Deck deck, IPC ipc) {
            base (label, deck, ipc);
        }

        public override SwaySettings.Input_Types input_type {
            get {
                return Input_Types.pointer;
            }
        }

        public override ArrayList<Gtk.Widget> get_options () {
            return new ArrayList<Gtk.Widget>.wrap ({
                get_scroll_factor (),
                get_natural_scroll (),
                get_accel_profile (),
                get_pointer_accel (),
            });
        }
    }
}
