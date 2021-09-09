// https://sssd.io/design-pages/accounts_service.html
namespace SwaySettings {
    [DBus (name = "org.freedesktop.Accounts")]
    interface Properties : GLib.Object {
        public abstract string FindUserByName (string name) throws Error;
    }

    [DBus (name = "org.freedesktop.Accounts.User")]
    interface Account : GLib.Object {
        public abstract string UserName { owned get; }
        public abstract string RealName { owned get; }
        public abstract string IconFile { owned get; }

        public signal void Changed ();

        public abstract void SetRealName (string full_name) throws Error;
    }

    public class Users : Page_Scroll {
        private Account account = null;

        private Gtk.Button button;

        public Users (string label, Hdy.Deck deck, IPC ipc) {
            base (label, deck, ipc);
        }

        public override Gtk.Widget set_child () {
            dbus_connect ();

            account.Changed.connect (() => this.refresh ());

            add_save_button ();

            var grid = new Gtk.Grid ();
            grid.column_homogeneous = true;
            grid.column_spacing = 24;

            grid.add (get_avatar ());
            grid.add (get_real_name ());

            return Page.get_scroll_widget (grid);
        }

        void add_save_button () {
            button = new Gtk.Button.with_label ("Save");
            button.get_style_context ().add_class ("suggested-action");
            this.button_box.add (button);
            this.button_box.show_all ();
        }

        Hdy.Avatar get_avatar () {
            Hdy.Avatar avatar = new Hdy.Avatar (96, account.RealName, true);
            if (account.IconFile != null && account.IconFile.length > 0) {
                File icon_file = File.new_for_path (account.IconFile);
                avatar.set_loadable_icon (new FileIcon (icon_file));
            }
            avatar.halign = Gtk.Align.END;
            return avatar;
        }

        Gtk.Box get_real_name () {
            Gtk.Box box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            Gtk.Label label = new Gtk.Label (account.UserName);
            label.halign = Gtk.Align.START;
            label.margin_start = 8;
            label.margin_top = 4;
            label.margin_bottom = 4;
            box.add (label);

            Gtk.Entry entry = new Gtk.Entry ();
            entry.text = account.RealName ?? "";
            box.add (entry);

            box.halign = Gtk.Align.START;
            box.valign = Gtk.Align.CENTER;
            return box;
        }

        void dbus_connect () {
            try {
                Properties properties = Bus.get_proxy_sync (
                    BusType.SYSTEM,
                    "org.freedesktop.Accounts",
                    "/org/freedesktop/Accounts");
                account = Bus.get_proxy_sync (
                    BusType.SYSTEM,
                    "org.freedesktop.Accounts",
                    properties.FindUserByName (
                        GLib.Environment.get_user_name ()));
            } catch (Error e) {
                stderr.printf (@"$(e.code): $(e.message)\n");
                stderr.printf ("Could not connect to Account service\n");
            }
        }
    }
}
