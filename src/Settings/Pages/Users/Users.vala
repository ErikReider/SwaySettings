using Gee;
// https://sssd.io/design-pages/accounts_service.html
namespace SwaySettings {

    private struct Image {
        string path;
        bool correct_size;
    }

    private errordomain PathError { INVALID_PATH }

    public class Users : PageScroll {

        private UsersContent content;

        public Users (SettingsItem item, Adw.NavigationPage page) {
            base (item, page);
        }

        private ulong changed_id = 0;

        public override async void on_back (Adw.NavigationPage page) {
            if (changed_id != 0) {
                userMgr.disconnect (changed_id);
                changed_id = 0;
            }
        }

        public override Gtk.Widget set_child () {
            content = new UsersContent ();

            // Avatar EventBox
            {
                Gtk.GestureClick gesture = new Gtk.GestureClick ();
                gesture.set_button (Gdk.BUTTON_PRIMARY);
                gesture.pressed.connect (() => {
                    content.popover.popup ();
                });
                content.avatar.add_controller (gesture);
            }

            // Title Entry on press ESC
            {
                Gtk.EventControllerKey controller = new Gtk.EventControllerKey ();
                controller.key_pressed.connect ((keyval, keycode, state) => {
                    if (keyval == Gdk.Key.Escape) {
                        string text = userMgr.current_user.real_name;
                        content.title.set_text (text);
                        content.title_entry.set_text (text);
                        content.title_button.set_active (false);
                        return true;
                    }
                    return false;
                });
                content.title_entry.add_controller (controller);
            }
            // Title Entry on press Enter
            content.title_entry.activate.connect (() => {
                string text = content.title_entry.text;
                content.title.set_text (text);
                content.title_entry.set_text (text);
                if (userMgr.current_user.get_real_name () != text) {
                    userMgr.current_user.set_real_name (text);
                }
                content.title_button.set_active (false);
            });
            // Title Togglebutton on toggle
            content.title_button.toggled.connect (() => {
                bool toggle_value = content.title_button.get_active ();
                string name = toggle_value ? "entry" : "title";
                content.title_stack.set_visible_child_name (name);
                if (toggle_value) {
                    content.title_entry.set_text (userMgr.current_user.real_name);
                    content.title_entry.grab_focus_without_selecting ();
                    content.title_entry.set_position (-1);
                }
            });

            changed_id = userMgr.changed.connect (set_user_data);
            if (userMgr.current_user.is_loaded) {
                set_user_data ();
            }

            return Page.get_scroll_widget (content);
        }

        void set_user_data () {
            // Avatar
            content.avatar.set_text (userMgr.current_user.real_name);
            if (userMgr.current_user.icon_file != null
                && userMgr.current_user.icon_file.length > 0) {
                Gtk.IconPaintable paintable = new Gtk.IconPaintable.for_file (
                    File.new_for_path (userMgr.current_user.icon_file),
                    content.avatar.size,
                    1);
                content.avatar.set_custom_image (paintable);
            }

            // Title
            content.title.set_text (userMgr.current_user.real_name);
            content.title_entry.set_text (userMgr.current_user.real_name);

            // Subtitle
            string sub_string = userMgr.current_user.email;
            if (sub_string == null || sub_string.length == 0) {
                sub_string = userMgr.current_user.user_name;
            }
            content.subtitle.set_text (sub_string);

            // Subtitle2
            string user_type = userMgr.current_user.system_account ?
                               "Root User" : "Regular User";
            content.subtitle2.set_text (user_type);

            fill_popover ();
        }

        void fill_popover () {
            // Remove all children
            Gtk.Widget child = content.popover_flowbox.get_first_child ();
            while (child != null) {
                content.popover_flowbox.remove (child);
                child = content.popover_flowbox.get_first_child ();
            }

            // Add file chooser button
            var add_button = new Gtk.Button.from_icon_name ("list-add-symbolic");
            add_button.add_css_class ("circular");
            add_button.set_valign (Gtk.Align.FILL);
            add_button.set_halign (Gtk.Align.FILL);
            add_button.clicked.connect (() => {
                var image_chooser = new Gtk.FileDialog ();
                image_chooser.set_title ("Select Image");
                image_chooser.accept_label = "_Open";
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
                            Image img = Image ();
                            int w, h;
                            Gdk.PixbufFormat ? format = Gdk.Pixbuf.get_file_info (
                                path, out w, out h);
                            if (format != null) {
                                img.path = path;
                                img.correct_size = w == 96 && h == 96;
                                set_user_img (img);
                            }
                        }
                    } catch (Error e) {
                        debug (e.message);
                    }
                });
            });
            content.popover_flowbox.append (add_button);

            // Add all children
            string[] avatar_locations = {
                "/usr/share/plasma/avatars",
                "/usr/share/pixmaps/faces"
            };

            string[] supported_formats = { "jpg" };
            Gdk.Pixbuf.get_formats ().foreach (
                (v) => supported_formats += v.get_name ());

            unowned int depth = 0;
            foreach (string location in avatar_locations) {
                get_avatars_in_path (location, supported_formats, depth, 3);
            }
        }

        void get_avatars_in_path (string location, string[] formats,
                                  int depth, int max_depth = -1) {
            Functions.walk_through_dir (location, (info, file) => {
                string path = Path.build_filename (file.get_path (),
                                                   info.get_name ());
                switch (info.get_file_type ()) {
                    case FileType.DIRECTORY:
                        // Limit the search depth
                        if (depth < max_depth) {
                            depth++;
                            get_avatars_in_path (path, formats,
                                                 depth, max_depth);
                        }
                        break;
                    case FileType.REGULAR:
                        string suffix = path.slice (
                            path.last_index_of_char ('.') + 1,
                            path.length);
                        if (suffix in formats) {
                            content.popover_flowbox.append (
                                new PopoverImage (path, set_user_img));
                        }
                        break;
                    default:
                        return;
                }
            });
        }

        // TODO: Implement image cropping/centering instead of squishing the image
        void set_user_img (Image img) {
            try {
                var pixbuf = new Gdk.Pixbuf.from_file (img.path);
                if (!img.correct_size) {
                    pixbuf = pixbuf.scale_simple (
                        96, 96, Gdk.InterpType.BILINEAR);
                }
                string new_path = Path.build_filename (
                    Environment.get_home_dir (), ".face");
                pixbuf.save (new_path, "jpeg");
                pixbuf.dispose ();

                userMgr.current_user.set_icon_file (new_path);
                content.popover.popdown ();
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
        }
    }

    [GtkTemplate (ui = "/org/erikreider/swaysettings/ui/Users.ui")]
    private class UsersContent : Adw.Bin {
        [GtkChild]
        public unowned Adw.Avatar avatar;

        [GtkChild]
        public unowned Gtk.Stack title_stack;
        [GtkChild]
        public unowned Gtk.ToggleButton title_button;
        [GtkChild]
        public unowned Gtk.Label title;
        [GtkChild]
        public unowned Gtk.Entry title_entry;

        [GtkChild]
        public unowned Gtk.Label subtitle;
        [GtkChild]
        public unowned Gtk.Label subtitle2;

        [GtkChild]
        public unowned Gtk.Popover popover;
        [GtkChild]
        public unowned Gtk.FlowBox popover_flowbox;
    }

    private class PopoverImage : Adw.Bin {
        const int SIZE = 64;

        public delegate void On_click (Image img);

        public PopoverImage (string path, On_click cb) {
            if (path == null || path.length == 0) {
                this.destroy ();
                return;
            }

            Image img = Image ();

            try {
                if (path == null || path.length == 0) {
                    throw new PathError.INVALID_PATH ("The image path is invalid!");
                }
                int w, h;
                Gdk.Pixbuf.get_file_info (path, out w, out h);
                img.path = path;
                img.correct_size = w == 96 && h == 96;

                Gtk.IconPaintable paintable = new Gtk.IconPaintable.for_file (
                    File.new_for_path (path), SIZE, 1);
                var img_surf = new Adw.Avatar (SIZE, null, false);
                img_surf.set_custom_image (paintable);
                set_child (img_surf);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
                this.destroy ();
                return;
            }

            Gtk.GestureClick gesture = new Gtk.GestureClick ();
            gesture.set_button (Gdk.BUTTON_PRIMARY);
            gesture.pressed.connect (() => cb (img));
            add_controller (gesture);
        }
    }
}
