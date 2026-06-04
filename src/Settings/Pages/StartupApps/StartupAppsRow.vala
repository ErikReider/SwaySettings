namespace SwaySettings {
    [GtkTemplate (ui = "/org/erikreider/swaysettings/ui/StartupAppsRow.ui")]
    private class StartupAppsRow : Gtk.ListBoxRow {
        public DesktopAppInfo app_info { get; construct; }

        public string ?display_name { get; construct; }
        public string ?cmdline { get; construct; }
        public Icon ?gicon { get; construct; }
        public string ?fallback_icon_name { get; construct; }

        public signal void remove_clicked (DesktopAppInfo app_info);

        construct {
            if (should_set_fallback_icon ()) {
                fallback_icon_name = "application-x-executable-symbolic";
            }
        }

        public StartupAppsRow (DesktopAppInfo app_info) {
            Object (
                app_info: app_info,
                display_name: app_info.get_display_name (),
                cmdline: app_info.get_commandline (),
                gicon: app_info.get_icon (),
                fallback_icon_name: null
            );
        }

        private bool should_set_fallback_icon () {
            if (gicon == null) {
                return true;
            }
            var theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
            return !theme.has_gicon (gicon);
        }

        [GtkCallback]
        private void remove_button_clicked_cb () {
            remove_clicked (app_info);
        }
    }
}
