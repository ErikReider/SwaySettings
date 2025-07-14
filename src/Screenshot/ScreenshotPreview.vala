private enum DecorationLayout {
    LEFT, RIGTH;
}

public delegate Graphene.Size AnimationCallback (ScreenshotPreview widget,
                                                 double value);
public delegate void AnimationDoneCallback (ScreenshotPreview widget);
public delegate void ClickCallback (ScreenshotPreview widget);

[GtkTemplate (ui = "/org/erikreider/swaysettings/ui/ScreenshotPreview.ui")]
public class ScreenshotPreview : Adw.Bin {
    public const uint TIMEOUT_S = 10;
    public const int MAX_SIZE = 300;
    // A good value to fit all the top buttons
    public const int MIN_SIZE = 150;
    const double MON_SCALE = 0.1;

    private unowned ScreenshotWindow window;

    [GtkChild]
    unowned Gtk.Overlay overlay;

    [GtkChild]
    public unowned Gtk.CenterBox header_bar;
    [GtkChild]
    unowned Gtk.Picture picture;

    private Gtk.GestureClick overlay_click = new Gtk.GestureClick ();
    private Gtk.EventControllerMotion motion_controller =
        new Gtk.EventControllerMotion ();

    private uint hide_id = 0;

    unowned ClickCallback close_click_cb = null;

    public ScreenshotPreview.list (ScreenshotWindow window,
                                   ClickCallback close_click_cb) {
        this(window);
        this.close_click_cb = close_click_cb;

        this.opacity = 0.0;

        overlay.set_cursor_from_name ("pointer");
        overlay.add_controller (overlay_click);
        overlay_click.released.connect (picture_button_click_cb);
        overlay.add_controller (motion_controller);
        motion_controller.enter.connect (remove_timer);
        motion_controller.leave.connect (add_timer);

        Gtk.Button close_button =
            new Gtk.Button.from_icon_name ("window-close-symbolic");
        close_button.add_css_class ("close");
        close_button.add_css_class ("circular");
        close_button.add_css_class ("opaque");
        close_button.clicked.connect (close_button_click_cb);

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
        switch (get_decoration_layout ()) {
            case DecorationLayout.LEFT:
                header_bar.set_end_widget (button_box);
                header_bar.set_start_widget (close_button);
                break;
            case DecorationLayout.RIGTH:
                header_bar.set_start_widget (button_box);
                header_bar.set_end_widget (close_button);
                break;
        }
    }

    public ScreenshotPreview.fixed (ScreenshotWindow window) {
        this(window);

        set_can_target (false);
    }

    private ScreenshotPreview (ScreenshotWindow window) {
        this.window = window;

        // Fixes the Picture taking up too much space:
        // https://gitlab.gnome.org/GNOME/gtk/-/issues/7092
        picture.set_layout_manager (new Gtk.CenterLayout ());
    }

    public void add_timer () {
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

    public static Graphene.Rect calculate_dst_rect (ScreenshotWindow window,
                                                    Graphene.Rect init_rect) {
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

        return Graphene.Rect ().init (
            window.monitor.geometry.width - (float) dst_width,
            window.monitor.geometry.height - (float)  dst_height,
            (float) dst_width,
            (float) dst_height);
    }

    private inline string get_file_name () {
        DateTime time = new DateTime.now_local ();
        return "Screenshot from %s.png".printf (time.format ("%Y-%m-%d %H-%M-%S"));
    }

    private File ? get_initial_folder () {
        Variant ? variant = SwaySettings.Functions.get_gsetting (
            self_settings,
            Constants.SETTINGS_SCREENSHOT_SAVE_DEST,
            VariantType.STRING);
        if (variant == null) {
            critical ("Setting: \"%s\" could not be found!",
                Constants.SETTINGS_SCREENSHOT_SAVE_DEST);
            return null;
        }

        string paths[2] = {
            variant.dup_string (),
            Path.build_path (
                    Path.DIR_SEPARATOR_S,
                    Environment.get_home_dir (),
                    variant.dup_string ()),
        };
        foreach (string path in paths) {
            if (path[:2] == "~/") {
                path = Environment.get_home_dir () + path[1:];
            }
            File initial_file = File.new_for_path (path);
            if (initial_file.query_exists ()) {
                return initial_file;
            }
        }

        return null;
    }

    private unowned Gdk.Texture ? get_texture () {
        unowned Gdk.Paintable ? paintable = picture.get_paintable ();
        if (paintable == null) {
            critical ("Paintable is null");
            return null;
        } else if (!(paintable is Gdk.Texture)) {
            warning (
                "Could not save screenshot. Type mismatch: %s",
                paintable.get_type ().name ());
            return null;
        }
        return (Gdk.Texture) paintable;
    }

    private void picture_button_click_cb () {
        Variant variant = SwaySettings.Functions.get_gsetting (
            self_settings,
            Constants.SETTINGS_SCREENSHOT_EDIT_CMD,
            VariantType.STRING);
        if (variant == null) {
            critical ("Setting: \"%s\" could not be found!",
                Constants.SETTINGS_SCREENSHOT_EDIT_CMD);
            return;
        }
        string cmd_str = variant.dup_string ();
        if (cmd_str[:2] == "~/") {
            cmd_str = Environment.get_home_dir () + cmd_str[1:];
        }

        unowned Gdk.Texture ? texture = get_texture ();
        if (texture == null) {
            critical ("Texture is null");
            return;
        }

        Bytes ? bytes = texture.save_to_png_bytes ();
        if (bytes == null) {
            critical ("Could not download PNG to bytes");
            return;
        }

        try {
            // Create a subprocess to run the set command
            string[] cmd;
            Shell.parse_argv (cmd_str, out cmd);

            Subprocess subprocess = new Subprocess.newv (
                cmd, SubprocessFlags.STDIN_PIPE);

            // Get the STDIN stream
            unowned OutputStream ? stdin_stream = subprocess.get_stdin_pipe ();
            if (stdin_stream == null) {
                stderr.printf("Failed to get stdin pipe for subprocess.\n");
                return;
            }

            // Write to STDIN
            stdin_stream.write_bytes (bytes);
            stdin_stream.close ();
        } catch (Error e) {
            stderr.printf ("Error: %s\n", e.message);
        }
    }

    private async void save_as_button_click_cb () {
        unowned Gdk.Texture ? texture = get_texture ();
        if (texture == null) {
            critical ("Texture is null");
            return;
        }

        Gtk.FileDialog dialog = new Gtk.FileDialog ();
        dialog.set_modal (true);
        dialog.set_title ("Save Screenshot");
        dialog.set_initial_folder (get_initial_folder ());
        dialog.set_initial_name (get_file_name ());

        File ? file = null;
        try {
            file = yield dialog.save (null, null);
            if (file == null) {
                return;
            }
        } catch (Error e) {
            info (e.message);
            return;
        }

        if (!texture.save_to_png (file.get_path ())) {
            critical ("Could not save screenshot %p in \"%s\"",
                texture, file.get_path ());
        }

        // Exit on save
        Variant ? variant = SwaySettings.Functions.get_gsetting (
            self_settings, Constants.SETTINGS_SCREENSHOT_EXIT_ON_SAVE, VariantType.BOOLEAN);
        if (variant == null) {
            critical ("Setting: \"%s\" could not be found!",
                Constants.SETTINGS_SCREENSHOT_EXIT_ON_SAVE);
            return;
        }
        if (variant.get_boolean ()) {
            close_button_click_cb ();
        }
    }

    private async void save_button_click_cb () {
        unowned Gdk.Texture ? texture = get_texture ();
        if (texture == null) {
            critical ("Texture is null");
            return;
        }

        File ? initial_folder = get_initial_folder ();
        string file_name = get_file_name ();
        if (initial_folder == null) {
            // Fallback
            yield save_as_button_click_cb ();
            return;
        }

        string path = Path.build_path (Path.DIR_SEPARATOR_S,
            initial_folder.get_path (), file_name);

        texture.save_to_png (path);

        // Exit on save
        Variant ? variant = SwaySettings.Functions.get_gsetting (
            self_settings, Constants.SETTINGS_SCREENSHOT_EXIT_ON_SAVE, VariantType.BOOLEAN);
        if (variant == null) {
            critical ("Setting: \"%s\" could not be found!",
                Constants.SETTINGS_SCREENSHOT_EXIT_ON_SAVE);
            return;
        }
        if (variant.get_boolean ()) {
            close_button_click_cb ();
        }
    }

    private void copy_button_click_cb () {
        unowned Gdk.Texture ? texture = get_texture ();
        if (texture == null) {
            critical ("Texture is null");
            return;
        }

        unowned Gdk.Clipboard clipboard = window.get_clipboard ();
        if (clipboard == null) {
            warning (
                "Could not copy screenshot to clipboard. Clipboard could not be obtained");
            return;
        }

        clipboard.set_texture (texture);
    }

    private void close_button_click_cb () {
        if (close_click_cb != null) {
            close_click_cb (this);
        }
    }

    public void set_texture (Gdk.Texture texture) {
        picture.set_paintable (texture);
        picture.set_content_fit (Gtk.ContentFit.CONTAIN);
    }
}
