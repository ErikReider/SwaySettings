namespace SwaySettings {
    public class PowerInfoBanner : Gtk.Box {
        private Gtk.Image icon = new Gtk.Image ();
        private Gtk.Label label = new Gtk.Label (null);

        construct {
            set_visible (false);

            append (icon);
            append (label);

            label.set_xalign (0);
            label.set_wrap (true);
            label.set_wrap_mode (Pango.WrapMode.WORD_CHAR);

            set_spacing (8);

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
