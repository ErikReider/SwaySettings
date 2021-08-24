int main (string[] args) {
    Gtk.init (ref args);
    Hdy.init ();

    var app = new Gtk.Application ("org.erikreider.swaysettings",
                                   ApplicationFlags.FLAGS_NONE);
    app.activate.connect (() => {
        var win = app.active_window;
        if (win == null) {
            win = new SwaySettings.Window (app);
        }
        win.present ();
    });

    return app.run (args);
}
