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
            base (label, deck);
        }

        public override TabItem[] tabs () {
            TabItem[] tabs = {
                new TabItem ("Background", new Background_Widget ((widget) => get_scroll_widget (widget, 0, int.MAX, int.MAX))),
                new TabItem ("Themes", new Themes_Widget ((widget) => get_scroll_widget (widget, 0))),
            };
            return tabs;
        }
    }
}
