public class ScreenshotWindow : Gtk.ApplicationWindow {
    public unowned Gdk.Monitor monitor;

    Gtk.EventControllerKey key_controller = new Gtk.EventControllerKey ();

    Gtk.Stack stack;
    ScreenshotGrid grid;
    public ScreenshotList list;

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
        grid.done.connect (() => show_screenshot_list (true));
        stack.add_child (grid);

        list = new ScreenshotList (this);
        stack.add_child (list);

        show_screenshot_grid ();
    }

    public void show_screenshot_grid () {
        GtkLayerShell.set_keyboard_mode (this,
                                         GtkLayerShell.KeyboardMode.EXCLUSIVE);
        stack.set_transition_type (Gtk.StackTransitionType.CROSSFADE);
        stack.set_visible_child (grid);
        grid.set_input_region ();
    }

    public void show_screenshot_list (bool screenshot_taken) {
        GtkLayerShell.set_keyboard_mode (this, GtkLayerShell.KeyboardMode.NONE);

        if (screenshot_taken) {
            // Force the coords into a origin of top-left
            Graphene.Rect rect = Graphene.Rect ().init (
                start_x, start_y,
                offset_x, offset_y);
            start_x = 0;
            start_y = 0;
            offset_x = 0;
            offset_y = 0;

            list.add_preview (rect);

            hide_all_except (this);

            // Don't fade in the screenshot animation
            stack.set_transition_type (Gtk.StackTransitionType.NONE);
        }

        stack.set_visible_child (list);
        list.set_input_region ();
    }

    protected override void snapshot (Gtk.Snapshot snapshot) {
        // HACK: Fixes fully transparent windows not being mapped
        Gdk.RGBA color = Gdk.RGBA () {
            red = 0,
            green = 0,
            blue = 0,
            alpha = 0,
        };
        snapshot.append_color (color, Graphene.Rect.zero ());
        base.snapshot (snapshot);
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
                show_all_screenshot_lists ();
                return;
        }
    }

    public void draw_grid () {
        if (grid.visible) {
            grid.queue_draw ();
        }
    }
}
