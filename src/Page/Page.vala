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

namespace SwaySettings {
    [GtkTemplate (ui = "/org/erikreider/swaysettings/Page/Page.ui")]
    public abstract class Page : Gtk.Bin {

        [GtkChild]
        public unowned Gtk.Box box;
        [GtkChild]
        public unowned Hdy.HeaderBar header_bar;
        [GtkChild]
        public unowned Gtk.Button back_button;

        public string label;

        protected Page (string label, Hdy.Deck deck) {
            Object ();
            this.label = label;
            header_bar.set_title (this.label);
            back_button.clicked.connect (() => deck.navigate (Hdy.NavigationDirection.BACK));
        }

        public Gtk.Widget get_scroll_widget (Gtk.Widget widget, int clamp_max = 600, int clamp_tight = 400) {
            var scrolled_window = new Gtk.ScrolledWindow (null, null);
            scrolled_window.expand = true;
            var clamp = new Hdy.Clamp ();
            clamp.maximum_size = clamp_max;
            clamp.tightening_threshold = clamp_tight;
            clamp.orientation = Gtk.Orientation.HORIZONTAL;
            clamp.set_margin_top (8);
            clamp.set_margin_start (8);
            clamp.set_margin_bottom (8);
            clamp.set_margin_end (8);
            var viewport = new Gtk.Viewport (null, null);

            viewport.add (widget);
            clamp.add (viewport);
            scrolled_window.add (clamp);
            scrolled_window.show_all ();
            return scrolled_window;
        }
    }

    public abstract class Page_Scroll : Page {

        protected Page_Scroll (string label, Hdy.Deck deck) {
            base (label, deck);
            box.add (get_scroll_widget (set_child ()));
        }

        public abstract Gtk.Widget set_child ();
    }

    public abstract class Page_Tabbed : Page {

        public class TabItem {
            public string name;
            public Gtk.Widget widget;

            public TabItem (string name, Gtk.Widget widget) {
                this.name = name;
                this.widget = widget;
            }
        }

        protected Page_Tabbed (string label, Hdy.Deck deck) {
            base (label, deck);

            var stack = new Gtk.Stack ();
            stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
            var stackSwitcher = new Gtk.StackSwitcher ();
            stackSwitcher.stack = stack;
            stackSwitcher.set_halign (Gtk.Align.CENTER);
            stackSwitcher.set_margin_top (8);
            stackSwitcher.set_margin_start (8);
            stackSwitcher.set_margin_bottom (8);
            stackSwitcher.set_margin_end (8);

            box.add (stackSwitcher);
            box.add (stack);
            box.show_all ();

            foreach (var tab in tabs ()) {
                stack.add_titled (tab.widget, tab.name, tab.name);
            }
        }

        public abstract TabItem[] tabs ();
    }
}
