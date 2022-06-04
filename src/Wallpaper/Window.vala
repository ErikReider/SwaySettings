namespace Wallpaper {
    class Window : Gtk.Window {
        Gtk.Stack stack;
        Gtk.Image image_1;
        Gtk.Image image_2;

        bool showing_image_1 = true;

        unowned Gdk.Display display;
        unowned Gdk.Monitor monitor;

        public Window (Gtk.Application app,
                       Gdk.Display disp,
                       Gdk.Monitor mon,
                       string ? path) {
            Object (application: app);
            this.display = disp;
            this.monitor = mon;

            GtkLayerShell.init_for_window (this);
            GtkLayerShell.set_monitor (this, monitor);
            GtkLayerShell.set_layer (this, GtkLayerShell.Layer.BACKGROUND);
            GtkLayerShell.set_exclusive_zone (this, -1);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);

            stack = new Gtk.Stack () {
                valign = Gtk.Align.FILL,
                halign = Gtk.Align.FILL,
                expand = true,
                transition_type = Gtk.StackTransitionType.CROSSFADE,
                transition_duration = 250,
            };
            this.add (stack);

            image_1 = new Gtk.Image () {
                pixel_size = -1,
                valign = Gtk.Align.FILL,
                halign = Gtk.Align.FILL,
                expand = true,
            };
            stack.add (image_1);

            image_2 = new Gtk.Image () {
                pixel_size = -1,
                valign = Gtk.Align.FILL,
                halign = Gtk.Align.FILL,
                expand = true,
            };
            stack.add (image_2);

            show_all ();

            // Init the first image
            ulong realize_handler = 0;
            realize_handler = image_1.draw.connect (() => {
                image_1.disconnect (realize_handler);
                realize_handler = 0;
                set_wallpaper (path);
                return false;
            });
        }

        /**
         * Sets the wallpaper and transitions between the new and the old wallpaper
         */
        public void set_wallpaper (string path) {
            unowned Gtk.Image background = showing_image_1 ? image_1 : image_2;
            showing_image_1 = !showing_image_1;

            draw_wallpaper (path, background);
            stack.set_visible_child (background);
        }

        /** Draws the wallpaper on the provided Gtk.Image */
        private void draw_wallpaper (string path, Gtk.Image background) {
            int width = get_allocated_width ();
            int height = get_allocated_height ();
            int scale = background.scale_factor;

            try {
                if (path != null && path.length > 0) {
                    var pixbuf = new Gdk.Pixbuf.from_file_at_scale (
                        path,
                        width * scale,
                        height * scale,
                        false);
                    var surface = Gdk.cairo_surface_create_from_pixbuf (
                        pixbuf,
                        scale,
                        get_window ());
                    background.set_from_surface (surface);
                    return;
                }
            } catch (Error e) {
                stderr.printf (
                    "Could not find wallpaper, using greyscale background instead... %s\n",
                    e.message);
            }
            // Use greyscale background if wallpaper is not found...
            Cairo.Surface surface = new Cairo.ImageSurface (
                Cairo.Format.ARGB32, width, height);
            Cairo.Context cr = new Cairo.Context (surface);

            cr.rectangle (0, 0, width, height);
            double value = 0.8;
            cr.set_source_rgb (value, value, value);
            cr.fill ();
            background.set_from_surface (surface);
        }
    }
}
