namespace Wallpaper {
    public static Settings self_settings;

    public class Main : Object {

        private static string action_variable_path = "";

        private const OptionEntry[] entries = {
            {
                "path",
                'p',
                OptionFlags.NONE,
                OptionArg.STRING,
                ref action_variable_path,
                "Image path",
                "[PAGE_NAME]"
            },
            { null }
        };

        private static string ? path = null;

        private static Gtk.Application app;

        private const string ACTION_NAME = "path";

        private static bool activated = false;

        public static int main (string[] args) {
            try {
                Gtk.init_with_args (ref args, null, entries, null);

                self_settings = new Settings ("org.erikreider.swaysettings");

                app = new Gtk.Application ("org.erikreider.swaysettings-wallpaper",
                                           ApplicationFlags.FLAGS_NONE);
                app.activate.connect ((g_app) => {
                    if (activated) return;
                    activated = true;
                    init ();
                });

                SimpleAction action = new SimpleAction (ACTION_NAME,
                                                        VariantType.STRING);
                action.activate.connect ((param) => {
                    if (!param.is_of_type (VariantType.STRING)) {
                        path = null;
                        return;
                    }
                    path = param.get_string ();

                    foreach (Gtk.Window w in app.get_windows ()) {
                        if (!(w is Window)) {
                            Gdk.Display ? display = Gdk.Display.get_default ();
                            if (display == null) return;
                            init_windows (display);
                            return;
                        }
                        Window window = (Window) w;
                        window.set_wallpaper (path);
                    }
                });
                app.add_action (action);
                app.register ();

                if (action_variable_path != null) {
                    app.activate_action (ACTION_NAME, action_variable_path);
                }

                return app.run (args);
            } catch (Error e) {
                stderr.printf ("%s\n", e.message);
                return 1;
            }
        }

        private static void init () {
            Gdk.Display ? display = Gdk.Display.get_default ();
            if (display == null) return;

            init_windows (display);

            display.opened.connect ((d) => {
                init_windows (d);
            });

            display.closed.connect ((d, is_error) => {
                if (is_error) {
                    stderr.printf ("Display Closed due to errors...");
                }
                close_all_windows ();
            });

            display.monitor_added.connect ((d, mon) => {
                print ("ADDED\n");
                init_windows (d);
            });

            display.monitor_removed.connect ((d, mon) => {
                print ("REMOVEd\n");
                init_windows (d);
            });
        }

        private static void close_all_windows () {
            foreach (var window in app.get_windows ()) {
                window.close ();
            }
        }

        private static void init_windows (Gdk.Display display) {
            close_all_windows ();

            for (int i = 0; i < display.get_n_monitors (); i++) {
                Gdk.Monitor ? mon = display.get_monitor (i);
                if (mon == null) continue;
                Window win = new Window (app, display, mon, path);
                win.present ();
            }
        }
    }
}
