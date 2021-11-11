namespace SwaySettings {
    [GtkTemplate (ui = "/org/erikreider/swaysettings/List_Item/List_Item.ui")]
    public class List_Item : Hdy.PreferencesRow {

        public static unowned int height_req = 70;

        [GtkChild]
        public unowned Gtk.Label label;
        [GtkChild]
        unowned Gtk.Box box;

        public List_Item (string title, Gtk.Widget widget, int height = height_req) {
            Object ();
            label.label = title;
            box.add (widget);
            widget.halign = Gtk.Align.FILL;
            widget.hexpand = true;
            this.height_request = height;
        }
    }

    public class List_Slider : List_Item {
        Gtk.Scale slider_widget;

        public delegate bool on_release_delegate (Gtk.Range range);

        public List_Slider (string title, double value,
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

    public class List_Switch : List_Item {
        Gtk.Switch switch_widget;

        public delegate bool on_state_set (bool state);

        public List_Switch (string title, bool value, on_state_set on_release) {
            var switch_widget = new Gtk.Switch ();
            switch_widget.set_active (value);
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

    public class List_Combo_Enum : Hdy.ComboRow {

        public delegate void selected_index (int index);

        public List_Combo_Enum (string title, int index, GLib.Type enum_type, selected_index callback) {
            Object ();

            this.set_title (title);
            this.height_request = List_Item.height_req;
            this.selectable = false;

            int selected_index = 0;
            int i = 0;
            this.set_for_enum (enum_type, (val) => {
                if (i == index) selected_index = i;
                i++;
                var nick = val.get_nick ();
                return nick.up (1) + nick.slice (1, nick.length);
            });
            this.set_selected_index (selected_index);
            this.notify["selected-index"].connect ((e) => callback (get_selected_index ()));
        }

        public void set_selected_from_enum (int val) {
            int selected_index = 0;
            for (int i = 0; i < this.get_model ().get_n_items (); i++) {
                if (val == i) selected_index = i;
            }
            this.set_selected_index (selected_index);
        }
    }

    public class List_Lazy_Image : Gtk.FlowBoxChild {

        public List_Lazy_Image (Wallpaper wp,
                                int height,
                                int width,
                                ref bool checked_folder_exists) {

            this.valign = Gtk.Align.CENTER;
            this.halign = Gtk.Align.CENTER;
            this.set_margin_start (8);
            this.set_margin_top (8);
            this.set_margin_end (8);
            this.set_margin_bottom (8);

            this.add (new ThumbnailImage (wp, height, width, ref checked_folder_exists));

            this.show_all ();
        }
    }
}
