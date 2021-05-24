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
    public class Keybindings_Page : Page_Scroll {

        public Keybindings_Page (string label, Hdy.Deck deck) {
            base (label, deck);
        }

        public override Gtk.Widget set_child () {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            box.add(get_variables_section());
            box.add(get_bindings_section());
            return box;
        }

        Gtk.Box get_variables_section () {
            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            box.add (new Gtk.Label ("Variables"));
            box.add (get_add_var_button ());
            box.add (get_variables_list ());
            return box;
        }

        Gtk.Button get_add_var_button () {
            var button = new Gtk.Button.with_label ("Add Variable");
            return button;
        }

        Gtk.ListBox get_variables_list () {
            var list_box = new Gtk.ListBox ();
            list_box.get_style_context ().add_class ("content");

            var variables = Functions.get_keybinding_variables ();
            foreach (var variable in variables) {
                list_box.add (new Keybind_Variable_Action (variable));
            }

            return list_box;
        }

        Gtk.Box get_bindings_section () {
            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            box.add (new Gtk.Label ("Shortcuts"));
            box.add (get_add_binding_button ());
            box.add (get_bindings_list ());
            return box;
        }

        Gtk.Button get_add_binding_button () {
            var button = new Gtk.Button.with_label ("Add Keybinding");
            return button;
        }

        Gtk.ListBox get_bindings_list () {
            var list_box = new Gtk.ListBox ();
            list_box.get_style_context ().add_class ("content");

            var bindings = Functions.get_keybindings ();
            foreach (var binding in bindings) {
                list_box.add (new Keybind_Action (binding));
            }

            return list_box;
        }
    }

    public class Keybinding {
        public string name;
        public string action;
        public ArrayList<string> triggers = new ArrayList<string>();

        public Keybinding (string name, Json.Object ? obj) {
            this.name = name;
            this.action = obj.get_string_member ("action");
            obj.get_array_member ("triggers").foreach_element (
                (array, i, node) => triggers.add (node.get_string ())
            );
        }
    }

    public class Keybinding_Variable {
        public string name;
        public string key_name;

        public Keybinding_Variable(string name, string key_name){
            this.name = name;
            this.key_name = key_name;
        }
    }
}
