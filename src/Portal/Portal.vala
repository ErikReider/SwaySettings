static MainLoop mainloop;
static Settings self_settings;

static bool replace = false;

public void main (string[] args) {
    Environment.unset_variable ("GTK_USE_PORTAL");
    Environment.set_prgname ("xdg-desktop-portal-swaysettings");

    mainloop = new MainLoop (null, false);

    if ("--replace" in args) {
        replace = true;
    }

    self_settings = new Settings ("org.erikreider.swaysettings");

    uint id = Bus.own_name (BusType.SESSION,
                            "org.freedesktop.impl.portal.desktop.swaysettings",
                            BusNameOwnerFlags.ALLOW_REPLACEMENT |
                            (replace ? BusNameOwnerFlags.REPLACE : 0),
                            on_bus_aquired,
                            on_name_aquired,
                            () => {
        critical ("Could not acquire portal name!...");
        mainloop.quit ();
    });

    mainloop.run ();

    Bus.unown_name (id);
}

void on_bus_aquired (DBusConnection conn,
                     string name) {
    debug ("Bus aquired: %s", name);
    try {
        conn.register_object ("/org/freedesktop/portal/desktop",
                              new Services.Wallpaper (conn));
        conn.register_object ("/org/freedesktop/portal/desktop",
                              new Services.Settings (conn));
    } catch (IOError e) {
        critical ("Could not register CC service");
        Process.exit (1);
    }
}

void on_name_aquired (DBusConnection conn) {
    debug ("org.freedesktop.impl.portal.desktop.swaysettings acquired");
}
