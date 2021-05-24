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
    public class Keybind_Variable_Action : Hdy.ActionRow {
        public Keybind_Variable_Action (Keybinding_Variable variable) {
            Object ();
            this.activatable = false;
            this.selectable = false;
            this.title = variable.name;

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);

            var label = new Gtk.Label (variable.key_name);
            label.ellipsize = Pango.EllipsizeMode.END;
            label.margin_start = 12;

            var next_icon = new Gtk.Image.from_icon_name (
                "go-next-symbolic", Gtk.IconSize.BUTTON);

            box.add (label);
            box.add (next_icon);

            this.add (box);
        }
    }
}