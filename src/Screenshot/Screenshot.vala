static Settings self_settings;
static bool activated = false;
static Gtk.Application app;

static int start_x = 0;
static int start_y = 0;
static int offset_x = 0;
static int offset_y = 0;

private static unowned ListModel monitors;
private static ListStore windows;

public const uint ANIMATION_DURATION = 400;

/** Separates each group of monitors and parses them separately */
public static int main (string[] args) {
    try {
        Gtk.init ();
        Adw.init ();

    // TODO: Do this instead:
    // https://discourse.gnome.org/t/having-trouble-getting-my-schema-to-work-in-gtk4-tutorial-example/8541/6
#if USE_GLOBAL_GSCHEMA
        // Use the global compiled gschema in /usr/share/glib-2.0/schemas/*
        self_settings = new Settings ("org.erikreider.swaysettings");
#else
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
#endif

        app = new Gtk.Application ("org.erikreider.swaysettings-screenshot",
                                   ApplicationFlags.FLAGS_NONE);
        app.activate.connect ((g_app) => {
            if (activated) {
                show_all_screenshot_grids ();
                return;
            }
            activated = true;
            init ();
        });

        app.register ();

        // Load custom CSS
        Gtk.CssProvider css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource (
            "/org/erikreider/swaysettings/screenshot.css");
        Gtk.StyleContext.add_provider_for_display (
            Gdk.Display.get_default (),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_USER);

        // Init resources
        var theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
        theme.add_resource_path ("/org/erikreider/swaysettings/icons");

        return app.run ();
    } catch (Error e) {
        stderr.printf ("Application error: %s\n", e.message);
        return 1;
    }
}

private static void init () {
    windows = new ListStore (typeof (ScreenshotWindow));

    Gdk.Display ? display = Gdk.Display.get_default ();
    assert_nonnull (display);

    monitors = display.get_monitors ();
    monitors.items_changed.connect (monitors_changed);

    monitors_changed (0, 0, monitors.get_n_items ());
}

private static void monitors_changed (uint position, uint removed, uint added) {
    for (uint i = 0; i < removed; i++) {
        ScreenshotWindow window = (ScreenshotWindow) windows.get_item (position + i);
        window.close ();
        windows.remove (position + i);
    }

    for (uint i = 0; i < added; i++) {
        Gdk.Monitor monitor = (Gdk.Monitor) monitors.get_item (position + i);
        ScreenshotWindow win = new ScreenshotWindow (app, monitor);
        windows.insert (position + i, win);
        win.present ();
    }
}

public static void show_all_screenshot_grids () {
    for (int i = 0; i < windows.n_items; i++) {
        ScreenshotWindow w = (ScreenshotWindow) windows.get_item (i);
        w.show_screenshot_grid ();
        w.show ();
    }
}

public static void show_all_screenshot_lists () {
    bool has_screenshots = false;
    for (int i = 0; i < windows.n_items; i++) {
        ScreenshotWindow w = (ScreenshotWindow) windows.get_item (i);
        if (w.list.num_screenshots == 0) {
            w.hide ();
        } else {
            has_screenshots = true;
            w.show_screenshot_list (false);
            w.show ();
        }
    }

    if (!has_screenshots) {
        app.quit ();
    }
}

public static void queue_draw_all () {
    for (int i = 0; i < windows.n_items; i++) {
        ScreenshotWindow w = (ScreenshotWindow) windows.get_item (i);
        w.draw_grid ();
    }
}

public static void hide_all_except (ScreenshotWindow ref_window) {
    for (int i = 0; i < windows.n_items; i++) {
        ScreenshotWindow w = (ScreenshotWindow) windows.get_item (i);
        if (w != ref_window) {
            if (w.list.num_screenshots == 0) {
                w.hide ();
            } else {
                w.show_screenshot_list (false);
            }
        }
    }
}

/**
 * Hides all windows that don't have any screenshot previews.
 * Closes the application if there are no windows with previews.
 */
public static void try_hide_all (bool close_if_empty) {
    bool has_screenshots = false;
    for (int i = 0; i < windows.n_items; i++) {
        ScreenshotWindow w = (ScreenshotWindow) windows.get_item (i);
        if (w.list.num_screenshots == 0) {
            w.hide ();
        } else {
            has_screenshots = true;
        }
    }

    if (!has_screenshots && close_if_empty) {
        app.quit ();
    }
}
