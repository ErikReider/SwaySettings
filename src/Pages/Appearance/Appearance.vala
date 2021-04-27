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
    public class Appearance_Page : Page_Tabbed {

        public Appearance_Page (string label, Hdy.Deck deck) {
            base (label, deck, "", false, 0);
        }

        public override Page_Tab[] tabs () {
            Page_Tab[] tabs = {
                       new Background_Widget ("Background", (widget) => get_scroll_widget (widget, 0, int.MAX, int.MAX)),
                       new Themes_Widget ("Themes", (widget) => get_scroll_widget (widget, 0)),
            };
            return tabs;
        }
    }
}
