public class ScreenshotGrid : Adw.Bin {
    unowned ScreenshotWindow window;

    Gtk.GestureDrag gesture_drag = new Gtk.GestureDrag ();

    public signal void done ();

    public ScreenshotGrid (ScreenshotWindow window) {
        this.window = window;

        set_cursor_from_name ("crosshair");

        this.add_controller (gesture_drag);
        gesture_drag.drag_begin.connect (drag_begin_cb);
        gesture_drag.drag_end.connect (drag_end_cb);
        gesture_drag.drag_update.connect (drag_update_cb);
    }

    private void drag_begin_cb (double x,
                                double y) {
        start_x = (int) x + window.monitor.geometry.x;
        start_y = (int) y + window.monitor.geometry.y;
        offset_x = 0;
        offset_y = 0;

        queue_draw ();
    }

    private void drag_end_cb (double offset_x,
                              double offset_y) {
        Graphene.Rect drag_rect = Graphene.Rect ().init (
            start_x, start_y,
            (int) offset_x, (int) offset_y);

        if (drag_rect.get_width () > 5 && drag_rect.get_height () > 5) {
            done ();
            return;
        }

        start_x = 0;
        start_y = 0;
        offset_x = 0;
        offset_y = 0;
        queue_draw_all ();
    }

    private void drag_update_cb (double x,
                                 double y) {
        offset_x = (int) x;
        offset_y = (int) y;
        queue_draw_all ();
    }

    protected override void snapshot(Gtk.Snapshot snapshot) {
        Graphene.Rect drag_rect = Graphene.Rect ().init (
            start_x - window.monitor.geometry.x,
            start_y - window.monitor.geometry.y,
            offset_x, offset_y);

        snapshot.push_mask (Gsk.MaskMode.INVERTED_ALPHA);

        Gdk.RGBA mask_color = Gdk.RGBA () {
            red = 0.0f,
            green = 0.0f,
            blue = 0.0f,
            alpha = 1.0f,
        };
        snapshot.append_color (mask_color, drag_rect);

        snapshot.pop ();

        Gdk.RGBA bg_color = Gdk.RGBA () {
            red = 0.0f,
            green = 0.0f,
            blue = 0.0f,
            alpha = 0.5f,
        };

        snapshot.append_color (bg_color, Graphene.Rect ().init (
                                   0, 0, get_width (), get_height ()));
        snapshot.pop ();

        //
        // Border
        //

        const float border_width = 2;
        Gdk.RGBA border_color = Gdk.RGBA () {
            red = 1.0f,
            green = 1.0f,
            blue = 1.0f,
            alpha = 0.5f,
        };
        Gsk.RoundedRect border_rect = Gsk.RoundedRect () {
            bounds = Graphene.Rect ().init (
                drag_rect.get_x () - border_width,
                drag_rect.get_y () - border_width,
                drag_rect.get_width () + border_width * 2,
                drag_rect.get_height () + border_width * 2),
        };
        snapshot.append_border (
            border_rect,
            new float[4] { border_width, border_width, border_width,
                           border_width, },
            new Gdk.RGBA[4] { border_color, border_color, border_color,
                              border_color, });

        base.snapshot (snapshot);
    }

    public void set_input_region () {
        // The input region should only cover the preview window
        unowned Gdk.Surface ?surface = window.get_surface ();
        if (surface != null) {
            Cairo.RectangleInt rect_int = Cairo.RectangleInt () {
                x = 0,
                y = 0,
                width = surface.width,
                height = surface.height,
            };
            Cairo.Region region = new Cairo.Region.rectangle (rect_int);
            surface.set_input_region (region);
        }
    }
}
