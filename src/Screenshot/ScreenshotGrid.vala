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

    public void drag_begin_cb (double x,
                               double y) {
        start_x = x + window.monitor.geometry.x;
        start_y = y + window.monitor.geometry.y;
        offset_x = 0;
        offset_y = 0;

        queue_draw ();
    }

    public void drag_end_cb (double offset_x,
                             double offset_y) {
        Graphene.Rect drag_rect = Graphene.Rect ().init (
            (int) start_x, (int) start_y,
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

    public void drag_update_cb (double x,
                                double y) {
        offset_x = x;
        offset_y = y;
        queue_draw_all ();
    }

    public override void snapshot(Gtk.Snapshot snapshot) {
        Graphene.Rect drag_rect = Graphene.Rect ().init (
            (int) start_x - window.monitor.geometry.x,
            (int) start_y - window.monitor.geometry.y,
            (int) offset_x,
            (int) offset_y);

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
}
