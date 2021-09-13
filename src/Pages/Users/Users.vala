// https://sssd.io/design-pages/accounts_service.html
namespace SwaySettings {
    public class Users : Page_Scroll {
        private unowned Act.UserManager user_manager = Act.UserManager.get_default ();
        private unowned Act.User current_user;

        private Users_Content content;

        public Users (string label, Hdy.Deck deck, IPC ipc) {
            base (label, deck, ipc);
        }

        public override Gtk.Widget set_child () {
            string username = GLib.Environment.get_user_name ();
            content = new Users_Content ();

            // Avatar EventBox
            content.avatar_event_box.button_press_event.connect (() => {

                return true;
            });

            // Title Entry on press ESC
            content.title_entry.key_press_event.connect ((_, eventKey) => {
                if (eventKey.keyval == Gdk.Key.Escape) {
                    string text = current_user.real_name;
                    content.title.set_text (text);
                    content.title_entry.set_text (text);
                    content.title_button.set_active (false);
                }
                return false;
            });
            // Title Entry on press Enter
            content.title_entry.activate.connect (() => {
                string text = content.title_entry.text;
                content.title.set_text (text);
                content.title_entry.set_text (text);
                current_user.set_real_name (text);
                content.title_button.set_active (false);
            });
            // Title Togglebutton on toggle
            content.title_button.toggled.connect (() => {
                bool toggle_value = content.title_button.get_active ();
                string name = toggle_value ? "entry" : "title";
                content.title_stack.set_visible_child_name (name);
                if (toggle_value) {
                    content.title_entry.set_text (current_user.real_name);
                    content.title_entry.grab_focus_without_selecting ();
                    content.title_entry.set_position (-1);
                }
            });

            if (current_user == null || !current_user.is_loaded) {
                current_user = user_manager.get_user (username);
                current_user.notify["is-loaded"].connect (set_user_data);
                current_user.changed.connect (set_user_data);
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
            content.title_entry.set_text (current_user.real_name);

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
        public unowned Gtk.Stack title_stack;
        [GtkChild]
        public unowned Gtk.ToggleButton title_button;
        [GtkChild]
        public unowned Gtk.Label title;
        [GtkChild]
        public unowned Gtk.Entry title_entry;

        [GtkChild]
        public unowned Gtk.Label subtitle;
        [GtkChild]
        public unowned Gtk.Label subtitle2;
    }
}
