/* window.vala
 *
 * Copyright 2021 Erik Reider
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gee;

namespace SwaySettings {

    struct ConfigModel {
        PositionX positionX { get; private set; }
        PositionY positionY { get; private set; }

        Json.Node node;

        ConfigModel (Json.Node ? node) {
            try {
                if (node.get_node_type () != Json.NodeType.OBJECT) {
                    throw new Json.ParserError.PARSE (
                              @"JSON DOES NOT CONTAIN OBJECT!");
                }
                this.node = node;
                Json.Object obj = node.get_object ();

                positionX = PositionX.from_string (assert_node (obj, "positionX", { "left", "right" }).get_string ());
                positionY = PositionY.from_string (assert_node (obj, "positionY", { "top", "bottom" }).get_string ());
            } catch (Json.ParserError e) {
                stderr.printf (e.message + "\n");
                Process.exit (1);
            }
        }

        public void set_json_value (string key, string value) {
            var obj = node.get_object ();
            obj.get_member (key).set_string (value);
        }

        private Json.Node ? assert_node (Json.Object ? obj,
                                         string name,
                                         string[] correct_values) throws Json.ParserError.INVALID_DATA {
            Json.Node ? node = obj.get_member (name);
            if (node == null || node.get_node_type () != Json.NodeType.VALUE) {
                throw new Json.ParserError.INVALID_DATA (
                          @"JSON value $(name) wasn't defined!");
            }
            if (correct_values.length > 0 &&
                !(node.get_value ().get_string () in correct_values)) {
                throw new Json.ParserError.INVALID_DATA (
                          @"JSON value $(name) does not contain a correct value!");
            }
            return node;
        }
    }

    enum PositionX {
        RIGHT, LEFT;

        public static PositionX from_string (string str) {
            EnumClass enumc = (EnumClass) typeof (PositionX).class_ref ();
            unowned EnumValue ? eval = enumc.get_value_by_nick (str);
            return (PositionX) eval.value;
        }

        public string parse () {
            EnumClass enumc = (EnumClass) typeof (PositionX).class_ref ();
            return enumc.get_value_by_name (this.to_string ()).value_nick;
        }
    }

    enum PositionY {
        TOP, BOTTOM;

        public static PositionY from_string (string str) {
            EnumClass enumc = (EnumClass) typeof (PositionY).class_ref ();
            unowned EnumValue ? eval = enumc.get_value_by_nick (str);
            return (PositionY) eval.value;
        }

        public string parse () {
            EnumClass enumc = (EnumClass) typeof (PositionY).class_ref ();
            return enumc.get_value_by_name (this.to_string ()).value_nick;
        }
    }

    public class Swaync : Page_Scroll {

        ConfigModel settings;
        string config_path = "";

        public Swaync (string label, Hdy.Deck deck, IPC ipc) {
            base (label, deck, ipc);
        }

        public override Gtk.Widget set_child () {
            bool is_valid;
            config_path = get_config_path (out is_valid);
            if (!is_valid) {
                var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                box.add (new Gtk.Label (config_path));
                return box;
            }
            settings = read_file (config_path);

            var comboX = new List_Combo_Enum ("Horizontal Position",
                                              settings._positionX,
                                              typeof (PositionX),
                                              (index) => {
                var profile = (PositionX) index;
                settings._positionX = profile;
                settings.set_json_value ("positionX", profile.parse ());
                write_file ();
            });
            var comboY = new List_Combo_Enum ("Vertical Position",
                                              settings._positionY,
                                              typeof (PositionY),
                                              (index) => {
                var profile = (PositionY) index;
                settings._positionY = profile;
                settings.set_json_value ("positionY", profile.parse ());
                write_file ();
            });

            var list_box = new Gtk.ListBox ();
            list_box.get_style_context ().add_class ("content");
            list_box.add (comboX);
            list_box.add (comboY);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            box.add (new Gtk.Label (@"Configures $(config_path)"));
            box.add (list_box);
            return Page.get_scroll_widget (box);
        }

        private ConfigModel read_file (string path) {
            try {
                Json.Parser parser = new Json.Parser ();
                parser.load_from_file (path);
                var node = parser.get_root ();
                return ConfigModel (node);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
                return ConfigModel (null);
            }
        }

        private void write_file () {
            try {
                string data = Json.to_string (settings.node, true);
                var file = File.new_for_path (config_path);
                file.replace_contents (data.data,
                                       null,
                                       false,
                                       GLib.FileCreateFlags.REPLACE_DESTINATION,
                                       null);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        private string get_config_path (out bool is_valid) {
            try {
                var dir = File.new_for_path (Functions.get_swaync_config_path ());
                if (!dir.query_exists ()) {
                    dir.make_directory ();
                }

                var file = File.new_for_path (config_path);
                if (!file.query_exists ()) {
                    file.create (GLib.FileCreateFlags.NONE);
                }
                is_valid = true;
                return config_path;
            } catch (Error e) {
                stderr.printf (e.message + "\n");
                is_valid = false;
                return e.message;
            }
        }
    }
}
