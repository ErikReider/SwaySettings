namespace Services {
    [DBus (name = "org.freedesktop.impl.portal.Settings")]
    // Docs: https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.impl.portal.Settings.html
    class Settings : BaseService {
        public uint version {
            get;
            default = 2;
        }

        private GLib.Settings ? gnome_settings;
        private const string APPEARANCE_NAMESPACE = "org.freedesktop.appearance";
        private const string ACCENT_COLOR = "accent-color";

        public Settings (DBusConnection conn) {
            base (conn);

            gnome_settings = new GLib.Settings ("org.gnome.desktop.interface");
            gnome_settings.changed.connect ((key) => {
                if (key == ACCENT_COLOR) {
                    SettingChanged (APPEARANCE_NAMESPACE, ACCENT_COLOR, get_accent_color ());
                }
            });
        }

        private Variant get_accent_color () {
            var color = SwaySettings.Functions.get_accent_color (gnome_settings);
            Gdk.RGBA rgb = color.to_rgba ();
            return new Variant ("(ddd)", rgb.red, rgb.green, rgb.blue);
        }

        private bool namespaces_match (string ref_namespace, string[] namespaces) {
            // Return true when a namespace is empty or when the list is empty
            int i = 0;
            for (; i < namespaces.length; i++) {
                string test = namespaces[i];
                if (test.length == 0) {
                    return true;
                }

                if (test == ref_namespace) {
                    return true;
                }
            }
            return i == 0;
        }

        /* *INDENT-OFF* */
        public HashTable<string, HashTable<string, Variant>> ReadAll (string[] namespaces)
        /* *INDENT-ON* */
        throws DBusError, IOError {
            debug ("ReadAll: [ %s ]", string.joinv (", ", namespaces));
            /* *INDENT-OFF* */
            var table = new HashTable<string, HashTable<string, Variant>> (str_hash, str_equal);
            /* *INDENT-ON* */

            // TODO: Support globbing
            if (namespaces_match (APPEARANCE_NAMESPACE, namespaces)) {
                var appearance = new HashTable<string, Variant> (str_hash, str_equal);
                appearance.set (ACCENT_COLOR, get_accent_color ());
                table.set (APPEARANCE_NAMESPACE, appearance);
            }

            return table;
        }

        public Variant Read (string namespace, string key) throws DBusError, IOError {
            debug ("Read: %s: %s", namespace, key);

            if (namespace == APPEARANCE_NAMESPACE
                && key == ACCENT_COLOR) {
                return get_accent_color ();
            }

            throw new DBusError.FAILED ("Requested setting not found");
        }

        public signal void SettingChanged (string namespace, string key, Variant value);
    }
}
