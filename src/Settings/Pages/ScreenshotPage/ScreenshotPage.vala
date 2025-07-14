namespace SwaySettings {
    public class ScreenshotPage : PageScroll {

        public ScreenshotPage (SettingsItem item, Adw.NavigationPage page) {
            base (item, page);
        }

        public override Gtk.Widget set_child () {
            var pref_group = new Adw.PreferencesGroup ();
            pref_group.set_title ("Screenshot preferences");

            pref_group.add (get_exit_on_save ());
            pref_group.add (get_save_destination ());
            pref_group.add (get_edit_command ());

            return pref_group;
        }

        private Adw.PreferencesRow get_exit_on_save () {
            var row = new Adw.SwitchRow ();
            row.set_title ("Exit On Save");
            self_settings.bind (
                Constants.SETTINGS_SCREENSHOT_EXIT_ON_SAVE,
                row, "active", SettingsBindFlags.DEFAULT);

            row.add_suffix (get_reset_button (Constants.SETTINGS_SCREENSHOT_EXIT_ON_SAVE));
            return row;
        }

        private Adw.PreferencesRow get_save_destination () {
            var row = new Adw.ActionRow ();
            row.set_title ("Default Save Location");

            self_settings.bind (
                Constants.SETTINGS_SCREENSHOT_SAVE_DEST,
                row, "subtitle", SettingsBindFlags.DEFAULT);
            row.set_subtitle_selectable (true);

            var button = new Gtk.Button.from_icon_name ("search-folder-symbolic");
            button.set_valign (Gtk.Align.CENTER);
            button.add_css_class ("flat");
            button.set_tooltip_text ("Select the default save location");
            button.clicked.connect (find_folder_click_cb);
            row.add_suffix (button);

            row.add_suffix (get_reset_button (Constants.SETTINGS_SCREENSHOT_SAVE_DEST));

            return row;
        }

        private async void find_folder_click_cb () {
            var dialog = new Gtk.FileDialog ();
            dialog.set_modal (true);

            File ? file = null;
            try {
                file = yield dialog.select_folder ((Gtk.Window) get_root (), null);
                if (file == null) {
                    critical ("Selected file is null");
                    return;
                }
            } catch (Error e) {
                info (e.message);
                return;
            }

            self_settings.set_string (Constants.SETTINGS_SCREENSHOT_SAVE_DEST,
                                      file.get_path ());
        }

        private Adw.PreferencesRow get_edit_command () {
            var row = new Adw.EntryRow ();
            row.set_title ("Edit Command. Ex: \"swappy -f -\"");
            self_settings.bind (
                Constants.SETTINGS_SCREENSHOT_EDIT_CMD,
                row, "text", SettingsBindFlags.DEFAULT);

            row.add_suffix (get_reset_button (Constants.SETTINGS_SCREENSHOT_EDIT_CMD));
            return row;
        }

        private Gtk.Button get_reset_button (string property) {
            var button = new Gtk.Button.from_icon_name ("arrow-circular-top-right-symbolic");
            button.set_valign (Gtk.Align.CENTER);
            button.add_css_class ("flat");
            button.set_tooltip_text ("Reset to default");
            button.clicked.connect (() => {
                self_settings.reset (property);
            });

            // Hide the button when the value equals its default value
            self_settings.bind_with_mapping (
                property,
                button, "visible",
                SettingsBindFlags.GET,
                (value, variant, data) => {
                    string name = (string) data;
                    value.set_boolean (!self_settings.get_default_value (name).equal (variant));
                    return true;
                },
                (value, variant) => {
                    return true;
                },
                property, null);
            return button;
        }
    }
}
