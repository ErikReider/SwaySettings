namespace Wallpaper {
    class Window : Gtk.Window {
        const Gsk.ScalingFilter SCALING_FILTER = Gsk.ScalingFilter.NEAREST;
        const int TRANSITION_DURATION = 250;
        const int BLUR_RADIUS = 100;

        private double animation_progress = 1.0;
        private double animation_progress_inv {
            get {
                return (1 - animation_progress);
            }
        }
        private Animation ? animation;

        public Window (Gtk.Application app, Gdk.Monitor monitor) {
            Object (application: app);

            animation = new Animation (this, TRANSITION_DURATION,
                           Animation.ease_in_out_cubic,
                           animation_value_cb,
                           animation_done_cb);

            GtkLayerShell.init_for_window (this);
            GtkLayerShell.set_monitor (this, monitor);
            GtkLayerShell.set_layer (this, GtkLayerShell.Layer.BACKGROUND);
            GtkLayerShell.set_exclusive_zone (this, -1);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);

            change_wallpaper ();
        }

        public void change_wallpaper () {
            // Start the transition
            animate (0);
        }

        public override void snapshot(Gtk.Snapshot snapshot) {
            if (animation.is_running) {
                snapshot.push_cross_fade (animation_progress_inv);

                apply_transformed_background (snapshot, old_background_info);
                snapshot.pop ();

                snapshot.push_blur (animation_progress * BLUR_RADIUS);
                apply_transformed_background (snapshot, background_info);
                snapshot.pop ();
                snapshot.pop ();
            } else {
                apply_transformed_background (snapshot, background_info);
            }
        }

        void apply_transformed_background (Gtk.Snapshot snapshot, BackgroundInfo info) {
            int buffer_height = get_height ();
            int buffer_width = get_width ();

            // Render color instead of texture
            if (info.texture == null || info.config.path.length == 0) {
                Gdk.RGBA color = info.config.get_color ();
                snapshot.append_color (color, { { 0, 0 }, { buffer_width, buffer_height } });
                return;
            }

            // Render texture and scale it correctly
            snapshot.save ();

            int height = info.height;
            int width = info.width;
            switch (info.config.scale_mode) {
                case ScaleModes.FILL:
                    double window_ratio = (double) buffer_width / buffer_height;
                    double bg_ratio = width / height;
                    if (window_ratio > bg_ratio) { // Taller wallpaper than monitor
                        double scale = (double) buffer_width / width;
                        if (scale * height < buffer_height) {
                            draw_scale_wide (buffer_width, width, buffer_height, height, snapshot, info);
                        } else {
                            draw_scale_tall (buffer_width, width, buffer_height, height, snapshot, info);
                        }
                    } else { // Wider wallpaper than monitor
                        double scale = (double) buffer_height / height;
                        if (scale * width < buffer_width) {
                            draw_scale_tall (buffer_width, width, buffer_height, height, snapshot, info);
                        } else {
                            draw_scale_wide (buffer_width, width, buffer_height, height, snapshot, info);
                        }
                    }
                    break;
                case ScaleModes.FIT:
                    double window_ratio = (double) buffer_width / buffer_height;
                    double bg_ratio = width / height;
                    if (window_ratio > bg_ratio) { // Taller wallpaper than monitor
                        double scale = (double) buffer_width / width;
                        if (scale * height < buffer_height) {
                            draw_scale_tall (buffer_width, width, buffer_height, height, snapshot, info);
                        } else {
                            draw_scale_wide (buffer_width, width, buffer_height, height, snapshot, info);
                        }
                    } else { // Wider wallpaper than monitor
                        double scale = (double) buffer_height / height;
                        if (scale * width < buffer_width) {
                            draw_scale_wide (buffer_width, width, buffer_height, height, snapshot, info);
                        } else {
                            draw_scale_tall (buffer_width, width, buffer_height, height, snapshot, info);
                        }
                    }
                    break;
                case ScaleModes.STRETCH:
                    snapshot.scale((float) buffer_width / width,
                                   (float) buffer_height / height);
                    snapshot.append_scaled_texture (info.texture,
                                                    SCALING_FILTER,
                                                    { { 0, 0 }, { width, height } });
                    break;
                case ScaleModes.CENTER:
                    float x = (float) (buffer_width / 2 - width / 2);
                    float y = (float) (buffer_height / 2 - height / 2);
                    snapshot.append_scaled_texture (info.texture,
                                                    SCALING_FILTER,
                                                    { { x, y }, { width, height } });
                    break;
            }
            snapshot.restore ();
        }

        private void draw_scale_tall (int buffer_width,
                                      int width,
                                      int buffer_height,
                                      int height,
                                      Gtk.Snapshot snapshot,
                                      BackgroundInfo info) {
            float scale = (float) buffer_width / width;
            snapshot.scale(scale, scale);
            float x = 0;
            float y = (float) (buffer_height / 2 / scale - height / 2);
            snapshot.append_scaled_texture (info.texture,
                                            SCALING_FILTER,
                                            { { x, y }, { width, height } });
        }

        private void draw_scale_wide (int buffer_width,
                                      int width,
                                      int buffer_height,
                                      int height,
                                      Gtk.Snapshot snapshot,
                                      BackgroundInfo info) {
            float scale = (float) buffer_height / height;
            snapshot.scale(scale, scale);
            float x = (float) (buffer_width / 2 / scale - width / 2);
            float y = 0;
            snapshot.append_scaled_texture (info.texture,
                                            SCALING_FILTER,
                                            { { x, y }, { width, height } });
        }

        void animation_value_cb (double progress) {
            animation_progress = progress;

            queue_resize ();
        }

        void animation_done_cb () {
            animation.dispose ();

            animation_progress = 1;

            queue_allocate ();
        }

        void animate (double to) {
            animation.stop ();
            animation.start (animation_progress, to);
        }
    }
}
