namespace SwaySettings {
    [GtkTemplate (ui = "/org/erikreider/swaysettings/Item/Item.ui")]
    public class Item : Gtk.FlowBoxChild {

        public SettingsItem settings_item;

        [GtkChild]
        public unowned Gtk.Image btn_image;
        [GtkChild]
        public unowned Gtk.Label btn_label;


        public Item (SettingsItem settings_item) {
            Object ();
            this.settings_item = settings_item;

            btn_label.set_text (settings_item.name);
            if (settings_item.image != "") {
                btn_image.set_from_icon_name (settings_item.image,
                                              Gtk.IconSize.DIALOG);
            }

            show_all ();
        }
    }
}
