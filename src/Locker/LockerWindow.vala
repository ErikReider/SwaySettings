public class LockData : Object {
    public Gtk.PasswordEntryBuffer pwd_buffer { get; construct set; }
    public bool show_password { get; private set; }

    public List<string> messages;
    public List<string> errors;

    public signal void pwd_checked ();

    construct {
        pwd_buffer = new Gtk.PasswordEntryBuffer ();
        show_password = false;
        messages = new List<string> ();
        errors = new List<string> ();
    }

    public void toggle_show_password () {
        show_password = !show_password;
    }

    public void clear_messages () {
        // Remove all of the previous messages
        while (!messages.is_empty ()) {
            unowned List<string> link = messages.nth (0);
            messages.delete_link (link);
        }
        warn_if_fail (messages.is_empty ());

        while (!errors.is_empty ()) {
            unowned List<string> link = errors.nth (0);
            errors.delete_link (link);
        }
        warn_if_fail (errors.is_empty ());
    }
}

[GtkTemplate (ui = "/org/erikreider/swaysettings/ui/LockerWindow.ui")]
public class LockerWindow : Gtk.ApplicationWindow {
    public unowned Gdk.Monitor monitor { get; construct set; }

    private static LockData lock_data = new LockData ();
    private const string PASSWORD_SHOW_ICON_NAME = "eye-open-negative-filled-symbolic";
    private const string PASSWORD_HIDE_ICON_NAME = "eye-not-looking-symbolic";

    [GtkChild]
    unowned Gtk.Picture picture;

    [GtkChild]
    unowned Gtk.Revealer revealer;

    [GtkChild]
    unowned Gtk.Label time_label;
    [GtkChild]
    unowned Gtk.Label date_label;

    [GtkChild]
    unowned Adw.Avatar avatar;
    [GtkChild]
    unowned Gtk.Label real_name;

    [GtkChild]
    unowned Gtk.Entry entry;
    [GtkChild]
    unowned Gtk.Button button;

    [GtkChild]
    unowned Gtk.Revealer status_revealer;
    [GtkChild]
    unowned Gtk.Box status;

    private Cancellable load_cancellable = new Cancellable ();
    private bool loaded_user_data = false;
    private ulong changed_id = 0;

    public LockerWindow (Gtk.Application app,
                         Gdk.Monitor monitor) {
        Object (
            application: app,
            monitor: monitor,
            css_name: "lockerwindow");

        notify["is-active"].connect (() => {
            bool active = !should_lock ? true : is_active;
            revealer.set_reveal_child (active);
            entry.grab_focus_without_selecting ();
            entry.set_position (-1);
            if (active) {
                add_css_class ("focused");
            } else {
                remove_css_class ("focused");
            }
        });

        entry.set_buffer (lock_data.pwd_buffer);
        set_password_visibility ();
        entry.icon_release.connect ((pos) => {
            if (pos == Gtk.EntryIconPosition.SECONDARY) {
                lock_data.toggle_show_password ();
            }
        });
        lock_data.notify["show-password"].connect (set_password_visibility);
        entry.activate.connect (() => button.clicked ());

        button.clicked.connect (password_check);

        set_date_time ();
        time_object.update.connect (set_date_time);

        lock_data.pwd_checked.connect (set_status);
        set_status ();

        map.connect (() => {
            add_css_class ("locked");
        });
    }

    private Adw.Banner get_message_banner (string message, bool error) {
        var banner = new Adw.Banner (message);
        banner.set_revealed (true);
        if (error) {
            banner.add_css_class ("error");
        }
        return banner;
    }

    private void set_status () {
        // Remove the previous status widgets
        unowned Gtk.Widget widget = null;
        while ((widget = status.get_first_child ()) != null) {
            status.remove (widget);
        }
        status_revealer.set_reveal_child (false);

        if (!lock_data.errors.is_empty ()) {
            foreach (var err in lock_data.errors) {
                status.append (get_message_banner (err, true));
            }
            status_revealer.set_reveal_child (true);
        }

        if (!lock_data.messages.is_empty ()) {
            foreach (var msg in lock_data.messages) {
                status.append (get_message_banner (msg, false));
            }
            status_revealer.set_reveal_child (true);
        }
    }

    private void set_password_visibility () {
        entry.set_visibility (lock_data.show_password);
        entry.secondary_icon_name = lock_data.show_password
            ? PASSWORD_HIDE_ICON_NAME : PASSWORD_SHOW_ICON_NAME;
    }

    private void set_date_time () {
        time_label.set_text (time_object.get_time ());
        date_label.set_text (time_object.get_date ());
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

        try {
            Gly.Image image = yield new Gly.Loader (file).load_async (null);
            Gly.FrameRequest frame_request = new Gly.FrameRequest ();
            frame_request.set_scale (monitor.geometry.width, monitor.geometry.height);
            Gly.Frame frame = yield image.get_specific_frame_async (frame_request, null);

            // Scale the texture
            float new_width, new_height;
            Gdk.Paintable ?paintable
                = SwaySettings.Functions.gdk_texture_scale (
                        GlyGtk4.frame_get_texture (frame),
                        frame.get_width (), frame.get_height (),
                        monitor.geometry.width, monitor.geometry.height,
                        Gsk.ScalingFilter.NEAREST,
                        out new_width, out new_height);
            picture.set_paintable (paintable);
        } catch (Error e) {
            critical ("Getting background error: %s", e.message);
            picture.set_paintable (null);
        }

        Utils.ScaleModes scale = Utils.get_scale_mode_gschema (self_settings);
        picture.set_content_fit (scale.to_content_fit ());

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
        if (lock_data.pwd_buffer.length <= 0) {
            return;
        }

        set_busy (true);

        lock_data.clear_messages ();
        status_revealer.set_reveal_child (false);

        check_password.begin (lock_data, (obj, res) => {
            password_checked (check_password.end (res));
        });
    }

    private void password_checked (pam_status status) {
        set_busy (false);

        switch (status) {
            case pam_status.PAM_STATUS_ERROR:
                // TODO:
                critical ("PAM failed!");
                break;
            case pam_status.PAM_STATUS_AUTH_FAILED:
                critical ("PAM Auth failed:");
                lock_data.messages.append ("Login Failed");
                break;
            case pam_status.PAM_STATUS_AUTH_SUCESS:
                if (should_lock) {
                    instance.unlock ();
                } else {
                    app.quit ();
                }
                return;
        }

        entry.grab_focus ();

        lock_data.pwd_checked ();
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
