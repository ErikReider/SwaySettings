namespace SwaySettings {
    public interface ISidebarListItem : Object {
        public abstract SettingsItem settings_item { get; set; }

        public const int MARGIN = 8;
    }

    public class SidebarListItem : Gtk.ListBoxRow, ISidebarListItem {
        public SwaySettings.SettingsItem settings_item { get; set; }

        public Gtk.Image btn_image = new Gtk.Image.from_icon_name ("image-missing");
        public Gtk.Label btn_label = new Gtk.Label ("Item");

        public SidebarListItem (SettingsItem settings_item) {
            this.settings_item = settings_item;

            Gtk.Box box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            box.margin_top = MARGIN;
            box.margin_bottom = MARGIN;
            box.margin_start = MARGIN;
            box.margin_end = MARGIN;
            this.set_child (box);

            btn_image.set_pixel_size (32);
            if (settings_item.image != "") {
                btn_image.set_from_icon_name (settings_item.image);
            }
            box.append (btn_image);

            btn_label.set_text (settings_item.name);
            box.append (btn_label);
        }
    }

    [GtkTemplate (ui = "/org/erikreider/swaysettings/ui/UserListItem.ui")]
    public class UserListItem : Gtk.ListBoxRow, ISidebarListItem {
        public SwaySettings.SettingsItem settings_item { get; set; }

        [GtkChild]
        public unowned Gtk.Box box;
        [GtkChild]
        public unowned Adw.Avatar avatar;
        [GtkChild]
        public unowned Gtk.Label name_label;
        [GtkChild]
        public unowned Gtk.Label username_label;

        public UserListItem (SettingsItem settings_item) {
            this.settings_item = settings_item;

            margin_start = MARGIN;
            margin_end = MARGIN;
            box.margin_top = MARGIN;
            box.margin_bottom = MARGIN;
            box.margin_start = MARGIN;
            box.margin_end = MARGIN;

            userMgr.changed.connect (set_user_data);
            if (userMgr.current_user.is_loaded) {
                set_user_data ();
            }
        }

        private void set_user_data () {
            // Avatar
            avatar.set_text (userMgr.current_user.real_name);
            if (userMgr.current_user.icon_file != null
                && userMgr.current_user.icon_file.length > 0) {
                Gtk.IconPaintable paintable = new Gtk.IconPaintable.for_file (
                    File.new_for_path (userMgr.current_user.icon_file),
                    avatar.size,
                    1);
                avatar.set_custom_image (paintable);
            }

            // Title
            name_label.set_text (userMgr.current_user.real_name);

            // Subtitle
            string sub_string = userMgr.current_user.email;
            if (sub_string == null || sub_string.length == 0) {
                sub_string = userMgr.current_user.user_name;
            }
            username_label.set_text (sub_string);
        }
    }
}
