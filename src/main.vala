namespace SwaySettings {
    public static Settings self_settings;

    public class Main : Object {

        private static string page = "";
        private static bool list_pages = false;

        private const OptionEntry[] ENTRIES = {
            {
                "page",
                'p',
                OptionFlags.NONE,
                OptionArg.STRING,
                ref page,
                "Navigate to page",
                "[PAGE_NAME]"
            },
            {
                "list-pages",
                'l',
                OptionFlags.NONE,
                OptionArg.NONE,
                ref list_pages,
                "List all pages",
                null
            },
            { null }
        };

        private static string ? page_value = null;

        public static int main (string[] args) {
            try {
                Gtk.init_with_args (ref args, null, ENTRIES, null);

                if (list_pages) {
                    EnumClass enumc = (EnumClass) typeof (PageType).class_ref ();
                    foreach (var enum_value in enumc.values) {
                        string ? name = ((PageType) enum_value.value)
                                         .get_internal_name ();
                        if (name == null) continue;
                        print ("%s\n", name);
                    }
                    return 0;
                }

                Hdy.init ();

#if USE_GLOBAL_GSCHEMA
                // Use the global compiled gschema in /usr/share/glib-2.0/schemas/*
                self_settings = new Settings ("org.erikreider.swaysettings");
#else
                // Meant for use in development.
                // Uses the compiled gschema in SwaySettings/data/
                // Should never be used in production!
                string settings_dir = Path.build_path (Path.DIR_SEPARATOR_S,
                                                       Environment.get_current_dir (),
                                                       "data");
                SettingsSchemaSource sss = new SettingsSchemaSource.from_directory (settings_dir, null, false);
                SettingsSchema schema = sss.lookup ("org.erikreider.swaysettings", false);
                if (sss.lookup == null) {
                    print ("ID not found.");
                    return 0;
                }
                self_settings = new Settings.full (schema, null, null);
#endif

                var app = new Gtk.Application ("org.erikreider.swaysettings",
                                               ApplicationFlags.FLAGS_NONE);
                app.activate.connect (() => {
                    Window ? win = (Window) app.active_window;
                    if (win == null) {
                        win = new SwaySettings.Window (app);
                    }
                    win.present ();
                    if (page_value != null && page_value.length > 0) {
                        win.navigato_to_page (page_value);
                    }
                });
                SimpleAction simple_action = new SimpleAction (
                    "page", GLib.VariantType.STRING);
                simple_action.activate.connect ((param) => {
                    page_value = param.get_string ();
                });
                app.add_action (simple_action);
                app.register ();

                app.activate_action ("page", page ?? "");

                // Load custom CSS
                Gtk.CssProvider css_provider = new Gtk.CssProvider ();
                css_provider.load_from_resource (
                    "/org/erikreider/swaysettings/style.css");
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (),
                    css_provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_SETTINGS);

                return app.run (args);
            } catch (Error e) {
                stderr.printf ("%s\n", e.message);
                return 1;
            }
        }
    }
}
