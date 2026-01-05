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
        private Adw.TimedAnimation ?animation;

        private Queue<unowned Cancellable> cancellables = new Queue<unowned Cancellable> ();
        private BackgroundInfo ?background_info = null;
        private BackgroundInfo ?prev_background_info = null;

        public Window (Gtk.Application app, Gdk.Monitor monitor) {
            Object (
                application : app,
                monitor : monitor
            );

            Adw.CallbackAnimationTarget target =
                new Adw.CallbackAnimationTarget (animation_value_cb);
            animation = new Adw.TimedAnimation (this, 1.0, 0.0, TRANSITION_DURATION, target);

            if (!debug_no_layer_shell) {
                GtkLayerShell.init_for_window (this);
                GtkLayerShell.set_monitor (this, monitor);
                GtkLayerShell.set_namespace (this, "sway-wallpaper");
                GtkLayerShell.set_layer (this, GtkLayerShell.Layer.BACKGROUND);
                GtkLayerShell.set_exclusive_zone (this, -1);
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);
            }
        }

        public async void change_wallpaper (owned Utils.Config new_config) {
            // Cancel all currently running image loading threads,
            // and start loading the new wallpaper instead
            unowned Cancellable ?running_cancellable = null;
            while ((running_cancellable = cancellables.pop_head ()) != null) {
                running_cancellable.cancel ();
            }
            Cancellable cancellable = new Cancellable ();
            cancellables.push_tail (cancellable);

            // Texture texture = new Texture ();
            BackgroundInfo ?saved_info = background_info;
            BackgroundInfo new_info = new BackgroundInfo (new_config);

            File ?file;
            bool has_image = new_info.config.has_image (out file, cancellable);
            uint hash = 0;
            if (file != null) {
                hash = file.hash ();
            }

            // Trying to load the same file, skip.
            bool load_new_file = true;
            if (saved_info != null) {
                bool same_image = has_image && saved_info.texture != null;
                bool same_hash = saved_info.file_hash != 0 && saved_info.file_hash == hash;
                bool same_path = new_info.config.path == saved_info.config.path;
                bool same_scale = new_info.config.scale_mode == saved_info.config.scale_mode;
                // Cancel if the new wallpaper/color config is the exact same
                // as the previous wallpaper/color
                if (saved_info.config.cmp (new_info.config)
                    && same_hash
                    && same_image) {
                    cancellables.remove (cancellable);
                    return;
                }
                load_new_file = !same_hash || !same_image || !same_path || !same_scale;
            }

            // Load Image
            if (has_image && load_new_file) {
                Gdk.Rectangle geometry = monitor.get_geometry ();

                SourceFunc callback = change_wallpaper.callback;
                Gly.Frame ?frame = null;
                new Thread<void> (null, () => {
                    load_image.begin (file, geometry, cancellable, (obj, res) => {
                        frame = load_image.end (res);
                        Idle.add ((owned) callback);
                    });
                });
                yield;

                if (cancellable.is_cancelled () || frame == null) {
                    cancellables.remove (cancellable);
                    return;
                }
                new_info.file_hash = hash;
                Gdk.Texture texture = GlyGtk4.frame_get_texture (frame);
                uint32 ref_width = frame.get_width ();
                uint32 ref_height = frame.get_height ();

                // Scale the texture
                float new_width, new_height;
                Gdk.Paintable ?paintable
                    = SwaySettings.Functions.gdk_texture_scale (texture,
                                                                ref_width,
                                                                ref_height,
                                                                geometry.width,
                                                                geometry.height,
                                                                SCALING_FILTER,
                                                                out new_width,
                                                                out new_height);
                if (paintable != null) {
                    new_info.texture = paintable;
                    new_info.width = (uint32) new_width;
                    new_info.height = (uint32) new_height;
                } else {
                    new_info.texture = texture;
                    new_info.width = ref_width;
                    new_info.height = ref_height;
                }

                if (cancellable.is_cancelled ()) {
                    cancellables.remove (cancellable);
                    return;
                }
            }

            // full_texture = texture;
            prev_background_info = saved_info;
            background_info = new_info;
            debug ("Old background: %s\n", prev_background_info?.to_string ());
            debug ("New background: %s\n", background_info.to_string ());

            cancellables.remove (cancellable);

            // Start the transition
            animation.set_value_to (0);
            animation.play ();
        }

        private static async Gly.Frame ?load_image (File file,
                                                    Gdk.Rectangle geometry,
                                                    Cancellable cancellable) {
            try {
                Gly.Image image = yield new Gly.Loader (file).load_async (cancellable);
                Gly.FrameRequest frame_request = new Gly.FrameRequest ();
                frame_request.set_scale (geometry.width, geometry.height);
                return yield image.get_specific_frame_async (frame_request, cancellable);
            } catch (Error e) {
                stderr.printf ("Setting wallpaper error: %s\n", e.message);
            }
            return null;
        }

        public override void snapshot (Gtk.Snapshot snapshot) {
            // Render a black base wallpaper
            Gdk.RGBA bg_color = Gdk.RGBA () {
                red = 0.0f,
                green = 0.0f,
                blue = 0.0f,
                alpha = 1.0f,
            };

            snapshot.append_color (bg_color, { { 0, 0 }, { get_width (), get_height () } });

            if (background_info == null) {
                return;
            }

            if (animation.state == Adw.AnimationState.PLAYING
                && prev_background_info != null) {
                snapshot.push_cross_fade (animation_progress_inv);

                apply_transformed_background (snapshot, prev_background_info);
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
            uint32 height = info.height;
            uint32 width = info.width;
            switch (info.config.scale_mode) {
                case Utils.ScaleModes.FILL :
                    double window_ratio = (double) buffer_width / buffer_height;
                    double bg_ratio = width / height;
                    if (window_ratio > bg_ratio) { // Taller wallpaper than monitor
                        double scale = (double) buffer_width / width;
                        if (scale * height < buffer_height) {
                            draw_scale_wide (buffer_width, width, buffer_height, height, snapshot,
                                             info);
                        } else {
                            draw_scale_tall (buffer_width, width, buffer_height, height, snapshot,
                                             info);
                        }
                    } else { // Wider wallpaper than monitor
                        double scale = (double) buffer_height / height;
                        if (scale * width < buffer_width) {
                            draw_scale_tall (buffer_width, width, buffer_height, height, snapshot,
                                             info);
                        } else {
                            draw_scale_wide (buffer_width, width, buffer_height, height, snapshot,
                                             info);
                        }
                    }
                    break;
                case Utils.ScaleModes.FIT :
                    double window_ratio = (double) buffer_width / buffer_height;
                    double bg_ratio = width / height;
                    if (window_ratio > bg_ratio) { // Taller wallpaper than monitor
                        double scale = (double) buffer_width / width;
                        if (scale * height < buffer_height) {
                            draw_scale_tall (buffer_width, width, buffer_height, height, snapshot,
                                             info);
                        } else {
                            draw_scale_wide (buffer_width, width, buffer_height, height, snapshot,
                                             info);
                        }
                    } else { // Wider wallpaper than monitor
                        double scale = (double) buffer_height / height;
                        if (scale * width < buffer_width) {
                            draw_scale_wide (buffer_width, width, buffer_height, height, snapshot,
                                             info);
                        } else {
                            draw_scale_tall (buffer_width, width, buffer_height, height, snapshot,
                                             info);
                        }
                    }
                    break;
                case Utils.ScaleModes.STRETCH :
                    snapshot.scale ((float) buffer_width / width,
                                    (float) buffer_height / height);
                    info.texture.snapshot (snapshot, width, height);
                    break;
                case Utils.ScaleModes.CENTER :
                    float x = (float) (buffer_width / 2 - width / 2);
                    float y = (float) (buffer_height / 2 - height / 2);
                    snapshot.translate (Graphene.Point ().init (x, y));
                    info.texture.snapshot (snapshot, width, height);
                    break;
            }
        }

        private void draw_scale_tall (int buffer_width,
                                      uint32 width,
                                      int buffer_height,
                                      uint32 height,
                                      Gtk.Snapshot snapshot,
                                      BackgroundInfo info) {
            float scale = (float) buffer_width / width;
            snapshot.scale (scale, scale);
            float x = 0;
            float y = (float) (buffer_height / 2 / scale - height / 2);
            snapshot.translate (Graphene.Point ().init (x, y));
            info.texture.snapshot (snapshot, width, height);
        }

        private void draw_scale_wide (int buffer_width,
                                      uint32 width,
                                      int buffer_height,
                                      uint32 height,
                                      Gtk.Snapshot snapshot,
                                      BackgroundInfo info) {
            float scale = (float) buffer_height / height;
            snapshot.scale (scale, scale);
            float x = (float) (buffer_width / 2 / scale - width / 2);
            float y = 0;
            snapshot.translate (Graphene.Point ().init (x, y));
            info.texture.snapshot (snapshot, width, height);
        }

        void animation_value_cb (double progress) {
            animation_progress = progress;

            queue_draw ();
        }
    }
}
