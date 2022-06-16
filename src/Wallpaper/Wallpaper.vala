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

    public struct Color {
        double r;
        double g;
        double b;
    }

    public struct Config {
        public const string DEFAULT_OUTPUT = "*";
        public const ScaleModes DEFAULT_MODE = ScaleModes.FILL;
        public const string DEFAULT_COLOR = "#FFFFFF";

        static string default_path;

        string output;
        string path;
        ScaleModes scale_mode;
        string color;

        public Config () {
            default_path = Path.build_filename (Environment.get_user_cache_dir (), "wallpaper");

            output = DEFAULT_OUTPUT;
            path = default_path;
            scale_mode = DEFAULT_MODE;
            color = DEFAULT_COLOR;
        }

        public string to_string () {
            return string.joinv (" ", { output, path, scale_mode.to_string (), color });
        }

        public Color get_color () {
            Color _c = Color ();
            var color = this.color;
            if (color.length != 7 || color[0] != '#') {
                stderr.printf ("Color not valid! ");
                stderr.printf ("Using \"#FFFFFF\". ");
                stderr.printf ("Please use this format: \"#RRGGBB\"\n");
                color = DEFAULT_COLOR;
            }
            // Remove the leading #
            color = color[1 :];

            int hex_value;
            bool result = int.try_parse (color, out hex_value, null, 16);
            if (!result) return _c;
            _c.r = ((hex_value >> 16) & 0xFF) / 255.0;
            _c.g = ((hex_value >> 8) & 0xFF) / 255.0;
            _c.b = (hex_value & 0xFF) / 255.0;
            return _c;
        }

        public static Config from_list (Config[] configs) {
            Config config = Config ();
            foreach (Config cfg in configs) {
                if (cfg.output != DEFAULT_OUTPUT) config.output = cfg.output;
                if (cfg.path != default_path) config.path = cfg.path;
                if (cfg.scale_mode != DEFAULT_MODE) config.scale_mode = cfg.scale_mode;
                if (cfg.color != DEFAULT_COLOR) config.color = cfg.color;
            }
            return config;
        }
    }

    public struct BackgroundInfo {
        Cairo.Surface * surface;
        int width;
        int height;
    }

    public class Main : Object {
        private static string option_output = "";
        private static string option_path = "";
        private static string option_mode = "";
        private static string option_color = "";
        private static bool option_list_modes = false;

        private const OptionEntry[] ENTRIES = {
            { // Parse Output but hide it from the user. Avoids "Unknown option -o"
                "output",
                'o',
                OptionFlags.HIDDEN,
                OptionArg.STRING,
                ref option_output,
                "Output",
                "[OUTPUT_NAME]"
            },
            {
                "image",
                'i',
                OptionFlags.NONE,
                OptionArg.FILENAME,
                ref option_path,
                "Image path",
                "[IMG_PATH]"
            },
            {
                "mode",
                'm',
                OptionFlags.NONE,
                OptionArg.STRING,
                ref option_mode,
                "Image scaling mode",
                "[IMG_MODE]"
            },
            {
                "color",
                'c',
                OptionFlags.NONE,
                OptionArg.STRING,
                ref option_color,
                "Background color",
                "[#rrggbb]"
            },
            {
                "list-modes",
                'l',
                OptionFlags.NONE,
                OptionArg.NONE,
                ref option_list_modes,
                "List all scaling modes",
                null
            },
            { null }
        };

        private const string ACTION_NAME = "action";
        private const string ACTION_FORMAT = "(ssis)";

        private static BackgroundInfo ? background_info;
        private static BackgroundInfo ? old_background_info;
        private static Config config;

        private static Gtk.Application app;

        private static bool activated = false;

        private static SimpleAction action;

        /** Seperates each group of monitors and parses them separately */
        private static void begin_parse (owned string[] args) throws Error {
            string prog_name = args[0];
            // remove the prog_name
            args = args[1 :];

            // Seperate all args into groups (grouped by monitor)
            Array<Array<string> > seperated = new Array<Array<string> > ();
            if ("-o" in args || "--output" in args) {
                int start = -1;
                for (int i = 0; i < args.length; i++) {
                    string arg = args[i];
                    if (arg == "-o" || arg == "--output") start++;
                    // Ignore all args before -o or --outputs
                    if (start == -1) continue;
                    // Add a new list if this is the first iteration
                    if (seperated.length - 1 != start) {
                        var list = new Array<string> ();
                        list.append_val (prog_name);
                        seperated.append_val (list);
                    }

                    unowned Array<string> list = seperated.index (start);
                    list.append_val (arg);
                }
            } else {
                // No monitor arg provided. All args should be parsed as default config
                var list = new Array<string> ();
                list.append_val (prog_name);
                foreach (string arg in args) list.append_val (arg);
                seperated.append_val (list);
            }

            // Begin parsing all seperated args
            Config[] configs = {};
            OptionContext context = new OptionContext ();
            context.set_help_enabled (true);
            context.add_main_entries (ENTRIES, null);
            foreach (var l in seperated) {
                context.parse_strv (ref l.data);
                // Gather the parsed options before overridden by the next parse
                if (option_output == null
                    && option_path == null
                    && option_mode == null
                    && option_color == null) {
                    continue;
                }

                Config info = Config ();
                if (option_output != null) info.output = option_output;
                if (option_path != null) info.path = option_path;
                if (option_mode != null) info.scale_mode = ScaleModes.parse_mode (option_mode);
                if (option_color != null) info.color = option_color;

                // Uses the config with global output as default config
                if (info.output == Config.DEFAULT_OUTPUT) {
                    config = info;
                    return;
                }
                configs += info;
            }
            config = Config.from_list (configs);
        }

        public static int main (string[] args) {
            try {
                begin_parse (args);
                args = null;
                Gtk.init (ref args);

                if (option_list_modes) {
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

                action = new SimpleAction (ACTION_NAME, new VariantType (ACTION_FORMAT));
                action.activate.connect (action_activated);
                app.add_action (action);

                app.register ();

                app.activate_action (ACTION_NAME, config);

                return app.run (args);
            } catch (Error e) {
                stderr.printf ("Application error: %s\n", e.message);
                return 1;
            }
        }

        private static async void action_activated (Variant ? param) {
            if (param == null || param.get_type_string () != ACTION_FORMAT) return;

            action.activate.disconnect (action_activated);

            config = Config () {
                output = param.get_child_value (0).get_string (),
                path = param.get_child_value (1).get_string (),
                scale_mode = param.get_child_value (2).get_int32 (),
                color = param.get_child_value (3).get_string (),
            };

            old_background_info = background_info;
            background_info = get_background ();

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

        private static void add_window (Gdk.Display display, Gdk.Monitor monitor) {
            Window win = new Window (app,
                                     display,
                                     monitor,
                                     config,
                                     background_info);
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

        private static BackgroundInfo ? get_background () {
            if (config.path == null || config.path.length == 0) return null;
            try {
                var info = BackgroundInfo ();
                var pixbuf = new Gdk.Pixbuf.from_file (config.path);
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
