namespace Services {
    [DBus (name = "org.freedesktop.impl.portal.Wallpaper")]
    class Wallpaper : BaseService {
        public Wallpaper (DBusConnection conn) {
            base (conn);
        }

        /// Docs: https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.impl.portal.Wallpaper.html
        public uint SetWallpaperURI (ObjectPath handle,
                                     string app_id,
                                     string parent_window,
                                     string uri,
                                     HashTable<string, Variant> options)
        throws GLib.DBusError, GLib.IOError {
            // TODO: Support previews
            bool show_preview = false;
            // TODO: Support setting separate wallpapers for background and lockscreen
            string set_on = "both";

            unowned Variant _show_preview = options.get ("show-preview");
            if (_show_preview.is_of_type (VariantType.BOOLEAN)) {
                show_preview = _show_preview.get_boolean ();
            }

            unowned Variant _set_on = options.get ("set-on");
            if (_set_on.is_of_type (VariantType.STRING)) {
                // Possible values are background, lockscreen or both
                set_on = _set_on.get_string ();
            }

            // Only support Both
            // TODO: Fix this in swaysettings
            if (set_on != "both") {
                critical ("Only supports Both! Got: %s", set_on);
                return 1;
            }

            File file = File.new_for_uri (uri);
            if (file == null) {
                critical ("Wallpaper file is NULL for URI: \"%s\"", uri);
                return 1;
            }

            string ? path = file.get_path ();
            if (!SwaySettings.Functions.set_wallpaper (path, self_settings)) {
                critical ("Could not set wallpaper for path: \"%s\"", path);
                return 1;
            }

            return 0;
        }
    }
}
