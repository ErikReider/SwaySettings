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
    public class Trackpad_Widget : Input_Tab {

        public Trackpad_Widget (string tab_name, Input_Device touchpad) {
            base (tab_name, Input_Types.touchpad, touchpad);
        }

        public override ArrayList<Gtk.Widget> get_options () {
            return new ArrayList<Gtk.Widget>.wrap ({
                get_scroll_factor (),
                get_natural_scroll (),
                get_accel_profile (),
                get_pointer_accel (),
            });
        }
    }
}
