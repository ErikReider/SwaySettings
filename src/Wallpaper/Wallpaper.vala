namespace Wallpaper {
    public static Settings self_settings;

    public enum ScaleModes {
        FILL, STRETCH, FIT, CENTER;

        public static ScaleModes parse_mode (string ? value) {
            switch (value) {
                default:
                case "fill":
                    return FILL;
                case "stretch":
                    return STRETCH;
                case "fit":
                    return FIT;
                case "center":
                    return CENTER;
            }
        }
    }

    public struct ImageInfo {
        string ? path;
        ScaleModes scale_mode;
    }

    public struct BackgroundInfo {
        Cairo.Surface * surface;
        int width;
        int height;
        ImageInfo image_info;
    }

    public class Main : Object {
        private static string action_variable_path = "";
        private static string action_variable_mode = "";
        private static bool action_variable_list_modes = false;

        private const OptionEntry[] entries = {
            {
                "path",
                'p',
                OptionFlags.NONE,
                OptionArg.STRING,
                ref action_variable_path,
                "Image path",
                "[IMG_PATH]"
            },
            {
                "mode",
                'm',
                OptionFlags.NONE,
                OptionArg.STRING,
                ref action_variable_mode,
                "Image scaling mode",
                "[IMG_MODE]"
            },
            {
                "list-modes",
                'l',
                OptionFlags.NONE,
                OptionArg.NONE,
                ref action_variable_list_modes,
                "List all scaling modes",
                null
            },
            { null }
        };

        private const string ACTION_NAME = "action";

        private static BackgroundInfo ? background_info;
        private static BackgroundInfo ? old_background_info;

        private static Gtk.Application app;

        private static bool activated = false;

        private static SimpleAction action;

        public static int main (string[] args) {
            try {
                Gtk.init_with_args (ref args, null, entries, null);

                if (action_variable_list_modes) {
                    print ("Available scaling modes: \n");
                    string[] modes = {};
                    EnumClass enumc = (EnumClass) typeof (ScaleModes).class_ref ();
                    foreach (EnumValue enum_value in enumc.values) {
                        modes += enum_value.value_nick;
                    }
                    print ("  %s\n", string.joinv (", ", modes));
                    return 0;
                }

                self_settings = new Settings ("org.erikreider.swaysettings");

                app = new Gtk.Application ("org.erikreider.swaysettings-wallpaper",
                                           ApplicationFlags.FLAGS_NONE);
                app.activate.connect ((g_app) => {
                    if (activated) return;
                    activated = true;
                    init ();
                });

                action = new SimpleAction (ACTION_NAME, new VariantType ("(si)"));
                action.activate.connect (action_activated);
                app.add_action (action);

                app.register ();

                if (action_variable_path != null) {
                    ImageInfo info = ImageInfo ();
                    info.path = action_variable_path;
                    info.scale_mode = ScaleModes.parse_mode (action_variable_mode);
                    app.activate_action (ACTION_NAME, info);
                }

                return app.run (args);
            } catch (Error e) {
                stderr.printf ("Application error: %s\n", e.message);
                return 1;
            }
        }

        private static async void action_activated (Variant ? param) {
            if (param == null || param.get_type_string () != "(si)") return;

            action.activate.disconnect (action_activated);

            ImageInfo info = ImageInfo () {
                path = param.get_child_value (0).get_string (),
                scale_mode = param.get_child_value (1).get_int32 (),
            };

            old_background_info = background_info;
            background_info = get_background (info);

            unowned List<Gtk.Window> windows = app.get_windows ();
            if (windows.length () > 0) {
                int signal_count = 0;
                windows.foreach ((w) => {
                    Window window = (Window) w;
                    ulong handler_id = 0;
                    handler_id = window.hide_transition_done.connect (() => {
                        window.disconnect (handler_id);
                        signal_count--;
                        if (signal_count == 0) {
                            action_activated.callback ();
                        }
                    });
                    signal_count++;
                    window.change_wallpaper (background_info, old_background_info);
                });
                // Wait until all windows animations are completed
                yield;
            }
            if (old_background_info != null) {
                delete old_background_info.surface;
                old_background_info = null;
            }

            action.activate.connect (action_activated);
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
                add_window (d, mon);
            });

            display.monitor_removed.connect ((d, mon) => {
                init_windows (d);
            });
        }

        private static void close_all_windows () {
            foreach (var window in app.get_windows ()) {
                window.close ();
            }
        }

        private static void add_window (Gdk.Display display,
                                        Gdk.Monitor monitor) {
            Window win = new Window (app, display, monitor, background_info);
            win.present ();
        }

        private static void init_windows (Gdk.Display display) {
            close_all_windows ();

            for (int i = 0; i < display.get_n_monitors (); i++) {
                Gdk.Monitor ? mon = display.get_monitor (i);
                if (mon == null) continue;
                add_window (display, mon);
            }
        }

        private static BackgroundInfo ? get_background (ImageInfo img_info) {
            if (img_info.path == null) return null;
            try {
                var info = BackgroundInfo ();
                info.image_info = img_info;
                var pixbuf = new Gdk.Pixbuf.from_file (info.image_info.path);
                info.surface = Gdk.cairo_surface_create_from_pixbuf (
                    pixbuf, 1, null);
                info.width = pixbuf.width;
                info.height = pixbuf.height;
                return info;
            } catch (Error e) {
                stderr.printf ("Setting wallpaper error: %s\n", e.message);
                return null;
            }
        }
    }
}
