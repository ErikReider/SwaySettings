using Gee;

namespace SwaySettings {
    public class Keyboard_Page : Input_Page {

        public Keyboard_Page (string label, Hdy.Deck deck, IPC ipc) {
            base (label, deck, ipc);
        }

        public override SwaySettings.Input_Types input_type {
            get {
                return Input_Types.keyboard;
            }
        }

        public override ArrayList<Gtk.Widget> get_top_widgets () {
            return new ArrayList<Gtk.Widget>.wrap ({
                get_keyboard_language (),
            });
        }
    }
}
