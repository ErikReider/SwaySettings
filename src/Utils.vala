namespace Utils {
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

    public struct Config {
        private const ScaleModes DEFAULT_MODE = ScaleModes.FILL;
        private const string DEFAULT_COLOR = "#FFFFFF";

        public static string default_path;

        string path;
        ScaleModes scale_mode;
        string color;

        public Config () {
            default_path = Path.build_filename (Environment.get_user_config_dir (),
                "swaysettings-wallpaper");

            path = "";
            scale_mode = DEFAULT_MODE;
            color = DEFAULT_COLOR;
        }

        public string to_string () {
            return string.joinv (" ", { path, scale_mode.to_string (), color });
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
            color = color[1 :];

            int hex_value;
            bool result = int.try_parse (color, out hex_value, null, 16);
            if (!result) return _c;
            _c.alpha = 1.0f;
            _c.red = ((hex_value >> 16) & 0xFF) / 255.0f;
            _c.green = ((hex_value >> 8) & 0xFF) / 255.0f;
            _c.blue = (hex_value & 0xFF) / 255.0f;
            return _c;
        }
    }

}
