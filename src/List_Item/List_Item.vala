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
    [GtkTemplate (ui = "/org/erikreider/swaysettings/List_Item/List_Item.ui")]
    public class List_Item : Gtk.ListBoxRow {

        [GtkChild]
        public unowned Gtk.Label label;
        [GtkChild]
        unowned Gtk.Box box;

        public List_Item (string title, Gtk.Widget widget) {
            Object ();
            label.label = title;
            box.add (widget);
            widget.halign = Gtk.Align.FILL;
            widget.hexpand = true;
        }
    }

    public class List_Slider : List_Item {
        Gtk.Scale slider_widget;

        public delegate bool on_release_delegate (Gdk.EventButton event_button, Gtk.Scale slider);

        public List_Slider (string title, double min, double max, double step, on_release_delegate on_release) {
            var slider_widget = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, min, max, step);
            slider_widget.button_release_event.connect ((event) => on_release (event, slider_widget));
            base (title, slider_widget);

            this.slider_widget = slider_widget;
        }

        public void set_value (float value) {
            slider_widget.set_value (value);
        }
    }

    public class List_Switch : List_Item {
        Gtk.Switch switch_widget;

        public delegate bool on_state_set (bool state);

        public List_Switch (string title, on_state_set on_release) {
            var switch_widget = new Gtk.Switch();
            switch_widget.state_set.connect ((value) => on_release (value));
            base (title, switch_widget);
            switch_widget.halign = Gtk.Align.END;
            switch_widget.valign = Gtk.Align.CENTER;

            this.switch_widget = switch_widget;
        }

        public void set_active (bool value) {
            switch_widget.set_active (value);
        }
    }
}
