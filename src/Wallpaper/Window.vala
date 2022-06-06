namespace Wallpaper {
    class Window : Gtk.Window {
        Gtk.Stack stack;
        Gtk.DrawingArea image_1;
        Gtk.DrawingArea image_2;

        bool showing_image_1 = false;

        BackgroundInfo ? info;
        BackgroundInfo ? old_info;

        unowned Gdk.Display display;
        unowned Gdk.Monitor monitor;

        public Window (Gtk.Application app,
                       Gdk.Display disp,
                       Gdk.Monitor mon,
                       BackgroundInfo ? init_info) {
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

            image_1 = new Gtk.DrawingArea () {
                valign = Gtk.Align.FILL,
                halign = Gtk.Align.FILL,
                expand = true,
                name = "image1",
            };
            stack.add (image_1);

            image_2 = new Gtk.DrawingArea () {
                valign = Gtk.Align.FILL,
                halign = Gtk.Align.FILL,
                expand = true,
                name = "image2",
            };
            stack.add (image_2);

            show_all ();

            this.image_1.draw.connect ((cr) => on_draw (cr, image_1));
            this.image_2.draw.connect ((cr) => on_draw (cr, image_2));

            change_wallpaper (init_info);
        }

        private bool on_draw (Cairo.Context cr, Gtk.DrawingArea image) {
            // Draw the new background if widget is transioning in. Else,
            // draw the old wallpaper
            unowned Gtk.DrawingArea background = showing_image_1 ? image_1 : image_2;
            unowned BackgroundInfo ? _info = image == background ? info : old_info;

            int buffer_width = monitor.geometry.width;
            int buffer_height = monitor.geometry.height;
            // Use greyscale background if wallpaper is not found...
            if (_info == null) {
                debug ("Not using surface...\n");
                Cairo.Surface surface = new Cairo.ImageSurface (
                    Cairo.Format.ARGB32, buffer_width, buffer_height);

                cr.rectangle (0, 0, buffer_width, buffer_height);
                double value = 0.8;
                cr.set_source_rgb (value, value, value);
                cr.fill ();
                cr.set_source_surface (surface, 0, 0);
                return false;
            }

            int surface_h = _info.height;
            int surface_w = _info.width;
            switch (_info.image_info.scale_mode) {
                case ScaleModes.COVER:
                    double window_ratio = (double) buffer_width / buffer_height;
                    double bg_ratio = surface_w / surface_h;

                    if (window_ratio > bg_ratio) {
                        double scale = (double) buffer_height / surface_h;
                        cr.scale (scale, scale);
                        cr.set_source_surface (
                            _info.surface,
                            (double) buffer_width / 2 / scale - surface_w / 2, 0);
                    } else {
                        double scale = (double) buffer_width / surface_w;
                        cr.scale (scale, scale);
                        cr.set_source_surface (
                            _info.surface,
                            0, (double) buffer_height / 2 / scale - surface_h / 2);
                    }
                    break;
                case ScaleModes.FIT:
                    double window_ratio = (double) buffer_width / buffer_height;
                    double bg_ratio = surface_w / surface_h;

                    if (window_ratio > bg_ratio) {
                        double scale = (double) buffer_width / surface_w;
                        cr.scale (scale, scale);
                        cr.set_source_surface (
                            _info.surface,
                            0,
                            (double) buffer_height / 2 / scale - surface_h / 2);
                    } else {
                        double scale = (double) buffer_height / surface_h;
                        cr.scale (scale, scale);
                        cr.set_source_surface (
                            _info.surface,
                            (double) buffer_width / 2 / scale - surface_w / 2,
                            0);
                    }
                    break;
                case ScaleModes.FILL:
                    cr.scale ((double) buffer_width / surface_w,
                              (double) buffer_height / surface_h);
                    cr.set_source_surface (_info.surface, 0, 0);
                    break;
                case ScaleModes.CENTER:
                    cr.set_source_surface (
                        _info.surface,
                        (double) buffer_width / 2 - surface_w / 2,
                        (double) buffer_height / 2 - surface_h / 2);
                    break;
            }

            // Sets a faster, less accurate filter when the pattern's reading pixel values
            cr.get_source ().set_filter (Cairo.Filter.BILINEAR);

            cr.paint ();
            return false;
        }

        public void change_wallpaper (BackgroundInfo ? background_info) {
            if (background_info == null) {
                this.old_info = null;
                this.info = null;
                return;
            }
            this.old_info = info;
            this.info = background_info;
            unowned Gtk.DrawingArea background = !showing_image_1 ? image_1 : image_2;
            showing_image_1 = !showing_image_1;
            stack.set_visible_child (background);
        }
    }
}
