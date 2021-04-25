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
    public class General_Input_Widget : Page_Tab {

        public delegate Gtk.Widget DelegateWidget (Gtk.Widget widget);

        public General_Input_Widget (string tab_name, DelegateWidget widget) {
            base (tab_name, widget);
        }

        public override Gtk.Widget init () {
            var widget = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            widget.add (new Gtk.Label ("General"));
            widget.show_all ();

            return widget;
        }
    }
}
