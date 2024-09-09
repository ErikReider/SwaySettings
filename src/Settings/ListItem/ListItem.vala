namespace SwaySettings {
    public class ListItem : Adw.ActionRow {

        public ListItem (string title, Gtk.Widget widget) {
            add_prefix (new Gtk.Label (title));
            add_suffix (widget);
            widget.halign = Gtk.Align.FILL;
            widget.hexpand = true;
        }
    }

    public class ListSlider : ListItem {
        Gtk.Scale slider_widget;

        public delegate bool on_release_delegate (Gtk.Range range);

        public ListSlider (string title, double value,
                            double min,
                            double max,
                            double step,
                            on_release_delegate on_release) {
            var slider_widget = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, min, max, step);
            slider_widget.set_value (value);
            base (title, slider_widget);

            this.slider_widget = slider_widget;
            slider_widget.value_changed.connect ((event) => on_release (event));
        }

        public void add_mark (double value, Gtk.PositionType position) {
            slider_widget.add_mark (value, position, null);
        }

        public void set_value (float value) {
            slider_widget.set_value (value);
        }
    }

    public class ListSwitch : ListItem {
        Gtk.Switch switch_widget;

        public delegate bool on_state_set (bool state);

        public ListSwitch (string title, bool value, on_state_set on_release) {
            var switch_widget = new Gtk.Switch ();
            switch_widget.set_active (value);
            switch_widget.state_set.connect ((value) => on_release (value));
            base (title, switch_widget);
            switch_widget.halign = Gtk.Align.END;
            switch_widget.valign = Gtk.Align.CENTER;

            this.switch_widget = switch_widget;

            this.activatable_widget = this.switch_widget;
        }

        public void set_active (bool value) {
            switch_widget.set_active (value);
        }
    }

    public class ListComboEnum : Adw.ComboRow {

        public delegate void selected_index (int index);

        public ListComboEnum (string title, int index, GLib.Type enum_type, selected_index callback) {
            Object ();

            this.set_title (title);
            // this.height_request = List_Item.height_req;
            this.selectable = false;

            int selected_index = 0;
            int i = 0;
            // this.set_for_enum (enum_type, (val) => {
            //     if (i == index) selected_index = i;
            //     i++;
            //     var nick = val.get_nick ();
            //     return nick.up (1) + nick.slice (1, nick.length);
            // });
            // this.set_selected_index (selected_index);
            // this.notify["selected-index"].connect ((e) => callback (get_selected_index ()));
        }

        public void set_selected_from_enum (int val) {
            int selected_index = 0;
            for (int i = 0; i < this.get_model ().get_n_items (); i++) {
                if (val == i) selected_index = i;
            }
            // this.set_selected_index (selected_index);
        }
    }
}
