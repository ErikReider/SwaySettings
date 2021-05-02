/* window.vala
 *
 * Copyright 2021 Erik Reider
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gee;

namespace SwaySettings {
    public class Startup_Apps : Page_Tab {

        ArrayList<DesktopAppInfo> startup_apps;

        public Startup_Apps (string tab_label) {
            base (tab_label);

            startup_apps = Functions.get_startup_apps ();

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            var list_box = new Gtk.ListBox ();
            list_box.selection_mode = Gtk.SelectionMode.NONE;
            list_box.get_style_context ().add_class ("content");
            foreach (var app_info in startup_apps) {
                list_box.add (new Startup_Apps_Item (app_info));
            }
            list_box.show_all ();

            var add_button = new Gtk.Button.with_label ("Add Application");
            add_button.clicked.connect ((e) => {
                var window = (SwaySettings.Window)get_toplevel ();
                // var dialog = new Gtk.AppChooserDialog(window, Gtk.DialogFlags.MODAL, null);
                // Gtk.Window ? window = get_root_window ().get_screen ().get_active_window ();
                // if (window == null) return;
                var dialog = new Desktop_App_Chooser (window);
                dialog.show_all ();
            });


            box.add (list_box);
            box.add (add_button);
            this.add (Page.get_scroll_widget (box));
        }
    }

    [GtkTemplate (ui = "/org/erikreider/swaysettings/Pages/Apps/Startup_Apps_Item.ui")]
    class Startup_Apps_Item : Gtk.ListBoxRow {

        [GtkChild]
        unowned Gtk.Image image;

        [GtkChild]
        unowned Gtk.Label label;

        [GtkChild]
        unowned Gtk.Button button;

        public Startup_Apps_Item (DesktopAppInfo app_info) {
            Object ();
            image.set_from_gicon (app_info.get_icon (), Gtk.IconSize.DND);
            label.set_text (app_info.get_display_name ());
        }
    }

    [GtkTemplate (ui = "/org/erikreider/swaysettings/Pages/Apps/Desktop_App_Chooser.ui")]
    class Desktop_App_Chooser : Hdy.Window {

        Gtk.ListStore liststore = new Gtk.ListStore (3, typeof (string), typeof (string), typeof (int));

        [GtkChild]
        unowned Gtk.TreeView tree_view;

        [GtkChild]
        unowned Gtk.Button save_button;

        [GtkChild]
        unowned Gtk.Button cancel_button;

        public Desktop_App_Chooser (SwaySettings.Window window) {
            Object ();
            this.set_attached_to (window);
            this.set_transient_for (window);

            cancel_button.clicked.connect (() => this.close ());

            tree_view.set_model (liststore);
            tree_view.row_activated.connect ((tree_path) => {
                print ("#");
            });

            var icon_column = new Gtk.TreeViewColumn.with_attributes ("icon", new Gtk.CellRendererPixbuf (), "icon_name", 1);
            var name_column = new Gtk.TreeViewColumn.with_attributes ("name", new Gtk.CellRendererText (), "text", 0);
            tree_view.append_column (icon_column);
            tree_view.append_column (name_column);

            var apps = new ArrayList<AppInfo>();
            GLib.AppInfo.get_all ().foreach ((val) => apps.add (val));

            add_items.begin (apps);
            liststore.set_sort_column_id (0, Gtk.SortType.ASCENDING);
        }

        async void add_items (ArrayList<AppInfo> apps) {
            for (int index = 0; index < apps.size; index++) {
                var app = apps[index];
                var app_icon = "gtk-missing-icon";
                if (app.get_icon () != null) app_icon = app.get_icon ().to_string ();
                Gtk.TreeIter iter;
                liststore.append (out iter);
                liststore.set (iter, 0, app.get_display_name (), 1, app_icon, 2, index);
                Idle.add (add_items.callback);
                yield;
            }
        }

        // public AppInfo run () {
            // var selection = tree_view.get_selection ();
            // Gtk.TreeModel tree_model;
            // Gtk.TreeIter tree_iter;
            // selection.get_selected (out tree_model, out tree_iter);
            // GLib.Value app_index;
            // tree_model.get_value (tree_iter, 2, out app_index);
        // }
    }
}
