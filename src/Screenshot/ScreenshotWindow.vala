public class ScreenshotWindow : Gtk.ApplicationWindow {
    public unowned Gdk.Monitor monitor;

    Gtk.EventControllerKey key_controller = new Gtk.EventControllerKey ();

    Gtk.Stack stack;
    ScreenshotGrid grid;
    ScreenshotPreview preview;

    public Gdk.Texture ? screenshot = null;

    public ScreenshotWindow (Gtk.Application app,
                             Gdk.Monitor monitor) {
        Object (application: app);

        this.monitor = monitor;

        add_css_class ("screenshot-window");

        GtkLayerShell.init_for_window (this);
        GtkLayerShell.set_monitor (this, monitor);
        GtkLayerShell.set_layer (this, GtkLayerShell.Layer.OVERLAY);
        GtkLayerShell.set_exclusive_zone (this, -1);
        GtkLayerShell.set_keyboard_mode (this,
                                         GtkLayerShell.KeyboardMode.EXCLUSIVE);
        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);
        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);

        ((Gtk.Widget) this).add_controller (key_controller);
        key_controller.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
        key_controller.key_released.connect (key_released_event_cb);

        stack = new Gtk.Stack ();
        set_child (stack);

        grid = new ScreenshotGrid (this);
        grid.done.connect (screenshot_taken);
        stack.add_child (grid);

        preview = new ScreenshotPreview (this);
        stack.add_child (preview);

        stack.set_visible_child (grid);

        close_request.connect (() => {
            app.quit ();
            return true;
        });
    }

    private void screenshot_taken () {
        GtkLayerShell.set_keyboard_mode (this, GtkLayerShell.KeyboardMode.NONE);

        // Force the coords into a origin of top-left
        Graphene.Rect rect = Graphene.Rect ().init (
            (int) start_x, (int) start_y,
            (int) offset_x, (int) offset_y);
        // Take the screenshot and wait
        if (!preview.set_texture (get_region (rect))) {
            stderr.printf ("Unable to screenshot!\n");
            app.quit ();
        }

        hide_all_except (this);
        stack.set_visible_child (preview);
    }

    private void key_released_event_cb (uint keyval,
                                        uint keycode,
                                        Gdk.ModifierType state) {
        if (!grid.visible) {
            return;
        }

        switch (Gdk.keyval_name (keyval)) {
            case "Escape":
            case "Delete":
            case "BackSpace":
            case "Caps_Lock":
                app.quit ();
                return;
        }
    }

    public void draw_grid () {
        if (grid.visible) {
            grid.queue_draw ();
        }
    }
}
