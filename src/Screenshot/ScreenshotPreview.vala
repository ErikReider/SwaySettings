private enum DecorationLayout {
    LEFT, RIGTH;
}
private class AnimationProgress : Object {
    public double progress { get; set; }

    public AnimationProgress (double progress) {
        Object (progress: progress);
    }
}

public delegate Graphene.Size AnimationCallback (ScreenshotPreview widget,
                                                 double value);
public delegate void AnimationDoneCallback (ScreenshotPreview widget);
public delegate void ClickCallback (ScreenshotPreview widget);

[GtkTemplate (ui = "/org/erikreider/swaysettings/ui/ScreenshotPreview.ui")]
public class ScreenshotPreview : Adw.Bin {
    public const uint ANIMATION_DURATION = 400;
    public const uint TIMEOUT_S = 10;
    public const int MAX_SIZE = 300;
    // A good value to fit all the top buttons
    public const int MIN_SIZE = 150;

    private unowned ScreenshotWindow window;

    [GtkChild]
    unowned Gtk.Overlay overlay;

    [GtkChild]
    unowned Gtk.CenterBox header_bar;
    [GtkChild]
    unowned Gtk.Picture picture;

    private Adw.TimedAnimation animation;
    private Adw.AnimationTarget target;

    public Graphene.Rect global_rect { get; private set; }
    public Graphene.Rect init_rect { get; private set; }
    public Graphene.Rect dst_rect { get; private set; }

    private Gtk.GestureClick overlay_click = new Gtk.GestureClick ();
    private Gtk.EventControllerMotion motion_controller =
        new Gtk.EventControllerMotion ();

    private AnimationProgress animation_progress = new AnimationProgress (0.0);

    private uint hide_id = 0;
    private ulong map_id = 0;

    private unowned AnimationCallback animation_cb;
    private unowned AnimationDoneCallback animation_done_cb;
    private unowned ClickCallback close_click_cb;

    public ScreenshotPreview (ScreenshotWindow window,
                              Graphene.Rect global_rect,
                              AnimationCallback animation_cb,
                              AnimationDoneCallback animation_done_cb,
                              ClickCallback close_click_cb) {
        this.window = window;
        this.global_rect = global_rect;
        this.animation_cb = animation_cb;
        this.animation_done_cb = animation_done_cb;
        this.close_click_cb = close_click_cb;

        overlay.set_cursor_from_name ("pointer");
        overlay.add_controller (overlay_click);
        overlay_click.released.connect (picture_button_click_cb);
        overlay.add_controller (motion_controller);
        motion_controller.enter.connect (remove_timer);
        motion_controller.leave.connect (add_timer);

        // Fixes the Picture taking up too much space:
        // https://gitlab.gnome.org/GNOME/gtk/-/issues/7092
        picture.set_layout_manager (new Gtk.CenterLayout ());

        animation_progress.bind_property ("progress",
                                          header_bar, "opacity",
                                          BindingFlags.SYNC_CREATE);

        DecorationLayout decoration_layout = get_decoration_layout ();

        Gtk.Button close_button =
            new Gtk.Button.from_icon_name ("window-close-symbolic");
        close_button.add_css_class ("close");
        close_button.add_css_class ("circular");
        close_button.add_css_class ("opaque");
        close_button.clicked.connect (() => close_click_cb (this));

        Gtk.Button save_button =
            new Gtk.Button.from_icon_name ("document-save-symbolic");
        save_button.add_css_class ("circular");
        save_button.add_css_class ("flat");
        save_button.clicked.connect (save_button_click_cb);

        Gtk.Button save_as_button =
            new Gtk.Button.from_icon_name ("document-save-as-symbolic");
        save_as_button.add_css_class ("circular");
        save_as_button.add_css_class ("flat");
        save_as_button.clicked.connect (save_as_button_click_cb);

        Gtk.Button copy_button =
            new Gtk.Button.from_icon_name ("edit-copy-symbolic");
        copy_button.add_css_class ("circular");
        copy_button.add_css_class ("flat");
        copy_button.clicked.connect (copy_button_click_cb);

        Gtk.Box button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
        button_box.append (copy_button);
        button_box.append (save_as_button);
        button_box.append (save_button);
        switch (decoration_layout) {
        case DecorationLayout.LEFT:
            header_bar.set_end_widget (button_box);
            header_bar.set_start_widget (close_button);
            break;
        case DecorationLayout.RIGTH:
            header_bar.set_start_widget (button_box);
            header_bar.set_end_widget (close_button);
            break;

        }

        target = new Adw.CallbackAnimationTarget (animate_value_cb);
        animation = new Adw.TimedAnimation (this, 0.0, 1.0, ANIMATION_DURATION,
                                            target);
        animation.set_easing (Adw.Easing.EASE_IN);
        animation.done.connect (animate_done_cb);

        init_rects ();
    }

    private void add_timer () {
        remove_timer ();
        hide_id = Timeout.add_seconds_once (TIMEOUT_S, () => {
            hide_id = 0;
            // TODO:Close / save the screenshot after a timeout?
        });
    }

    private void remove_timer () {
        if (hide_id > 0) {
            Source.remove (hide_id);
            hide_id = 0;
        }
    }

    private DecorationLayout get_decoration_layout () {
        DecorationLayout layout = DecorationLayout.RIGTH;

        unowned Gtk.Settings?g_settings = Gtk.Settings.get_default ();
        if (g_settings == null) {
            return layout;
        }

        string decoration = g_settings.gtk_decoration_layout;
        if (!decoration.contains (":")) {
            return layout;
        }

        string[] split = decoration.split (":");
        string start = "";
        string end = "";
        if ("close" in split[0]) {
            start = "close";
            layout = DecorationLayout.LEFT;
        }
        if ("close" in split[1]) {
            end = "close";
            layout = DecorationLayout.RIGTH;
        }

        return layout;
    }

    private void init_rects () {
        init_rect = Graphene.Rect ()
                    .init_from_rect (global_rect)
                    .offset (-window.monitor.geometry.x,
                             -window.monitor.geometry.y);

        const double MON_SCALE = 0.1;
        double max_preview_size_width =
            Math.fmax (window.monitor.geometry.width * MON_SCALE, MAX_SIZE);
        double max_preview_size_height =
            Math.fmax (window.monitor.geometry.height * MON_SCALE, MAX_SIZE);

        double dst_width = init_rect.get_width ();
        double dst_height = init_rect.get_height ();
        double ratio = init_rect.get_width () / init_rect.get_height ();
        if (ratio > 1.0) {
            // Wide
            double scale = dst_width / max_preview_size_width;
            dst_height = (init_rect.get_height () / scale);
        } else if (ratio < 1.0) {
            // Tall
            double scale = dst_height / max_preview_size_height;
            dst_width = (init_rect.get_width () / scale);
        }
        dst_width = Math.fmax (
            Math.fmin (dst_width, max_preview_size_width),
            MIN_SIZE);
        dst_height = Math.fmax (
            Math.fmin (dst_height, max_preview_size_height),
            MIN_SIZE);

        dst_rect = Graphene.Rect ().init (
            window.monitor.geometry.width - (float) dst_width,
            window.monitor.geometry.height - (float)  dst_height,
            (float) dst_width,
            (float) dst_height);
    }

    private void animate_value_cb (double value) {
        this.animation_progress.progress = value;

        Graphene.Size size = this.animation_cb (this, value);
        set_size_request ((int) size.width, (int) size.height);
    }

    private void animate_done_cb () {
        this.animation_done_cb (this);

        Graphene.Size size = this.animation_cb (this, 1.0);
        set_size_request ((int) size.width, (int) size.height);

        add_timer ();
    }

    // TODO:
    private void picture_button_click_cb (int n_press,
                                          double x,
                                          double y) {
        print ("PIC CLICK!\n");
    }

    // TODO:
    private void save_as_button_click_cb (Gtk.Button button) {
        print ("Save As CLICK!\n");
    }

    // TODO:
    private void save_button_click_cb (Gtk.Button button) {
        print ("Save CLICK!\n");
    }

    // TODO:
    private void copy_button_click_cb (Gtk.Button button) {
        print ("Copy CLICK!\n");
    }

    public bool set_texture (Gdk.Texture ?texture) {
        if (texture == null) {
            return false;
        }

        picture.set_paintable (texture);
        picture.set_content_fit (Gtk.ContentFit.CONTAIN);
        return true;
    }

    public void start_animation () {
        if (map_id != 0) {
            disconnect (map_id);
            map_id = 0;
        }
        map_id = map.connect (() => {
            disconnect (map_id);
            map_id = 0;

            animation.play ();
        });
    }
}
