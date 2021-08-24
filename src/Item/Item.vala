namespace SwaySettings {
    [GtkTemplate (ui = "/org/erikreider/swaysettings/Item/Item.ui")]
    public class Item : Gtk.FlowBoxChild {

        public SettingsItem settings_item;

        [GtkChild]
        public unowned Gtk.Image btn_image;
        [GtkChild]
        public unowned Gtk.Label btn_label;


        public Item (string text, string icon_name, SettingsItem settings_item) {
            Object ();
            this.get_style_context().add_class("main-flex-item");
            this.settings_item = settings_item;

            btn_label.set_text (text);
            if (icon_name != "") btn_image.set_from_icon_name (icon_name, Gtk.IconSize.DIALOG);

            show_all ();
        }
    }
}
