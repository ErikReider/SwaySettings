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
        public unowned Gtk.Box root_box;
        [GtkChild]
        public unowned Hdy.HeaderBar header_bar;
        [GtkChild]
        public unowned Gtk.Button back_button;

        public string label;

        protected Page (string label, Hdy.Deck deck) {
            Object ();
            this.label = label;
            header_bar.set_title (this.label);
            back_button.clicked.connect (() => {
                deck.navigate (Hdy.NavigationDirection.BACK);
            });
            deck.child_switched.connect ((deck_child_index) => {
                if (deck_child_index == 0) on_back (deck);
            });
        }

        public virtual void on_back (Hdy.Deck deck) {
        }

        public Gtk.Widget get_scroll_widget (Gtk.Widget widget, int margin, bool shadow = false,
                                             int clamp_max = 600, int clamp_tight = 400) {
            var scrolled_window = new Gtk.ScrolledWindow (null, null);
            if (shadow) scrolled_window.shadow_type = Gtk.ShadowType.IN;
            scrolled_window.expand = true;
            var clamp = new Hdy.Clamp ();
            clamp.maximum_size = clamp_max;
            clamp.tightening_threshold = clamp_tight;
            clamp.orientation = Gtk.Orientation.HORIZONTAL;
            clamp.set_margin_top (margin);
            clamp.set_margin_start (margin);
            clamp.set_margin_bottom (margin);
            clamp.set_margin_end (margin);

            clamp.add (widget);
            scrolled_window.add (clamp);
            scrolled_window.show_all ();
            return scrolled_window;
        }
    }

    public abstract class Page_Scroll : Page {

        protected Page_Scroll (string label, Hdy.Deck deck) {
            base (label, deck);
            root_box.add (get_scroll_widget (set_child (), 8));
        }

        public abstract Gtk.Widget set_child ();
    }

    public abstract class Page_Tabbed : Page {

        public Gtk.Stack stack;

        protected Page_Tabbed (string label,
                               Hdy.Deck deck,
                               string no_tabs_text = "Nothing here...",
                               bool auto_hide_stack_bar = true,
                               int margin = 8) {
            base (label, deck);

            stack = new Gtk.Stack ();
            stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
            var stack_switcher = new Gtk.StackSwitcher ();
            stack_switcher.button_release_event.connect ((widget) => {
                header_bar.set_subtitle (stack.visible_child_name);
                return false;
            });
            stack_switcher.stack = stack;
            stack_switcher.set_halign (Gtk.Align.CENTER);
            stack_switcher.set_margin_top (8);
            stack_switcher.set_margin_start (8);
            stack_switcher.set_margin_bottom (8);
            stack_switcher.set_margin_end (8);

            stack.set_margin_top (margin);
            stack.set_margin_start (margin);
            stack.set_margin_bottom (margin);
            stack.set_margin_end (margin);

            root_box.add (stack_switcher);
            root_box.add (stack);
            root_box.show_all ();

            var all_tabs = tabs ();
            if (all_tabs.length < 1) {
                stack.add (new Gtk.Label (no_tabs_text));
                stack.show_all ();
            } else {
                if (all_tabs.length == 1) {
                    stack_switcher.visible = false;
                }
                foreach (var tab in all_tabs) {
                    stack.add_titled (tab, tab.tab_name, tab.tab_name);
                }
            }

            header_bar.set_subtitle (stack.visible_child_name);
        }

        public override void on_back (Hdy.Deck deck) {
            stack.set_visible_child (stack.get_children ().nth_data (0));
        }

        public abstract Page_Tab[] tabs ();
    }

    public abstract class Page_Tab : Gtk.Box {
        public string tab_name;
        public delegate Gtk.Widget DelegateWidget (Gtk.Widget widget);

        protected Page_Tab (string tab_name, DelegateWidget widget) {
            Object ();

            this.orientation = Gtk.Orientation.VERTICAL;
            this.spacing = 0;
            this.expand = true;

            this.tab_name = tab_name;
            this.add (widget (init ()));
            this.show_all ();
        }

        public abstract Gtk.Widget init ();
    }
}
