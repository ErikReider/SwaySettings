using Gee;
using Utils;

namespace SwaySettings {
    public class StartupApps : PageScroll {
        public string autostart_path { private get; construct; }

        Gtk.ListBox list_box;

        ListStore list_store;

        construct {
            autostart_path = Path.build_path (Path.DIR_SEPARATOR_S,
                                               Environment.get_user_config_dir (),
                                               "autostart");

            list_store = new ListStore (typeof (DesktopAppInfo));
        }

        public StartupApps (SettingsItem item, Adw.NavigationPage page) {
            base (item, page);
        }

        public override Gtk.Widget set_child () {
            repopulate_startup_apps ();

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            list_box = new Gtk.ListBox ();
            list_box.selection_mode = Gtk.SelectionMode.NONE;
            list_box.add_css_class ("content");
            list_box.bind_model (list_store, list_box_create_widget_cb);

            var add_button = new Gtk.Button.with_label ("Add Application");
            add_button.add_css_class ("pill");
            add_button.set_halign (Gtk.Align.CENTER);
            add_button.clicked.connect (add_app_to_startup);

            box.append (list_box);
            box.append (add_button);
            return box;
        }

        Gtk.Widget list_box_create_widget_cb (Object obj) {
            DesktopAppInfo app_info = (DesktopAppInfo) obj;
            StartupAppsRow row = new StartupAppsRow (app_info);
            row.remove_clicked.connect (remove_app_from_startup);
            return row;
        }

        void repopulate_startup_apps () {
            list_store.remove_all ();

            Fs.walk_through_dir (autostart_path, (file_info, dir) => {
                // TODO: Implement "X-GNOME-Autostart-enabled" check???
                string app_path = Path.build_path (Path.DIR_SEPARATOR_S,
                                                   dir.get_path (), file_info.get_name ());
                var app_info = new DesktopAppInfo.from_filename (app_path);
                if (app_info == null) {
                    return;
                }
                list_store.append (app_info);
            });
        }

        async void add_app_to_startup () {
            // Pick a application
            var dialog = new AppChooserDialog (null);
            DesktopAppInfo ?app_info = yield dialog.choose (get_root ());

            if (app_info == null) {
                return;
            }

            // Add the picked application to the autostart directory
            try {
                string app_path = app_info.get_filename ();
                File app_file = File.new_for_path (app_path);
                if (!app_file.query_exists ()) {
                    throw new IOError.NOT_FOUND (
                              "File %s not found or permissions missing".printf (app_path));
                }

                string dest_path = Path.build_path (Path.DIR_SEPARATOR_S,
                                                    autostart_path,
                                                    Path.get_basename (app_path));
                File file_dest = File.new_for_path (dest_path);
                if (file_dest.query_exists ()) {
                    throw new IOError.EXISTS (
                              "File %s already exists!".printf (app_path));
                }

                app_file.copy (file_dest, FileCopyFlags.NONE);
            } catch (Error e) {
                critical ("add_app_to_startup error: %s", e.message);
            }

            repopulate_startup_apps ();
        }

        void remove_app_from_startup (DesktopAppInfo app_info) {
            try {
                string file_path = app_info.get_filename ();
                File file = File.new_for_path (file_path);
                if (!file.query_exists ()) {
                    throw new IOError.NOT_FOUND (
                              "File %s not found or permissions missing".printf (file_path));
                }
                file.delete ();
            } catch (Error e) {
                critical ("remove_app_from_startup error: %s", e.message);
            }

            repopulate_startup_apps ();
        }
    }
}
