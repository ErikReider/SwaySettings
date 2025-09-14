using Posix;

static Settings self_settings;
static Gtk.Application app;
static UserMgr user_mgr;
static GtkSessionLock.Instance instance;

private static bool should_daemonize = false;
private static bool should_lock = true;

class Main : Object {
    private static Posix.pid_t parent_pid = int.MIN;

    private static bool activated = false;

    private static unowned ListModel monitors;
    private static ListStore windows;

    private const OptionEntry[] ENTRIES = {
        {
            "daemonize",
            0,
            OptionFlags.NONE,
            OptionArg.NONE,
            ref should_daemonize,
            "Detach from the terminal once locked",
            null
        },
        {
            "debug-do-not-lock",
            0,
            OptionFlags.REVERSE,
            OptionArg.NONE,
            ref should_lock,
            "Doesn't start a session lock, opens in a regular window",
            null
        },
        { null }
    };

    private static void parse_args (owned string[] args) {
        try {
            OptionContext context = new OptionContext ();
            context.set_help_enabled (true);
            context.add_main_entries (ENTRIES, null);
            context.parse_strv (ref args);
        } catch (Error e) {
            error (e.message);
        }
    }

    public static int main (string[] args) {
        parse_args (args);

        if (should_daemonize) {
            daemonize ();
        }

        Gtk.init ();
        Adw.init ();

        user_mgr = new UserMgr ();

        // TODO: Do this instead:
        // https://discourse.gnome.org/t/having-trouble-getting-my-schema-to-work-in-gtk4-tutorial-example/8541/6
#if USE_GLOBAL_GSCHEMA
        // Use the global compiled gschema in /usr/share/glib-2.0/schemas/*
        self_settings = new Settings ("org.erikreider.swaysettings");
#else
        try {
            message ("Using local GSchema");
            // Meant for use in development.
            // Uses the compiled gschema in SwaySettings/data/
            // Should never be used in production!
            string settings_dir = Path.build_path (Path.DIR_SEPARATOR_S,
                                                   Environment.get_current_dir (),
                                                   "data");
            SettingsSchemaSource sss =
                new SettingsSchemaSource.from_directory (settings_dir, null,
                                                         false);
            SettingsSchema schema = sss.lookup ("org.erikreider.swaysettings",
                                                false);
            if (sss.lookup == null) {
                error ("ID not found.\n");
                return 0;
            }
            self_settings = new Settings.full (schema, null, null);
        } catch (Error e) {
            critical ("Application error: %s", e.message);
            return 1;
        }
#endif

        app = new Gtk.Application ("org.erikreider.swaysettings-locker",
                                   ApplicationFlags.FLAGS_NONE);
        app.activate.connect ((g_app) => {
            if (activated) {
                return;
            }
            activated = true;
            app.hold ();
            init.begin ();
        });

        try {
            app.register ();
            if (app.get_is_remote ()) {
                signal_daemon ();
                return 0;
            }
        } catch (Error e) {
            error (e.message);
        }
        // Load custom CSS
        Gtk.CssProvider css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource (
            "/org/erikreider/swaysettings/style.css");
        Gtk.StyleContext.add_provider_for_display (
            Gdk.Display.get_default (),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_USER);

        // Init resources
        var theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
        theme.add_resource_path ("/org/erikreider/swaysettings/icons");

        return app.run ();
    }

    private static async void init_lock () {
        if (should_lock) {
            GLib.assert (GtkSessionLock.is_supported ());
            instance = new GtkSessionLock.Instance ();
            assert_nonnull (instance);

            instance.locked.connect (locked);
            instance.unlocked.connect (unlocked);
            instance.failed.connect (failed);

            monitors.items_changed.connect (monitors_changed);
        }

        uint n_items = monitors.get_n_items ();
        int count = (int) n_items;
        for (uint i = 0; i < n_items; i++) {
            Gdk.Monitor monitor = (Gdk.Monitor) monitors.get_item (i);
            LockerWindow win = new LockerWindow (app, monitor);
            win.load_content.begin ((obj, res) => {
                win.load_content.end (res);
                if (AtomicInt.dec_and_test (ref count)) {
                    init_lock.callback ();
                }
            });
            windows.insert (i, win);
        }
        yield;
    }

    private static async void init () {
        windows = new ListStore (typeof (LockerWindow));

        Gdk.Display ?display = Gdk.Display.get_default ();
        assert_nonnull (display);

        monitors = display.get_monitors ();

        yield init_lock ();

        if (should_lock) {
            instance.lock ();
            for (uint i = 0; i < windows.get_n_items (); i++) {
                LockerWindow win = (LockerWindow) windows.get_item (i);
                instance.assign_window_to_monitor (win, win.monitor);
            }
        } else {
            // For debugging, doesn't start as a session-lock session
            locked ();
            for (uint i = 0; i < windows.get_n_items (); i++) {
                LockerWindow win = (LockerWindow) windows.get_item (i);
                win.close_request.connect (() => {
                    unlocked ();
                    app.quit ();
                    return false;
                });
                win.present ();
            }
        }
    }

    private static void monitors_changed (uint position,
                                          uint removed,
                                          uint added) {
        for (uint i = 0; i < removed; i++) {
            windows.remove (position + i);
        }

        for (uint i = 0; i < added; i++) {
            Gdk.Monitor monitor = (Gdk.Monitor) monitors.get_item (position +
                                                                   i);
            LockerWindow win = new LockerWindow (app, monitor);
            windows.insert (position + i, win);
            win.load_content.begin ((obj, res) => {
                win.load_content.end (res);
                instance.assign_window_to_monitor (win, monitor);
            });
        }
    }

    private static void locked () {
        print ("LOCKED!\n");

        // Kill the parent if daemonized
        signal_daemon ();
    }

    private static void unlocked () {
        app.release ();
        print ("UNLOCKED!\n");
    }

    private static void failed () {
        print ("FAILED!\n");
    }

    //
    // Daemonization logic
    //

    static int got_sig = 0;
    private static void sig_handler (int sig) {
        AtomicInt.set (ref got_sig, 1);
    }

    private static void daemonize () {
        parent_pid = getpid ();

        if (signal (Posix.Signal.USR2, sig_handler) == SIG_ERR) {
            error ("signal");
        }

        pid_t pid;
        switch (pid = fork ()) {
            case -1:
                error ("Fork PID error");
            case 0:
                break;
            default:
                sigset_t sig_set;
                sigemptyset (out sig_set);
                sigaddset (ref sig_set, Posix.Signal.USR2);
                sigprocmask (SIG_BLOCK, sig_set, null);
                int sig;
                if (sigwait (sig_set, out sig) != 0) {
                    exit (Posix.EXIT_FAILURE);
                }
                exit (Posix.EXIT_SUCCESS);
                break;
        }

        if (setsid () < 0) {
            error ("setsid error");
        }
        switch (pid = fork ()) {
            case -1:
                error ("Fork 2 PID error");
            case 0:
                break;
            default:
                exit (Posix.EXIT_SUCCESS);
                break;
        }
    }

    private static void signal_daemon () {
        if (parent_pid > 0) {
            kill (parent_pid, Posix.Signal.USR2);
        }
    }
}
