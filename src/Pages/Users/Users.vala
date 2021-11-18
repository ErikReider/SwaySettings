using Gee;
// https://sssd.io/design-pages/accounts_service.html
namespace SwaySettings {

    private struct Image {
        string path;
        bool correct_size;
    }

    private errordomain PathError { INVALID_PATH }

    public class Users : Page_Scroll {
        private unowned Act.UserManager user_manager = Act.UserManager.get_default ();
        private unowned Act.User current_user;

        private Users_Content content;

        public Users (string label, Hdy.Deck deck, IPC ipc) {
            base (label, deck, ipc);
        }

        public override Gtk.Widget set_child () {
            string username = GLib.Environment.get_user_name ();
            content = new Users_Content ();

            // Avatar EventBox
            content.avatar_event_box.button_press_event.connect (() => {
                content.popover.popup ();
                return true;
            });

            // Title Entry on press ESC
            content.title_entry.key_press_event.connect ((_, eventKey) => {
                if (eventKey.keyval == Gdk.Key.Escape) {
                    string text = current_user.real_name;
                    content.title.set_text (text);
                    content.title_entry.set_text (text);
                    content.title_button.set_active (false);
                }
                return false;
            });
            // Title Entry on press Enter
            content.title_entry.activate.connect (() => {
                string text = content.title_entry.text;
                content.title.set_text (text);
                content.title_entry.set_text (text);
                if (current_user.get_real_name () != text) {
                    current_user.set_real_name (text);
                }
                content.title_button.set_active (false);
            });
            // Title Togglebutton on toggle
            content.title_button.toggled.connect (() => {
                bool toggle_value = content.title_button.get_active ();
                string name = toggle_value ? "entry" : "title";
                content.title_stack.set_visible_child_name (name);
                if (toggle_value) {
                    content.title_entry.set_text (current_user.real_name);
                    content.title_entry.grab_focus_without_selecting ();
                    content.title_entry.set_position (-1);
                }
            });

            if (current_user == null || !current_user.is_loaded) {
                current_user = user_manager.get_user (username);
                current_user.notify["is-loaded"].connect (set_user_data);
                current_user.changed.connect (set_user_data);
            } else {
                set_user_data ();
            }

            return Page.get_scroll_widget (content);
        }

        void set_user_data () {
            // Avatar
            content.avatar.set_text (current_user.real_name);
            if (current_user.icon_file != null
                && current_user.icon_file.length > 0) {
                // Compat with older versions
                content.avatar.set_image_load_func ((size) => {
                    try {
                        return new Gdk.Pixbuf.from_file_at_size (
                            current_user.icon_file, size, size);
                    } catch (Error e) {
                        stderr.printf ("ERROR: %s \n", e.message);
                        return null;
                    }
                });
            }

            // Title
            content.title.set_text (current_user.real_name);
            content.title_entry.set_text (current_user.real_name);

            // Subtitle
            string sub_string = current_user.email;
            if (sub_string == null || sub_string.length == 0) {
                sub_string = current_user.user_name;
            }
            content.subtitle.set_text (sub_string);

            // Subtitle2
            string user_type = current_user.system_account ?
                               "Root User" : "Regular User";
            content.subtitle2.set_text (user_type);

            fill_popover ();
        }

        void fill_popover () {
            // Remove all children
            foreach (var child in content.popover_flowbox.get_children ()) {
                content.popover_flowbox.remove (child);
            }

            // Add file chooser button
            var add_button = new Gtk.Button.from_icon_name ("list-add-symbolic",
                                                            Gtk.IconSize.DND);
            add_button.get_style_context ().add_class ("circular");
            add_button.clicked.connect (() => {
                var image_chooser = new Gtk.FileChooserNative (
                    "Select Image",
                    (Gtk.Window)get_toplevel (),
                    Gtk.FileChooserAction.OPEN,
                    "_Open",
                    "_Cancel");
                // Only show images
                var filter = new Gtk.FileFilter ();
                filter.add_mime_type ("image/*");
                image_chooser.set_filter (filter);
                // Run and get result
                int res = image_chooser.run ();
                if (res == Gtk.ResponseType.ACCEPT) {
                    string ? path = image_chooser.get_filename ();
                    if (path != null) {
                        Image img = Image ();
                        int w, h;
                        Gdk.Pixbuf.get_file_info (path, out w, out h);
                        img.path = path;
                        img.correct_size = w == 96 && h == 96;
                        set_user_img (img);
                    }
                }
                image_chooser.destroy ();
            });
            content.popover_flowbox.add (add_button);

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
            content.popover_flowbox.show_all ();
        }

        void get_avatars_in_path (string location, string[] formats,
                                  int depth, int max_depth = -1) {
            Functions.walk_through_dir (location, (info, file) => {
                string path = Path.build_filename (file.get_path (),
                                                   info.get_name ());
                switch (info.get_file_type ()) {
                    case FileType.DIRECTORY :
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
                            content.popover_flowbox.add (
                                new Popover_Image (path, set_user_img));
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

                current_user.set_icon_file (new_path);
                content.popover.popdown ();
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
        }
    }

    [GtkTemplate (ui = "/org/erikreider/swaysettings/Pages/Users/Users.ui")]
    private class Users_Content : Gtk.Box {
        [GtkChild]
        public unowned Gtk.EventBox avatar_event_box;
        [GtkChild]
        public unowned Hdy.Avatar avatar;

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

    private class Popover_Image : Gtk.EventBox {
        public delegate void On_click (Image img);

        public Popover_Image (string path, On_click cb) {
            if (path == null || path.length == 0) {
                this.destroy ();
                this.dispose ();
                return;
            }

            Image img = Image ();

            const int size = 64;
            const int h_size = 32;
            try {
                if (path == null || path.length == 0) {
                    throw new PathError.INVALID_PATH ("The image path is invalid!");
                }
                int w, h;
                Gdk.Pixbuf.get_file_info (path, out w, out h);
                img.path = path;
                img.correct_size = w == 96 && h == 96;

                var pixbuf = new Gdk.Pixbuf.from_file_at_size (path, size, size);

                var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, size, size);
                var ctx = new Cairo.Context (surface);
                Gdk.cairo_set_source_pixbuf (ctx, pixbuf, 0, 0);

                ctx.arc (h_size, h_size, h_size, 0, 2 * Math.PI);
                ctx.clip ();
                ctx.paint ();
                var img_surf = new Gtk.Image.from_surface (surface);
                this.add (img_surf);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
                this.hide ();
                this.destroy ();
                return;
            }

            this.button_press_event.connect (() => {
                cb (img);
                return false;
            });

            this.show_all ();
        }
    }
}
