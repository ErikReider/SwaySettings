namespace SwaySettings {
    public static Settings self_settings;
    public static UserMgr userMgr;

    public class Main {
        private static string page = "";

        private static string ? page_value = null;

        private static void print_help () {
            string[] msg = {
                "Usage:",
                "  swaysettings [OPTION...]",
                "Options:",
                "  -p, --page=[PAGE_NAME]\tNavigate to page",
                "  -l, --list-pages\t\tList all pages",
            };
            print("%s\n", string.joinv("\n", msg));
            Process.exit(0);
        }

        private static void parse_cmdline (string[] args) {
            if (args.length < 2) {
                return;
            }
            switch (args[1]) {
                case "-p":
                case "--page":
                    if (args.length < 3 || args[2].length == 0) {
                        stderr.printf ("Too few arguments");
                        Process.exit(1);
                    }
                    page = args[2];
                    break;
                case "-l":
                case "--list-pages":
                    EnumClass enumc = (EnumClass) typeof (PageType).class_ref ();
                    foreach (var enum_value in enumc.values) {
                        string ? name = ((PageType) enum_value.value)
                                         .get_internal_name ();
                        if (name == null) continue;
                        print ("%s\n", name);
                    }
                    Process.exit(0);
                default:
                    print_help();
                    break;
            }
        }

        public static int main (string[] args) {
            parse_cmdline(args);

            Gtk.init ();
            Adw.init ();

            userMgr = new UserMgr ();

            Utils.wallpaper_application_registered ();

            self_settings = new Settings ("org.erikreider.swaysettings");

            try {
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
                SimpleAction action = new SimpleAction ("page", VariantType.STRING);
                action.activate.connect ((param) => {
                    page_value = param.get_string ();
                });
                app.add_action (action);
                app.register ();

                if (page != null && page.length > 0) {
                    app.activate_action ("page", page);
                }

                // Load custom CSS
                Gtk.CssProvider css_provider = new Gtk.CssProvider ();
                css_provider.load_from_resource (
                    "/org/erikreider/swaysettings/style/settings-window.css");
                Gtk.StyleContext.add_provider_for_display (
                    Gdk.Display.get_default (),
                    css_provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_SETTINGS);

                // Init resources
                var theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
                theme.add_resource_path ("/org/erikreider/swaysettings/icons");

                return app.run ();
            } catch (Error e) {
                stderr.printf ("%s\n", e.message);
                return 1;
            }
        }
    }
}
