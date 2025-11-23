namespace SwaySettings {
    public class PowerInfoBanner : Gtk.ListBoxRow {
        private Gtk.Image icon = new Gtk.Image ();
        private Gtk.Label label = new Gtk.Label (null);

        construct {
            set_selectable (false);
            set_activatable (false);
            set_visible (false);

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            set_child (box);

            box.append (icon);
            box.append (label);

            label.set_xalign (0);
            label.set_wrap (true);
            label.set_wrap_mode (Pango.WrapMode.WORD_CHAR);

            add_css_class ("power-info-banner");
        }

        public void set_icon (string ?icon_name) {
            icon.set_from_icon_name (icon_name);
            icon.set_visible (icon_name != null && icon_name != "");
        }

        public void set_text (string ?text) {
            set_visible (text != null && text != "");
            label.set_text (text);
        }
    }
}
