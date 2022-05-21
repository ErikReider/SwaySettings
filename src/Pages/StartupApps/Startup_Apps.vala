using Gee;

namespace SwaySettings {
    public class Startup_Apps : Page_Scroll {

        Gtk.ListBox list_box;

        ArrayList<DesktopAppInfo> startup_apps;

        public Startup_Apps (string page_label, Hdy.Deck deck) {
            base (page_label, deck);
        }

        public override Gtk.Widget set_child () {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            list_box = new Gtk.ListBox ();
            list_box.selection_mode = Gtk.SelectionMode.NONE;
            list_box.get_style_context ().add_class ("content");
            add_apps ();

            var add_button = new Gtk.Button.with_label ("Add Application");
            add_button.clicked.connect ((e) => {
                var window = (SwaySettings.Window)get_toplevel ();
                new Desktop_App_Chooser (window, (desktop) => {
                    add_app_to_startup.begin (desktop.filename, () => {
                        refresh_apps ();
                    });
                });
            });

            box.add (list_box);
            box.add (add_button);
            return box;
        }

        void add_apps () {
            startup_apps = get_startup_apps ();
            foreach (var app_info in startup_apps) {
                list_box.add (new Startup_Apps_Item (app_info, (a_info) => {
                    remove_app_from_startup.begin (
                        a_info.get_filename (),
                        () => refresh_apps ());
                }));
            }
            list_box.show_all ();
        }

        void refresh_apps () {
            list_box.foreach ((element) => list_box.remove (element));
            add_apps ();
        }

        ArrayList<DesktopAppInfo> get_startup_apps () {
            ArrayList<DesktopAppInfo> apps = new ArrayList<DesktopAppInfo>();
            string auto_start_path = @"$(Environment.get_user_config_dir())/autostart";
            Functions.walk_through_dir (auto_start_path, (file_info) => {
                // Implement "X-GNOME-Autostart-enabled" check???
                var app_path = @"$(auto_start_path)/$(file_info.get_name())";
                var app = new DesktopAppInfo.from_filename (app_path);
                if (app == null) return;
                apps.add (app);
            });
            return apps;
        }

        async void add_app_to_startup (string file_path) {
            try {
                string dest_path = Path.build_path (
                    "/",
                    Environment.get_user_config_dir (),
                    "autostart",
                    Path.get_basename (file_path));

                File file = File.new_for_path (file_path);
                File file_dest = File.new_for_path (dest_path);

                if (!file.query_exists ()) {
                    stderr.printf (
                        "File %s not found or permissions missing",
                        file_path);
                    return;
                }
                file.copy (file_dest, GLib.FileCopyFlags.OVERWRITE);
            } catch (Error e) {
                stderr.printf ("%s\n", e.message);
            }
        }

        async void remove_app_from_startup (string file_path) {
            try {
                File file = File.new_for_path (file_path);
                if (!file.query_exists ()) {
                    stderr.printf (
                        "File %s not found or permissions missing",
                        file_path);
                    return;
                }
                file.delete ();
            } catch (Error e) {
                stderr.printf ("%s\n", e.message);
            }
        }
    }

    [GtkTemplate (ui = "/org/erikreider/swaysettings/Pages/StartupApps/Startup_Apps_Item.ui")]
    class Startup_Apps_Item : Gtk.ListBoxRow {

        [GtkChild]
        unowned Gtk.Image image;

        [GtkChild]
        unowned Gtk.Label title;
        [GtkChild]
        unowned Gtk.Label subtitle;

        [GtkChild]
        unowned Gtk.Button button;

        public delegate void on_remove (DesktopAppInfo app_info);

        public Startup_Apps_Item (DesktopAppInfo app_info, on_remove callback) {
            Object ();
            image.set_from_gicon (app_info.get_icon (), Gtk.IconSize.DND);
            title.set_text (app_info.get_display_name ());
            subtitle.set_text (app_info.get_commandline ());

            button.clicked.connect (() => callback (app_info));
        }
    }

    [GtkTemplate (ui = "/org/erikreider/swaysettings/Pages/StartupApps/Startup_Apps_Chooser.ui")]
    class Desktop_App_Chooser : Hdy.Window {

        Gtk.ListStore liststore = new Gtk.ListStore (3,
                                                     typeof (string),
                                                     typeof (string),
                                                     typeof (int));

        [GtkChild]
        unowned Gtk.TreeView tree_view;

        [GtkChild]
        unowned Gtk.Button save_button;

        [GtkChild]
        unowned Gtk.Button cancel_button;

        ArrayList<DesktopAppInfo> apps = new ArrayList<DesktopAppInfo>();

        public delegate void on_selected (DesktopAppInfo app_info);

        public Desktop_App_Chooser (SwaySettings.Window window,
                                    on_selected callback) {
            Object ();
            this.set_attached_to (window);
            this.set_transient_for (window);

            tree_view.set_model (liststore);

            cancel_button.clicked.connect (() => this.close ());
            tree_view.row_activated.connect (() => {
                callback (get_selected ());
                this.close ();
            });
            save_button.clicked.connect (() => {
                var selection = get_selected ();
                if (selection != null) {
                    callback (selection);
                    this.close ();
                }
            });

            var icon_column = new Gtk.TreeViewColumn.with_attributes (
                "icon",
                new Gtk.CellRendererPixbuf (),
                "icon_name",
                1);
            var name_column = new Gtk.TreeViewColumn.with_attributes (
                "name",
                new Gtk.CellRendererText (),
                "text",
                0);

            tree_view.append_column (icon_column);
            tree_view.append_column (name_column);

            populate_list ();

            this.show_all ();
        }

        void populate_list () {
            var all_apps = GLib.AppInfo.get_all ();
            all_apps.sort ((a, b) => {
                if (a.get_display_name () == b.get_display_name ()) return 0;
                return a.get_display_name () > b.get_display_name () ? 1 : -1;
            });
            for (uint index = 0, shown_index = 0; index < all_apps.length (); index++) {
                var app_val = all_apps.nth_data (index);
                var app = new DesktopAppInfo (app_val.get_id ());
                if (app.should_show () && !app.get_is_hidden ()) {
                    apps.add (app);
                    var app_icon = "gtk-missing-icon";
                    if (app.get_icon () != null) {
                        app_icon = app.get_icon ().to_string ();
                    }
                    Gtk.TreeIter iter;
                    liststore.append (out iter);
                    liststore.set (iter, 0, app.get_display_name (), 1,
                                   app_icon, 2, shown_index++);
                }
            }
        }

        DesktopAppInfo ? get_selected () {
            var selection = tree_view.get_selection ();
            Gtk.TreeModel tree_model;
            Gtk.TreeIter tree_iter;
            selection.get_selected (out tree_model, out tree_iter);
            GLib.Value app_index;
            if (tree_iter.user_data == null) return null;
            tree_model.get_value (tree_iter, 2, out app_index);
            if (!app_index.holds (typeof (int))) return null;
            return apps[app_index.get_int ()];
        }
    }
}
