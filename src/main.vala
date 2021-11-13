namespace SwaySettings {
    public class Main : Object {
        private static string page = "";
        private static bool list_pages = false;

        private const OptionEntry[] entries = {
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

        private const string[] pages = {
            "wallpaper",
            "appearance",
            "startup-apps",
            "default-apps",
            "swaync",
            "keyboard",
            "mouse",
            "trackpad",
            "users",
        };

        private static string ? page_value = null;

        public static int main (string[] args) {
            try {
                Gtk.init_with_args (ref args, null, entries, null);

                if (list_pages) {
                    foreach (var page in pages) {
                        print ("%s\n", page);
                    }
                    return 0;
                }

                Hdy.init ();

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

                return app.run (args);
            } catch (Error e) {
                stderr.printf ("%s\n", e.message);
                return 1;
            }
        }
    }
}
