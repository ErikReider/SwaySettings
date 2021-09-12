// https://sssd.io/design-pages/accounts_service.html
namespace SwaySettings {
    public class Users : Page_Scroll {
        private unowned Act.UserManager user_manager = Act.UserManager.get_default ();
        private unowned Act.User current_user;

        private Users_Content content;

        private Gtk.Button save_button;

        public Users (string label, Hdy.Deck deck, IPC ipc) {
            base (label, deck, ipc);
        }

        public override Gtk.Widget set_child () {
            string username = GLib.Environment.get_user_name ();
            content = new Users_Content ();

            // Save button
            save_button = new Gtk.Button.with_label ("Save");
            save_button.get_style_context ().add_class ("suggested-action");
            this.button_box.add (save_button);
            this.button_box.show_all ();

            // Avatar EventBox
            content.avatar_event_box.button_press_event.connect (() => {

                return true;
            });

            if (current_user == null || !current_user.is_loaded) {
                current_user = user_manager.get_user (username);
                current_user.notify["is-loaded"].connect (set_user_data);
                current_user.changed.connect (() => this.on_refresh ());
            } else {
                set_user_data ();
            }

            return Page.get_scroll_widget (content);
        }

        void set_user_data () {
            // Avatar
            content.avatar.set_text (current_user.real_name);
            if (current_user.icon_file != null
                && current_user.icon_file.length > 0) {
                File icon_file = File.new_for_path (current_user.icon_file);
                content.avatar.set_loadable_icon (new FileIcon (icon_file));
            }

            // Title
            content.title.set_text (current_user.real_name);

            // Subtitle
            string sub_string = current_user.email;
            if (sub_string == null || sub_string.length == 0) {
                sub_string = current_user.user_name;
            }
            content.subtitle.set_text (sub_string);

            // Subtitle2
            string user_type = current_user.system_account ?
                               "Root Account" : "Regular Account";
            content.subtitle2.set_text (user_type);
        }
    }

    [GtkTemplate (ui = "/org/erikreider/swaysettings/Pages/Users/Users.ui")]
    private class Users_Content : Gtk.Box {
        [GtkChild]
        public unowned Gtk.EventBox avatar_event_box;
        [GtkChild]
        public unowned Hdy.Avatar avatar;

        [GtkChild]
        public unowned Gtk.Label title;
        [GtkChild]
        public unowned Gtk.Label subtitle;
        [GtkChild]
        public unowned Gtk.Label subtitle2;
    }
}
