[GtkTemplate (ui = "/org/erikreider/swaysettings/ui/LockerWindow.ui")]
public class LockerWindow : Gtk.ApplicationWindow {
    public unowned Gdk.Monitor monitor { get; construct set; }

    private const string PASSWORD_SHOW_ICON_NAME = "eye-open-negative-filled-symbolic";
    private const string PASSWORD_HIDE_ICON_NAME = "eye-not-looking-symbolic";

    [GtkChild]
    unowned Gtk.Picture picture;

    [GtkChild]
    unowned Adw.Avatar avatar;
    [GtkChild]
    unowned Gtk.Label real_name;

    [GtkChild]
    unowned Gtk.PasswordEntry entry;
    [GtkChild]
    unowned Gtk.Button button;

    private Cancellable load_cancellable = new Cancellable ();
    private bool loaded_user_data = false;
    private ulong changed_id = 0;

    public LockerWindow (Gtk.Application app,
                         Gdk.Monitor monitor) {
        Object (
            application: app,
            monitor: monitor,
            css_name: "lockerwindow");

        button.clicked.connect (password_check);

        entry.activate.connect (() => button.clicked ());

        picture.set_can_shrink (!should_lock);
    }

    public async void load_content () {
        load_cancellable.cancel ();
        load_cancellable.reset ();

        string path = Utils.get_wallpaper_gschema (self_settings);

        File file = File.new_for_path (path);
        if (!file.query_exists ()) {
            critical ("Wallpaper doesn't exist!");
            return;
        }

        Gdk.Texture ?texture = null;
        try {
            InputStream stream = file.read (load_cancellable);
            Gdk.Pixbuf pixbuf = new Gdk.Pixbuf.from_stream_at_scale (
                stream, monitor.geometry.width, monitor.geometry.height,
                true, load_cancellable);

            texture = Gdk.Texture.for_pixbuf (pixbuf);
        } catch (Error e) {
            critical (e.message);
        }

        picture.set_paintable (texture);

        // User Data
        changed_id = user_mgr.changed.connect (() => {
            if (loaded_user_data) {
                set_user_data ();
            }
        });
        if (user_mgr.current_user.is_loaded) {
            set_user_data ();
        } else {
            // Wait until the user manager has loaded
            ulong id = 0;
            id = user_mgr.changed.connect (() => {
                user_mgr.disconnect (id);
                load_content.callback ();
            });
            yield;

            set_user_data ();
            loaded_user_data = true;
        }
    }

    private void password_check () {
        string password = entry.get_text ();
        return_if_fail (password.length > 0);

        set_busy (true);

        check_password.begin (password, (obj, res) => {
            password_checked (check_password.end (res));
        });
    }

    private void password_checked (pam_status status) {
        switch (status) {
            case pam_status.PAM_STATUS_ERROR:
                critical ("PAM failed!");
                set_busy (false);
                break;
            case pam_status.PAM_STATUS_AUTH_FAILED:
                // TODO:
                critical ("PAM Auth failed:");
                set_busy (false);
                break;
            case pam_status.PAM_STATUS_AUTH_SUCESS:
                set_busy (false);
                if (should_lock) {
                    instance.unlock ();
                } else {
                    app.quit ();
                }
                break;
        }
    }

    private void set_busy (bool busy) {
        if (busy) {
            app.mark_busy ();
        } else {
            app.unmark_busy ();
        }

        entry.set_sensitive (!busy);
        button.set_sensitive (!busy);
        if (!busy) {
            entry.grab_focus ();
        }
    }

    private void set_user_data () {
        // Avatar
        avatar.set_text (user_mgr.current_user.real_name);
        if (user_mgr.current_user.icon_file != null
            && user_mgr.current_user.icon_file.length > 0) {
            Gtk.IconPaintable paintable = new Gtk.IconPaintable.for_file (
                File.new_for_path (user_mgr.current_user.icon_file),
                avatar.size, get_scale_factor ());
            avatar.set_custom_image (paintable);
        }

        // Name
        real_name.set_text (user_mgr.current_user.real_name);
    }
}
