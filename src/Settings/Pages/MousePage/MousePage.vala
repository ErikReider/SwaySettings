using Gee;

namespace SwaySettings {
    public class MousePage : InputPage {

        public MousePage (SettingsItem item, Hdy.Deck deck, IPC ipc) {
            base (item, deck, ipc);
        }

        public override SwaySettings.InputTypes input_type {
            get {
                return InputTypes.POINTER;
            }
        }

        public override InputPageOption get_options () {
            return new InputPageOption (new ArrayList<Gtk.Widget>.wrap ({
                get_scroll_factor (),
                get_natural_scroll (),
                get_accel_profile (),
                get_pointer_accel (),
            }), "General");
        }
    }
}
