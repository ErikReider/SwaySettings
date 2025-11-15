namespace Wallpaper {
    class Window : Gtk.Window {
        const Gsk.ScalingFilter SCALING_FILTER = Gsk.ScalingFilter.NEAREST;
        const int TRANSITION_DURATION = 500;
        const int BLUR_RADIUS = 100;

        public unowned Gdk.Monitor monitor { get; construct set; }

        private double animation_progress = 1.0;
        private double animation_progress_inv {
            get {
                return (1 - animation_progress);
            }
        }
        private Adw.TimedAnimation ? animation;
        private bool loading_texture = false;

        private Cancellable pixbuf_cancellable = new Cancellable ();
        private BackgroundInfo ? background_info = null;
        private BackgroundInfo ? old_background_info = null;

        public Window (Gtk.Application app, Gdk.Monitor monitor) {
            Object (
                application: app,
                monitor: monitor
            );

            Adw.CallbackAnimationTarget target = new Adw.CallbackAnimationTarget (animation_value_cb);
            animation = new Adw.TimedAnimation (this, 1.0, 0.0, TRANSITION_DURATION, target);

            GtkLayerShell.init_for_window (this);
            GtkLayerShell.set_monitor (this, monitor);
            GtkLayerShell.set_layer (this, GtkLayerShell.Layer.BACKGROUND);
            GtkLayerShell.set_exclusive_zone (this, -1);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);
        }

        public async void change_wallpaper (owned Utils.Config config, Cancellable cancellable) {
            loading_texture = true;

            cancellable.connect (() => {
                pixbuf_cancellable.cancel ();
            });

            BackgroundInfo ?saved_background_info = background_info;
            BackgroundInfo ?new_background_info = background_info;
            if (new_background_info == null) {
                new_background_info = BackgroundInfo ();
            }
            new_background_info.config = config;

            if (new_background_info.config.path != null
                && new_background_info.config.path.length > 0) {
                // Cancel previous download, reset the state and download again
                pixbuf_cancellable.cancel ();
                pixbuf_cancellable.reset ();

                try {
                    File file = File.new_for_path (new_background_info.config.path);
                    uint hash = file.hash ();
                    if (old_background_info?.config?.path == new_background_info.config.path
                        && old_background_info?.file_hash == hash) {
                        return;
                    }
                    InputStream stream = yield file.read_async (Priority.DEFAULT,
                                                                pixbuf_cancellable);
                    if (pixbuf_cancellable.is_cancelled ()) {
                        pixbuf_cancellable.reset ();
                        loading_texture = false;
                        return;
                    }
                    Gdk.Pixbuf pixbuf = yield new Gdk.Pixbuf.from_stream_at_scale_async (
                        stream, monitor.geometry.width, monitor.geometry.height,
                        true, pixbuf_cancellable);
                    if (pixbuf_cancellable.is_cancelled ()) {
                        pixbuf_cancellable.reset ();
                        loading_texture = false;
                        return;
                    }

                    new_background_info.texture = Gdk.Texture.for_pixbuf (pixbuf);
                    new_background_info.width = pixbuf.width;
                    new_background_info.height = pixbuf.height;
                    new_background_info.file_hash = hash;
                } catch (Error e) {
                    stderr.printf ("Setting wallpaper error: %s\n", e.message);
                }
            }

            old_background_info = saved_background_info;
            background_info = new_background_info;
            debug ("Old background: %s\n", old_background_info?.to_string ());
            debug ("New background: %s\n", background_info?.to_string ());
        }

        // Has to be run after `change_wallpaper`
        public void run_animation () {
            loading_texture = false;

            // Start the transition
            animation.set_value_to (0);
            animation.play ();
        }

        public override void snapshot(Gtk.Snapshot snapshot) {
            // Render a black base wallpaper
            Gdk.RGBA bg_color = Gdk.RGBA () {
                red = 0.0f,
                green = 0.0f,
                blue = 0.0f,
                alpha = 1.0f,
            };

            snapshot.append_color (bg_color, { { 0, 0 }, { get_width(), get_height() } });

            if (background_info == null || loading_texture) {
                return;
            }

            if (animation.state == Adw.AnimationState.PLAYING
                && old_background_info != null) {
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

            int height = info.height;
            int width = info.width;
            switch (info.config.scale_mode) {
                case Utils.ScaleModes.FILL:
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
                case Utils.ScaleModes.FIT:
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
                case Utils.ScaleModes.STRETCH:
                    snapshot.scale((float) buffer_width / width,
                                   (float) buffer_height / height);
                    snapshot.append_scaled_texture (info.texture,
                                                    SCALING_FILTER,
                                                    { { 0, 0 }, { width, height } });
                    break;
                case Utils.ScaleModes.CENTER:
                    float x = (float) (buffer_width / 2 - width / 2);
                    float y = (float) (buffer_height / 2 - height / 2);
                    snapshot.append_scaled_texture (info.texture,
                                                    SCALING_FILTER,
                                                    { { x, y }, { width, height } });
                    break;
            }
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

            queue_draw ();
        }
    }
}
