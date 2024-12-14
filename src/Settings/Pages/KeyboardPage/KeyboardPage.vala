using Gee;

namespace SwaySettings {
    public class KeyboardPage : InputPage {

        public KeyboardPage (SettingsItem item,
                             Adw.NavigationPage page,
                             IPC ipc) {
            base (item, page, ipc);
        }

        public override SwaySettings.InputTypes input_type {
            get {
                return InputTypes.KEYBOARD;
            }
        }

        public override ArrayList<InputPageSection> get_top_sections () {
            return new ArrayList<InputPageSection>.wrap ({
                new InputPageSection (get_keyboard_language (),
                                      "Keyboard Layout"),
            });
        }
    }
}
