using Gee;

namespace SwaySettings {

    enum PositionX {
        RIGHT, LEFT;

        public string parse () {
            EnumClass enumc = (EnumClass) typeof (PositionX).class_ref ();
            return enumc.get_value_by_name (this.to_string ()).value_nick;
        }
    }

    enum PositionY {
        TOP, BOTTOM;

        public string parse () {
            EnumClass enumc = (EnumClass) typeof (PositionY).class_ref ();
            return enumc.get_value_by_name (this.to_string ()).value_nick;
        }
    }

    class ConfigModel : Object, Json.Serializable {
        public PositionX positionX { get; set; }
        public PositionY positionY { get; set; }

        public Json.Node serialize_property (string property_name, GLib.Value value, GLib.ParamSpec pspec) {
            var node = new Json.Node (Json.NodeType.VALUE);
            switch (property_name) {
                case "positionX":
                    node.set_string (((PositionX) value.get_enum ()).parse ());
                    break;
                case "positionY":
                    node.set_string (((PositionY) value.get_enum ()).parse ());
                    break;
                default:
                    node.set_value (value);
                    break;
            }
            return node;
        }

        public string json_serialized () {
            var json = Json.gobject_serialize (this);
            string json_string = Json.to_string (json, true);
            return json_string;
        }
    }

    /*
     * Reads the config file from the first found config file in the priority list.
     * Writes the config content to the users .config/swaync/config.json
     */
    public class Swaync : Page_Scroll {

        ConfigModel settings;

        public Swaync (string label, Hdy.Deck deck, IPC ipc) {
            base (label, deck, ipc);
        }

        public override Gtk.Widget set_child () {
            string config_path = Functions.get_swaync_config_path ();
            settings = read_file (config_path);
            write_file ();

            var comboX = new List_Combo_Enum ("Horizontal Position",
                                              settings.positionX,
                                              typeof (PositionX),
                                              (index) => {
                var profile = (PositionX) index;
                settings.positionX = profile;
                write_file ();
            });
            var comboY = new List_Combo_Enum ("Vertical Position",
                                              settings.positionY,
                                              typeof (PositionY),
                                              (index) => {
                var profile = (PositionY) index;
                settings.positionY = profile;
                write_file ();
            });

            var list_box = new Gtk.ListBox ();
            list_box.get_style_context ().add_class ("content");
            list_box.add (comboX);
            list_box.add (comboY);

            return Page.get_scroll_widget (list_box);
        }

        private ConfigModel read_file (string path) {
            try {
                Json.Parser parser = new Json.Parser ();
                parser.load_from_file (path);
                var node = parser.get_root ();
                ConfigModel model = Json.gobject_deserialize (typeof (ConfigModel), node) as ConfigModel;
                if (model == null) throw new Json.ParserError.UNKNOWN ("Json model is null!");
                return model;
            } catch (Error e) {
                stderr.printf (e.message + "\n");
                return new ConfigModel ();
            }
        }

        private void write_file () {
            try {
                string dir_path = Path.build_path (Path.DIR_SEPARATOR.to_string (),
                                                   GLib.Environment.get_user_config_dir (),
                                                   "swaync");
                string config_path = Path.build_path (Path.DIR_SEPARATOR.to_string (),
                                                      dir_path, "config.json");
                var dir = File.new_for_path (dir_path);
                if (!dir.query_exists ()) {
                    dir.make_directory ();
                }

                var file = File.new_for_path (config_path);
                if (!file.query_exists ()) {
                    file.create (GLib.FileCreateFlags.NONE);
                }

                string data = settings.json_serialized ();
                file.replace_contents (data.data,
                                       null,
                                       false,
                                       GLib.FileCreateFlags.REPLACE_DESTINATION,
                                       null);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
        }
    }
}
