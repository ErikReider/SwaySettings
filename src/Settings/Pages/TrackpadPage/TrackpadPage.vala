using Gee;

namespace SwaySettings {
    public class TrackpadPage : InputPage {

        public TrackpadPage (SettingsItem item, Hdy.Deck deck, IPC ipc) {
            base (item, deck, ipc);
        }

        public override SwaySettings.InputTypes input_type {
            get {
                return InputTypes.TOUCHPAD;
            }
        }

        public override InputPageOption get_options () {
            return new InputPageOption (new ArrayList<Gtk.Widget>.wrap ({
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
