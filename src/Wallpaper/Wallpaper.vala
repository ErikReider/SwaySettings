namespace Wallpaper {
    public static Settings self_settings;

    public struct BackgroundInfo {
        public Utils.Config config;
        public Gdk.Texture texture;
        public int width;
        public int height;
        public uint file_hash;

        public string to_string () {
            return string.joinv ("\n", {
                "BackgroundInfo:",
                "\tConfig: %s".printf (config.to_string ()),
                "\tTexture: %p".printf (texture),
                "\tDimensions: %ix%i".printf (width, height),
                "\tHash: %u".printf (file_hash),
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
        private static Utils.Config current_config;

        private static unowned ListModel monitors;
        private static ListStore windows;

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

                current_config = begin_parse (args);

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

                app.register ();

                // Exit early if a instance is already running
                if (app.get_is_remote ()) {
                    app.activate_action (Constants.WALLPAPER_ACTION_NAME, current_config);
                    app.get_dbus_connection ().flush_sync ();
                    return 0;
                }

                return app.run ();
            } catch (Error e) {
                stderr.printf ("Application error: %s\n", e.message);
                return 1;
            }
        }

        private static async void action_activated (Variant ? param) {
            if (param == null || param.get_type_string () != Constants.WALLPAPER_ACTION_FORMAT) return;

            action.activate.disconnect (action_activated);

            current_config = Utils.Config () {
                path = param.get_child_value (0).get_string (),
                scale_mode = param.get_child_value (1).get_int32 (),
                color = param.get_child_value (2).get_string (),
            };


            uint n_items = windows.get_n_items ();
            int count = (int) n_items;
            for (int i = 0; i < count; i++) {
                Window window = (Window) windows.get_item (i);
                window.change_wallpaper.begin (current_config, (obj, res) => {
                    window.change_wallpaper.end (res);
                    if (AtomicInt.dec_and_test (ref count)) {
                        action_activated.callback ();
                    }
                });
            }
            yield;

            // Run all the animations at the same time, after all monitors
            // have loaded its new textures
            for (int i = 0; i < n_items; i++) {
                Window window = (Window) windows.get_item (i);
                window.run_animation ();
            }

            action.activate.connect (action_activated);
        }

        private static void init () {
            windows = new ListStore (typeof (Window));

            Gdk.Display ? display = Gdk.Display.get_default ();
            assert_nonnull (display);

            monitors = display.get_monitors ();
            monitors.items_changed.connect (monitors_changed);

            monitors_changed (0, 0, monitors.get_n_items ());

            // Activate once all windows have been added
            action = new SimpleAction (Constants.WALLPAPER_ACTION_NAME,
                new VariantType (Constants.WALLPAPER_ACTION_FORMAT));
            action.activate.connect (action_activated);

            app.add_action (action);
            app.activate_action (Constants.WALLPAPER_ACTION_NAME, current_config);
        }

        private static void monitors_changed (uint position, uint removed, uint added) {
            for (uint i = 0; i < removed; i++) {
                Window window = (Window) windows.get_item (position + i);
                window.close ();
                windows.remove (position + i);
            }

            for (uint i = 0; i < added; i++) {
                Gdk.Monitor monitor = (Gdk.Monitor) monitors.get_item (position + i);
                Window win = new Window (app, monitor);
                windows.insert (position + i, win);
                win.present ();
            }

            if (app.has_action (Constants.WALLPAPER_ACTION_NAME)) {
                app.activate_action (Constants.WALLPAPER_ACTION_NAME, current_config);
            }
        }
    }
}
