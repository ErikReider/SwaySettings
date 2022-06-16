using Gee;

namespace SwaySettings {
    public class KeyboardPage : InputPage {

        public KeyboardPage (SettingsItem item, Hdy.Deck deck, IPC ipc) {
            base (item, deck, ipc);
        }

        public override SwaySettings.InputTypes input_type {
            get {
                return InputTypes.KEYBOARD;
            }
        }

        public override ArrayList<InputPageSection> get_top_sections () {
            return new ArrayList<InputPageSection>.wrap ({
                new InputPageSection (get_keyboard_language (), "Keyboard Layout"),
            });
        }
    }
}
