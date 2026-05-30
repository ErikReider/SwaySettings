namespace Utils.Wallpaper {
    public const string ACTION_NAME = "action";
    public const string ACTION_FORMAT = "(sis)";

    private errordomain ThumbnailerError { FAILED; }

    public enum ScaleModes {
        FILL = 0,
        STRETCH = 1,
        FIT = 2,
        CENTER = 3;

        public string to_string () {
            switch (this) {
                default:
                case FILL:
                    return "fill";
                case STRETCH:
                    return "stretch";
                case FIT:
                    return "fit";
                case CENTER:
                    return "center";
            }
        }

        public string to_title () {
            switch (this) {
                default:
                case FILL:
                    return "Fill Screen";
                case STRETCH:
                    return "Stretch Screen";
                case FIT:
                    return "Fit Screen";
                case CENTER:
                    return "Center Screen";
            }
        }

        public Gtk.ContentFit to_content_fit () {
            switch (this) {
                default:
                case FILL:
                    return Gtk.ContentFit.FILL;
                case STRETCH:
                    return Gtk.ContentFit.COVER;
                case FIT:
                    return Gtk.ContentFit.CONTAIN;
                case CENTER:
                    return Gtk.ContentFit.SCALE_DOWN;
            }
        }

        public static ScaleModes parse_mode (string ?value) {
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

    public struct Config {
        private const ScaleModes DEFAULT_MODE = ScaleModes.FILL;
        private const string DEFAULT_COLOR = "#FFFFFF";

        public static string default_path;

        string path;
        ScaleModes scale_mode;
        string color;

        public Config () {
            default_path = get_default_path ();

            path = "";
            scale_mode = DEFAULT_MODE;
            color = DEFAULT_COLOR;
        }

        public static inline string get_default_path () {
            return Path.build_path (Path.DIR_SEPARATOR_S,
                                    Environment.get_user_config_dir (),
                                    "swaysettings-wallpaper");
        }

        public inline string to_string () {
            return string.joinv (" ", { path, scale_mode.to_string (), color });
        }

        public inline bool is_path_valid () {
            return path != null && path.length > 0;
        }

        public bool has_image (out File ?fd, Cancellable cancellable) {
            fd = null;
            if (!is_path_valid ()) {
                return false;
            }
            File file = File.new_for_path (path);
            FileType type = file.query_file_type (FileQueryInfoFlags.NONE, cancellable);
            if (type != FileType.REGULAR && type != FileType.SYMBOLIC_LINK
                && type != FileType.SHORTCUT) {
                return false;
            }

            fd = file;
            return true;
        }

        public inline bool cmp (Config other) {
            return this.path == other.path
                   && this.scale_mode == other.scale_mode
                   && this.color == other.color;
        }

        public Gdk.RGBA get_color () {
            Gdk.RGBA _c = Gdk.RGBA ();
            var color = this.color;
            if (color.length != 7 || color[0] != '#') {
                stderr.printf ("Color not valid! ");
                stderr.printf ("Using \"#FFFFFF\". ");
                stderr.printf ("Please use this format: \"#RRGGBB\"\n");
                color = DEFAULT_COLOR;
            }
            // Remove the leading #
            color = color.substring (1);

            int hex_value;
            bool result = int.try_parse (color, out hex_value, null, 16);
            if (!result) {
                return _c;
            }
            _c.alpha = 1.0f;
            _c.red = ((hex_value >> 16) & 0xFF) / 255.0f;
            _c.green = ((hex_value >> 8) & 0xFF) / 255.0f;
            _c.blue = (hex_value & 0xFF) / 255.0f;
            return _c;
        }
    }

    public static void update_config (owned Config config) throws Error {
        Application app = new Application (
            AppIds.WALLPAPER,
            ApplicationFlags.IS_LAUNCHER);

        if (!app.is_registered) {
            // Register wallpaper application
            app.register ();
        }

        app.activate_action (ACTION_NAME, config);
    }

    // TODO: Replace `GLib.Settings` with our own `GSettings` subclassing `GLib.Settings`
    public static bool set_wallpaper (string file_path,
                                      Settings ?self_settings) {
        if (file_path == null || self_settings == null) {
            return false;
        }
        try {
            string dest_path = Config.get_default_path ();

            File file = File.new_for_path (file_path);
            File file_dest = File.new_for_path (dest_path);

            if (!file.query_exists ()) {
                stderr.printf (
                    "File %s not found or permissions missing",
                    file_path);
                return false;
            }

            file.copy (file_dest, FileCopyFlags.OVERWRITE);
            generate_thumbnail (dest_path, true);

            // TODO: Move info function
            GSchema.set_gsetting (self_settings,
                                  Constants.SETTINGS_WALLPAPER_PATH,
                                  file_path);
            Config config = Config () {
                path = file_path,
                scale_mode = get_scale_mode_setting (self_settings),
            };
            update_config (config);
        } catch (Error e) {
            stderr.printf ("Setting wallpaper error: %s\n", e.message);
            return false;
        }

        return true;
    }

    public static string ?generate_thumbnail (string image_path,
                                              bool delete_past = false,
                                              int size = 256) throws Error {
        File file = File.new_for_path (image_path);
        string path = file.get_uri ();
        string checksum = Checksum.compute_for_string (ChecksumType.MD5, path, path.length);
        // Only use large thumbnails to match the widget size
        string checksum_path = "%s/thumbnails/large/%s.png".printf (
            Environment.get_user_cache_dir (), checksum);

        File sum_file = File.new_for_path (checksum_path);
        bool exists = sum_file.query_exists ();
        // Remove the old file
        if (delete_past && exists) {
            sum_file.delete ();
            exists = false;
        }
        if (!exists) {
            string error;
            string[] args = {
                "glycin-thumbnailer",
                "--input", path,
                "--output", checksum_path,
                "--size", size.to_string (),
            };
            // TODO: Use glycin lib instead of spawning process...
            bool status = Process.spawn_sync (null, args, null,
                                              SpawnFlags.STDOUT_TO_DEV_NULL
                                              | SpawnFlags.SEARCH_PATH_FROM_ENVP,
                                              null, null, out error, null);
            if (!status) {
                throw new ThumbnailerError.FAILED (error);
            }
        }

        return checksum_path;
    }

    public static ScaleModes get_scale_mode_setting (Settings settings) {
        // TODO: refactor
        Variant ?variant = GSchema.get_gsetting (settings,
                                                 Constants.
                                                  SETTINGS_WALLPAPER_SCALING_MODE,
                                                 VariantType.INT32);
        if (variant == null
            || !variant.get_type ().equal (VariantType.INT32)) {
            return 0;
        }
        return (ScaleModes) variant.get_int32 ();
    }

    public static string ?get_path_setting (Settings settings) {
        // TODO: refactor
        Variant ?variant = GSchema.get_gsetting (settings,
                                                 Constants.SETTINGS_WALLPAPER_PATH,
                                                 VariantType.STRING);
        if (variant == null
            || !variant.get_type ().equal (VariantType.STRING)) {
            return null;
        }
        return variant.get_string ();
    }
}
