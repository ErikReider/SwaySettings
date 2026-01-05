namespace SwaySettings {
    public struct Wallpaper {
        string path;
        string thumbnail_path;
        bool thumbnail_valid;
    }

    public class BackgroundPage : PageScroll {
        private ThumbnailImage preview_image;
        private const int PREVIEW_IMAGE_HEIGHT = 216;
        private const int PREVIEW_IMAGE_WIDTH = 384;
        private const int LIST_IMAGE_HEIGHT = 135;
        private const int LIST_IMAGE_WIDTH = 180;

        private const int SPACING = 16;

        private Queue<unowned ThumbnailImage> load_images = new Queue<unowned ThumbnailImage> ();

        private static Wallpaper current_wallpaper = Wallpaper () {
            path = Path.build_path (Path.DIR_SEPARATOR_S,
                                    Environment.get_user_config_dir (),
                                    "swaysettings-wallpaper"),
            thumbnail_path = "",
            thumbnail_valid = false,
        };

        private static Utils.ScaleModes scaling_mode = Utils.get_scale_mode_gschema (self_settings);

        private Gtk.FlowBox ? user_flow_box;
        private Gtk.FlowBox ? sys_flow_box;

        public override int clamp_max {
            get {
                return 1200;
            }
        }

        private void connect_wallpaper_listener () {
            self_settings.changed[Constants.SETTINGS_WALLPAPER_PATH]
             .connect (on_user_wallpapers_change);
        }

        private void disconnect_wallpaper_listener () {
            self_settings.changed[Constants.SETTINGS_WALLPAPER_PATH]
             .disconnect (on_user_wallpapers_change);
        }

        construct {
            self_settings.changed[Constants.SETTINGS_USER_WALLPAPERS]
                .connect (on_user_wallpapers_change);
            self_settings.changed[Constants.SETTINGS_WALLPAPER_SCALING_MODE]
                .connect (on_user_wallpapers_change);
            connect_wallpaper_listener ();
        }

        ~BackgroundPage () {
            self_settings.changed[Constants.SETTINGS_USER_WALLPAPERS]
                .disconnect (on_user_wallpapers_change);
            self_settings.changed[Constants.SETTINGS_WALLPAPER_SCALING_MODE]
                .disconnect (on_user_wallpapers_change);
            disconnect_wallpaper_listener ();
        }

        public BackgroundPage (SettingsItem item, Adw.NavigationPage page) {
            base (item, page);
        }

        public override Gtk.Widget set_child () {
            lock (load_images) {
                load_images.clear ();
            }

            Gtk.Box content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);

            preview_image = new ThumbnailImage (current_wallpaper,
                                                PREVIEW_IMAGE_HEIGHT,
                                                PREVIEW_IMAGE_WIDTH,
                                                scaling_mode,
                                                false) {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.START,
                vexpand = false,
                hexpand = false,
                width_request = PREVIEW_IMAGE_WIDTH,
                height_request = PREVIEW_IMAGE_HEIGHT,
            };
            content_box.append (preview_image);

            content_box.append (get_scale_mode_container ());

            Gtk.Box wallpaper_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 16);
            content_box.append (wallpaper_box);

            // User Wallpapers
            Adw.PreferencesGroup user_wallpapers = get_wallpaper_container (
                "User Wallpapers", get_user_wallpapers (), out user_flow_box, true);
            wallpaper_box.append (user_wallpapers);

            // System Wallpapers
            Adw.PreferencesGroup sys_wallpapers = get_wallpaper_container (
                "System Wallpapers", get_system_wallpapers (), out sys_flow_box);
            wallpaper_box.append (sys_wallpapers);

            load_batched_images.begin ();

            return content_box;
        }

        // TODO: Don't refresh, manually check the diff?
        private void on_user_wallpapers_change () {
            this.on_refresh ();
        }

        private void refresh_selected_wallpaper (string selected_path) {
            // string selected_path = preview_image.wallpaper.path;
            preview_image.refresh_image.begin ();
            // Change the selected row
            Gtk.FlowBox[] boxes = { user_flow_box, sys_flow_box };
            foreach (Gtk.FlowBox flow_box in boxes) {
                if (flow_box == null) continue;
                flow_box.unselect_all ();
                unowned Gtk.Widget ? widget = flow_box.get_first_child ();
                if (widget == null) {
                    continue;
                }
                do {
                    if (widget is Gtk.FlowBoxChild) {
                        Gtk.FlowBoxChild child = (Gtk.FlowBoxChild) widget;
                        ThumbnailImage img = (ThumbnailImage) child.get_child ();
                        if (selected_path == img.wallpaper.path) {
                            flow_box.select_child (child);
                            break;
                        }
                    }
                    widget = widget.get_next_sibling ();
                } while (widget != null && widget != flow_box.get_first_child ());
            }
        }

        private void add_user_wallpaper () {
            var image_chooser = new Gtk.FileDialog ();
            image_chooser.set_title ("Select Image");
            image_chooser.accept_label = "_Open";
            // // Only show images
            var filter = new Gtk.FileFilter ();
            filter.add_mime_type ("image/*");
            filter.add_pixbuf_formats ();
            image_chooser.set_default_filter (filter);

            image_chooser.open.begin ((Gtk.Window) get_root (), null, (obj, result) => {
                if (obj == null) {
                    return;
                }
                Gtk.FileDialog dialog = (Gtk.FileDialog) obj;
                try {
                    File file = dialog.open.end (result);
                    string ? path = file.get_path ();
                    if (path != null) {
                        int w, h;
                        Gdk.PixbufFormat ? format = Gdk.Pixbuf.get_file_info (
                            path, out w, out h);
                        string[] paths = get_user_wallpaper_paths ();
                        if (format != null && !(path in paths)) {
                            paths += path;
                            Functions.set_gsetting (self_settings,
                                                    Constants.SETTINGS_USER_WALLPAPERS,
                                                    new Variant.strv (paths));
                        }
                    }
                } catch (Error e) {
                    debug (e.message);
                }
            });
        }

        private void remove_user_wallpaper (Wallpaper wallpaper) {
            string[] paths = get_user_wallpaper_paths ();
            if (wallpaper.path in paths) {
                string[] wallpapers = {};
                foreach (string path in paths) {
                    if (path != wallpaper.path) {
                        wallpapers += path;
                    }
                }
                Functions.set_gsetting (self_settings,
                                        Constants.SETTINGS_USER_WALLPAPERS,
                                        new Variant.strv (wallpapers));
            }
        }

        Adw.PreferencesGroup get_scale_mode_container () {
            Utils.ScaleModes[] modes = {
                Utils.ScaleModes.FILL,
                Utils.ScaleModes.STRETCH,
                Utils.ScaleModes.FIT,
                Utils.ScaleModes.CENTER,
            };

            Adw.PreferencesGroup pref_group = new Adw.PreferencesGroup ();

            ListStore liststore = new ListStore (typeof(Gtk.StringObject));

            Adw.ComboRow combo_row = new Adw.ComboRow ();
            pref_group.add (combo_row);
            combo_row.set_model (liststore);
            combo_row.set_title ("Scaling Mode");

            Gtk.PropertyExpression expression = new Gtk.PropertyExpression (
                typeof(Gtk.StringObject), null, "string");
            combo_row.set_expression (expression);

            for (int i = 0; i < modes.length; i++) {
                var mode = modes[i];
                liststore.append (new Gtk.StringObject (mode.to_title ()));
                if (mode == scaling_mode) {
                    combo_row.set_selected (i);
                }
            }

            combo_row.notify["selected-item"].connect (
                (sender, property) => {
                Utils.ScaleModes mode = modes[((int)((Adw.ComboRow) sender).get_selected ())];
                set_scale_mode (mode);
            });

            return pref_group;
        }

        Adw.PreferencesGroup get_wallpaper_container (string title,
                                                      Wallpaper[] wallpapers,
                                                      out Gtk.FlowBox ? flow_box,
                                                      bool add_button = false) {
            var group = new Adw.PreferencesGroup ();
            group.title = title;

            // Adds a Add Image Button
            if (add_button) {
                var add_row = new Adw.PreferencesRow () {
                    activatable = false,
                    can_focus = false,
                };
                var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                    halign = Gtk.Align.CENTER,
                    margin_top = SPACING,
                    margin_bottom = SPACING,
                    margin_start = SPACING,
                    margin_end = SPACING,
                };
                var button = new Gtk.Button.with_label ("Add Wallpaper");
                button.add_css_class ("pill");
                button.clicked.connect (this.add_user_wallpaper);
                box.append (button);
                add_row.set_child (box);
                group.add (add_row);
            }

            var row = new Adw.PreferencesRow () {
                activatable = false,
                can_focus = false,
            };
            group.add (row);

            if (wallpapers.length == 0) {
                var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                    sensitive = false,
                    vexpand = true,
                    valign = Gtk.Align.CENTER,
                    margin_top = SPACING,
                    margin_bottom = SPACING,
                    margin_start = SPACING,
                    margin_end = SPACING,
                };
                var img = new Gtk.Image.from_icon_name ("image-missing-symbolic") {
                    pixel_size = 96,
                };
                box.append (img);
                box.append (new Gtk.Label ("No wallpapers found..."));
                row.set_child (box);
                flow_box = null;
                return group;
            }

            flow_box = new Gtk.FlowBox () {
                max_children_per_line = 8,
                min_children_per_line = 1,
                homogeneous = true,
                margin_top = SPACING,
                margin_bottom = SPACING,
                margin_start = SPACING,
                margin_end = SPACING,
                activate_on_single_click = true,
                selection_mode = Gtk.SelectionMode.SINGLE,
                row_spacing = SPACING,
                column_spacing = SPACING,
            };
            flow_box.child_activated.connect ((widget) => {
                unowned Gtk.Widget? child = widget.get_child ();
                if (!(child is ThumbnailImage)) return;
                ThumbnailImage img = (ThumbnailImage) child;
                if (img.image_path != null) {
                    disconnect_wallpaper_listener ();
                    Functions.set_wallpaper (img.wallpaper.path, self_settings);
                    refresh_selected_wallpaper (img.wallpaper.path);
                    connect_wallpaper_listener ();
                }
            });
            row.set_child (flow_box);

            add_images (wallpapers, flow_box, add_button);
            return group;
        }

        void add_images (owned Wallpaper[] paths, Gtk.FlowBox flow_box, bool remove_button) {
            string ? path = Utils.get_wallpaper_gschema (self_settings);

            bool checked_folder_exists = false;
            foreach (var wp in paths) {
                ThumbnailImage item = new ThumbnailImage.batch (
                    wp,
                    LIST_IMAGE_HEIGHT, LIST_IMAGE_WIDTH,
                    scaling_mode,
                    ref checked_folder_exists,
                    remove_button,
                    0);
                item.on_remove_click.connect (remove_user_wallpaper);
                var f_child = new Gtk.FlowBoxChild () {
                    vexpand = true,
                    hexpand = true,
                    valign = Gtk.Align.CENTER,
                    halign = Gtk.Align.CENTER,
                };
                f_child.set_child (item);
                f_child.add_css_class ("background-flowbox-child");

                flow_box.append (f_child);
                if (wp.path == path) flow_box.select_child (f_child);

                item.on_set_image.connect ((visible) => {
                    // Hide if unable to set image
                    f_child.set_visible (visible);
                });

                load_images.push_tail (item);
            }
        }

        // Load all the Thumbnails in batches to not overload the system
        private async void load_batched_images (uint max_batch_size = 20) {
            while (true) {
                uint counter = 0;
                lock (load_images) {
                    if (load_images.is_empty ()) {
                        break;
                    }
                    uint batch_size = uint.min (max_batch_size, load_images.length);
                    counter = batch_size;
                    for (uint i = 0; i < batch_size; i++) {
                        unowned ThumbnailImage ?image = load_images.pop_head ();
                        if (image == null) {
                            AtomicUint.dec_and_test (ref counter);
                            continue;
                        }
                        image.refresh_image.begin ((obj, result) => {
                            if (AtomicUint.dec_and_test (ref counter)) {
                                load_batched_images.callback ();
                            }
                        });
                    }
                }
                yield;
            }
        }

        private Wallpaper get_wallpaper_from_path (string path) {
            Wallpaper wp = Wallpaper ();
            wp.path = path;
            try {
                string[] required = {
                    FileAttribute.THUMBNAIL_PATH,
                    FileAttribute.THUMBNAIL_IS_VALID
                };
                var info = File.new_for_path (wp.path).query_info (
                    string.joinv (",", required),
                    FileQueryInfoFlags.NONE);
                string thumb_path = info.get_attribute_as_string (
                    FileAttribute.THUMBNAIL_PATH);
                bool thumb_valid = info.get_attribute_boolean (
                    FileAttribute.THUMBNAIL_IS_VALID);
                wp.thumbnail_path = thumb_path;
                wp.thumbnail_valid = thumb_valid;
                if (thumb_path == null) {
                    thumb_valid = false;
                }
            } catch (Error e) {
                stderr.printf ("Error: %s\n", e.message);
                wp.thumbnail_valid = false;
            }
            return wp;
        }

        private void set_scale_mode (Utils.ScaleModes mode) {
            scaling_mode = mode;
            Functions.set_gsetting (self_settings,
                Constants.SETTINGS_WALLPAPER_SCALING_MODE,
                mode);
            if (Utils.wallpaper_application_registered ()) {
                Utils.Config config = Utils.Config() {
                    path = current_wallpaper.path,
                    scale_mode = scaling_mode,
                };
                Utils.wallpaper_application.activate_action (Constants.WALLPAPER_ACTION_NAME, config);
            }
        }

        private string[] get_user_wallpaper_paths () {
            Variant ? variant = Functions.get_gsetting (
                self_settings,
                Constants.SETTINGS_USER_WALLPAPERS,
                VariantType.STRING_ARRAY);
            if (variant == null
                || !variant.get_type ().equal (VariantType.STRING_ARRAY)) {
                return {};
            }
            return variant.dup_strv ();
        }

        private Wallpaper[] get_user_wallpapers () {
            Wallpaper[] wallpapers = {};
            string[] paths = get_user_wallpaper_paths ();
            foreach (string path in paths) {
                wallpapers += get_wallpaper_from_path (path);
            }
            return wallpapers;
        }

        private Wallpaper[] get_system_wallpapers () {
            string[] default_paths = {
                "/usr/share/backgrounds",
                "/usr/share/wallpapers",
                "/usr/local/share/wallpapers",
                "/usr/local/share/backgrounds",
            };

            string[] formats = { "jpg" };
            Gdk.Pixbuf.get_formats ().foreach ((fmt) => formats += fmt.get_name ());

            Wallpaper[] wallpaper_paths = {};
            for (int i = 0; i < default_paths.length; i++) {
                string path = default_paths[i];
                Functions.walk_through_dir (path, (file_info, file) => {
                    switch (file_info.get_file_type ()) {
                        case FileType.REGULAR:
                            if (file_info.get_is_hidden ()
                                || file_info.get_is_backup ()
                                || file_info.get_is_symlink ()) {
                                return;
                            }
                            string name = file_info.get_name ();
                            string suffix = name.slice (
                                name.last_index_of_char ('.') + 1,
                                name.length);
                            if (!(suffix in formats)) return;

                            string wp_path = Path.build_path (
                                Path.DIR_SEPARATOR_S,
                                path,
                                file_info.get_name ());
                            wallpaper_paths += get_wallpaper_from_path (wp_path);
                            break;
                        case FileType.DIRECTORY:
                            default_paths += Path.build_path (
                                Path.DIR_SEPARATOR_S,
                                path,
                                file_info.get_name ());
                            break;
                        default:
                            break;
                    }
                });
            }
            return wallpaper_paths;
        }
    }
}
