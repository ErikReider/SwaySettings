namespace Wallpaper {
    public static Settings self_settings;

    public static BackgroundInfo background_info;
    public static BackgroundInfo old_background_info;

    public struct BackgroundInfo {
        public Utils.Config config;
        public Gdk.Texture texture;
        public int width;
        public int height;

        public string to_string () {
            return string.joinv ("\n", {
                "BackgroundInfo:",
                "\tConfig: %s".printf (config.to_string ()),
                "\tTexture: %p".printf (texture),
                "\tDimensions: %ix%i".printf (width, height),
            });
        }
    }

    public class Main : Object {
        private static string option_path = "";
        private static string option_mode = "";
        private static string option_color = "";
        private static bool option_list_modes = false;

        private const OptionEntry[] ENTRIES = {
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

        private static Gtk.Application app;

        private static bool activated = false;

        private static SimpleAction action;

        /** Separates each group of monitors and parses them separately */
        private static Utils.Config begin_parse (owned string[] args) throws Error {
            OptionContext context = new OptionContext ();
            context.set_help_enabled (true);
            context.add_main_entries (ENTRIES, null);
            context.parse_strv (ref args);

            Utils.Config config = Utils.Config();
            if (option_path == null && option_color == null) {
                // Use default wallpaper if no arguments were provided
                // Try getting GSchema wallpaper before defaulting to file
                config.path = Utils.get_wallpaper_gschema (self_settings);
                if (config.path == null) {
                    debug ("Defaulting to default wallpaper through path");
                    config.path = Utils.Config.default_path;
                }
            } else {
                if (option_path != null) {
                    config.path = option_path;
                }
                if (option_color != null) {
                    config.color = option_color;
                }
            }
            if (option_mode != null) {
                config.scale_mode = Utils.ScaleModes.parse_mode (option_mode);
            } else {
                config.scale_mode = Utils.get_scale_mode_gschema (self_settings);
            }

            return config;
        }

        public static int main (string[] args) {
            try {
                Gtk.init ();

#if USE_GLOBAL_GSCHEMA
                // Use the global compiled gschema in /usr/share/glib-2.0/schemas/*
                self_settings = new Settings ("org.erikreider.swaysettings");
#else
                message ("Using local GSchema");
                // Meant for use in development.
                // Uses the compiled gschema in SwaySettings/data/
                // Should never be used in production!
                string settings_dir = Path.build_path (Path.DIR_SEPARATOR_S,
                                                       Environment.get_current_dir (),
                                                       "data");
                SettingsSchemaSource sss = new SettingsSchemaSource.from_directory (settings_dir, null, false);
                SettingsSchema schema = sss.lookup ("org.erikreider.swaysettings", false);
                if (sss.lookup == null) {
                    error ("ID not found.\n");
                    return 0;
                }
                self_settings = new Settings.full (schema, null, null);
#endif

                Utils.Config config = begin_parse (args);

                if (option_list_modes) {
                    print ("Available scaling modes: \n");
                    string[] modes = {};
                    EnumClass enumc = (EnumClass) typeof (Utils.ScaleModes).class_ref ();
                    foreach (EnumValue enum_value in enumc.values) {
                        modes += enum_value.value_nick;
                    }
                    print ("  %s\n", string.joinv (", ", modes));
                    return 0;
                }

                app = new Gtk.Application ("org.erikreider.swaysettings-wallpaper",
                                           ApplicationFlags.DEFAULT_FLAGS);
                app.hold ();
                app.activate.connect ((g_app) => {
                    if (activated) return;
                    activated = true;
                    init ();
                });

                action = new SimpleAction (Constants.WALLPAPER_ACTION_NAME,
                    new VariantType (Constants.WALLPAPER_ACTION_FORMAT));
                action.activate.connect (action_activated);
                app.add_action (action);

                app.register ();

                app.activate_action (Constants.WALLPAPER_ACTION_NAME, config);

                return app.run ();
            } catch (Error e) {
                stderr.printf ("Application error: %s\n", e.message);
                return 1;
            }
        }

        private static async void action_activated (Variant ? param) {
            if (param == null || param.get_type_string () != Constants.WALLPAPER_ACTION_FORMAT) return;

            action.activate.disconnect (action_activated);

            old_background_info = background_info;
            background_info.config = Utils.Config () {
                path = param.get_child_value (0).get_string (),
                scale_mode = param.get_child_value (1).get_int32 (),
                color = param.get_child_value (2).get_string (),
            };

            if (background_info.config.path != null
                && background_info.config.path.length > 0) {
                try {
                    Gdk.Pixbuf pixbuf = new Gdk.Pixbuf.from_file (background_info.config.path);
                    background_info.texture = Gdk.Texture.for_pixbuf (pixbuf);
                    background_info.width = pixbuf.width;
                    background_info.height = pixbuf.height;
                } catch (Error e) {
                    stderr.printf ("Setting wallpaper error: %s\n", e.message);
                }
            }

            debug ("Old background: %s\n", old_background_info.to_string ());
            debug ("New background: %s\n", background_info.to_string ());

            app.get_windows ().foreach ((w) => {
                ((Window) w).change_wallpaper ();
            });

            action.activate.connect (action_activated);
        }

        private static void init () {
            Gdk.Display ? display = Gdk.Display.get_default ();
            if (display == null) return;

            unowned ListModel monitors = display.get_monitors ();
            monitors.items_changed.connect (() => {
                init_windows (display, monitors);
            });

            init_windows (display, monitors);
        }

        private static void close_all_windows () {
            foreach (var window in app.get_windows ()) {
                window.close ();
            }
        }

        private static void add_window (Gdk.Monitor monitor) {
            Window win = new Window (app, monitor);
            win.present ();
        }

        private static void init_windows (Gdk.Display display, ListModel monitors) {
            close_all_windows ();

            for (int i = 0; i < monitors.get_n_items (); i++) {
                Object ? obj = monitors.get_item (i);
                if (obj == null || !(obj is Gdk.Monitor)) continue;
                unowned Gdk.Monitor monitor = (Gdk.Monitor) obj;
                add_window (monitor);
            }
        }
    }
}
