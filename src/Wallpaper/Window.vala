namespace Wallpaper {
    class Window : Gtk.Window {
        Gtk.Stack stack;
        Gtk.DrawingArea image_1;
        Gtk.DrawingArea image_2;

        bool showing_image_1 = false;

        unowned BackgroundInfo ? info;
        unowned BackgroundInfo ? old_info;

        unowned Gdk.Display display;
        unowned Gdk.Monitor monitor;

        public signal void hide_transition_done ();

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
            image_1.unmap.connect (() => hide_transition_done ());
            stack.add (image_1);

            image_2 = new Gtk.DrawingArea () {
                valign = Gtk.Align.FILL,
                halign = Gtk.Align.FILL,
                expand = true,
                name = "image2",
            };
            image_2.unmap.connect (() => hide_transition_done ());
            stack.add (image_2);

            show_all ();

            this.image_1.draw.connect ((cr) => on_draw (cr, image_1));
            this.image_2.draw.connect ((cr) => on_draw (cr, image_2));

            change_wallpaper (init_info, null);
        }

        private bool on_draw (Cairo.Context cr, Gtk.DrawingArea image) {
            // Draw the new background if widget is transioning in. Else,
            // draw the old wallpaper
            unowned Gtk.DrawingArea background = showing_image_1 ? image_1 : image_2;
            bool is_image1 = image == background;
            unowned BackgroundInfo ? _info = is_image1 ? info : old_info;

            int buffer_width = image.get_allocated_width ();
            int buffer_height = image.get_allocated_height ();
            // Use greyscale background if wallpaper is not found...
            if (_info == null) {
                cr.save ();
                debug ("Not using surface...\n");
                Cairo.Surface surface = new Cairo.ImageSurface (
                    Cairo.Format.ARGB32, buffer_width, buffer_height);

                cr.rectangle (0, 0, buffer_width, buffer_height);
                double value = 0.8;
                cr.set_source_rgb (value, value, value);
                cr.fill ();
                cr.set_source_surface (surface, 0, 0);
                cr.restore ();
                return true;
            }

            int height = _info.height;
            int width = _info.width;
            cr.save ();
            switch (_info.image_info.scale_mode) {
                case ScaleModes.FILL:
                    double window_ratio = (double) buffer_width / buffer_height;
                    double bg_ratio = width / height;
                    if (window_ratio > bg_ratio) { // Taller wallpaper than monitor
                        double scale = (double) buffer_width / width;
                        if (scale * height < buffer_height) {
                            draw_scale_wide (buffer_width, width, buffer_height, height, cr, _info);
                        } else {
                            draw_scale_tall (buffer_width, width, buffer_height, height, cr, _info);
                        }
                    } else { // Wider wallpaper than monitor
                        double scale = (double) buffer_height / height;
                        if (scale * width < buffer_width) {
                            draw_scale_tall (buffer_width, width, buffer_height, height, cr, _info);
                        } else {
                            draw_scale_wide (buffer_width, width, buffer_height, height, cr, _info);
                        }
                    }
                    break;
                case ScaleModes.FIT:
                    double window_ratio = (double) buffer_width / buffer_height;
                    double bg_ratio = width / height;
                    if (window_ratio > bg_ratio) { // Taller wallpaper than monitor
                        double scale = (double) buffer_width / width;
                        if (scale * height < buffer_height) {
                            draw_scale_tall (buffer_width, width, buffer_height, height, cr, _info);
                        } else {
                            draw_scale_wide (buffer_width, width, buffer_height, height, cr, _info);
                        }
                    } else { // Wider wallpaper than monitor
                        double scale = (double) buffer_height / height;
                        if (scale * width < buffer_width) {
                            draw_scale_wide (buffer_width, width, buffer_height, height, cr, _info);
                        } else {
                            draw_scale_tall (buffer_width, width, buffer_height, height, cr, _info);
                        }
                    }
                    break;
                case ScaleModes.STRETCH:
                    cr.scale ((double) buffer_width / width,
                              (double) buffer_height / height);
                    cr.set_source_surface (_info.surface, 0, 0);
                    break;
                case ScaleModes.CENTER:
                    cr.set_source_surface (
                        _info.surface,
                        (double) buffer_width / 2 - width / 2,
                        (double) buffer_height / 2 - height / 2);
                    break;
            }
            // Sets a faster, less accurate filter when the pattern's reading pixel values
            cr.get_source ().set_filter (Cairo.Filter.BILINEAR);

            cr.paint ();
            cr.restore ();
            return true;
        }

        private void draw_scale_tall (int buffer_width,
                                      int width,
                                      int buffer_height,
                                      int height,
                                      Cairo.Context cr,
                                      BackgroundInfo _info) {
            double scale = (double) buffer_width / width;
            cr.scale (scale, scale);
            cr.set_source_surface (_info.surface,
                                   0, (double) buffer_height / 2 / scale - height / 2);
        }

        private void draw_scale_wide (int buffer_width,
                                      int width,
                                      int buffer_height,
                                      int height,
                                      Cairo.Context cr,
                                      BackgroundInfo _info) {
            double scale = (double) buffer_height / height;
            cr.scale (scale, scale);
            cr.set_source_surface (
                _info.surface,
                (double) buffer_width / 2 / scale - width / 2, 0);
        }

        public void change_wallpaper (BackgroundInfo ? background_info,
                                      BackgroundInfo ? old_background_info) {
            this.old_info = old_background_info;
            this.info = background_info;
            unowned Gtk.DrawingArea background = !showing_image_1 ? image_1 : image_2;
            showing_image_1 = !showing_image_1;
            stack.set_visible_child (background);
        }
    }
}
