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
    public class Trackpad_Widget : Page_Tab {

        public delegate Gtk.Widget DelegateWidget (Gtk.Widget widget);

        public Trackpad_Widget (string tab_name, DelegateWidget widget, Input_Device touchpad) {
            base(tab_name, widget);
        }

        public override Gtk.Widget init () {
            var widget = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            widget.add (create_mouse_settings());
            widget.show_all ();

            return widget;
        }

        Gtk.Widget create_mouse_settings () {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            var label = new Gtk.Label ("Mouse");

            var list_box = new Gtk.ListBox ();
            list_box.get_style_context ().add_class ("content");

            // pointer_accel
            var sens_action = new Hdy.ActionRow ();
            sens_action.selectable = false;
            sens_action.set_title ("Mouse sensitivity");
            var speed_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, -1.0, 1.0, 0.1);
            speed_scale.expand = true;
            speed_scale.hexpand = true;
            sens_action.add (speed_scale);
            list_box.add (sens_action);

            // scroll_factor
            var scrollfac_action = new Hdy.ActionRow ();
            scrollfac_action.selectable = false;
            scrollfac_action.set_title ("Scroll Factor");
            var scrollfac_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 10, 0.1);
            scrollfac_scale.expand = true;
            scrollfac_scale.hexpand = true;
            scrollfac_action.add (scrollfac_scale);
            list_box.add (scrollfac_action);

            // natural_scroll
            var natural_scroll_action = new Hdy.ActionRow ();
            natural_scroll_action.selectable = false;
            natural_scroll_action.set_title ("Natural Scrolling");
            var natural_scroll_switch = new Gtk.Switch ();
            natural_scroll_switch.valign = Gtk.Align.CENTER;
            natural_scroll_action.add (natural_scroll_switch);
            list_box.add (natural_scroll_action);

            box.add (label);
            box.add (list_box);
            return box;
        }
    }
}
