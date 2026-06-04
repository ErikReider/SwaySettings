namespace SwaySettings {
    private class DialogAppInfoItem : Object {
        public DesktopAppInfo app_info { get; construct; }
        public string category { get; construct; }
        public short category_order { get; construct; }

        public string ?display_name { get; construct; }
        public Icon ?gicon { get; construct; }

        public DialogAppInfoItem (DesktopAppInfo app_info,
                                  string category,
                                  short category_order) {
            Object (
                app_info: app_info,
                category: category,
                category_order: category_order,
                display_name: app_info.get_display_name (),
                gicon: app_info.get_icon ()
            );
        }
    }

    [GtkTemplate (ui = "/org/erikreider/swaysettings/ui/AppChooserDialog.ui")]
    public class AppChooserDialog : Adw.Dialog {
        public string ?content_type { get; construct; }
        public string ?subtitle { get; construct; }

        [GtkChild]
        unowned Gtk.Button select_button;
        [GtkChild]
        unowned Gtk.ListView list_view;

        private ListStore list_store;
        private Gtk.SingleSelection selection_model;

        private DialogAppInfoItem ?default_app = null;
        private DialogAppInfoItem ?selected_app = null;

        construct {
            if (content_type != null) {
                subtitle = "For opening “%s” files.".printf (content_type);
            }

            list_store = new ListStore (typeof (DialogAppInfoItem));

            var name_expression = new Gtk.PropertyExpression (typeof (DialogAppInfoItem),
                                                              null,
                                                              "display-name");

            var sort_model = new Gtk.SortListModel (
                list_store, new Gtk.StringSorter (name_expression));

            var category_expression = new Gtk.PropertyExpression (typeof (DialogAppInfoItem),
                                                                  null,
                                                                  "category-order");
            sort_model.section_sorter = new Gtk.NumericSorter (category_expression);

            selection_model = new Gtk.SingleSelection (sort_model) {
                autoselect = false,
                can_unselect = true,
                selected = Gtk.INVALID_LIST_POSITION,
            };
            selection_model.notify["selected"].connect (() => {
                select_button.sensitive = selection_model.selected != Gtk.INVALID_LIST_POSITION;
                selected_app = (DialogAppInfoItem ?) selection_model.get_selected_item ();
            });

            list_view.set_model (selection_model);
            var factory = new Gtk.BuilderListItemFactory.from_resource (
                null, "/org/erikreider/swaysettings/ui/AppChooserDialogRow.ui");
            list_view.set_factory (factory);

            var header_factory = new Gtk.SignalListItemFactory ();
            header_factory.setup.connect ((obj) => {
                Gtk.ListHeader list_header = (Gtk.ListHeader) obj;
                list_header.set_child (new Gtk.Label (null) {
                    halign = Gtk.Align.START,
                    margin_start = 4,
                });
            });
            header_factory.bind.connect ((obj) => {
                Gtk.ListHeader list_header = (Gtk.ListHeader) obj;
                DialogAppInfoItem item = (DialogAppInfoItem) list_header.item;
                Gtk.Label label = (Gtk.Label) list_header.get_child ();
                label.set_label (item.category);
            });
            list_view.set_header_factory (header_factory);

            populate_list.begin ();
        }

        public AppChooserDialog (string ?content_type) {
            Object (
                content_type: content_type,
                title: "Select Application"
            );
        }

        private async void populate_list () {
            if (content_type != null) {
                // Default app
                AppInfo ?default_app_info = AppInfo.get_default_for_type (content_type, false);
                if (default_app_info != null && default_app_info is DesktopAppInfo) {
                    DesktopAppInfo d_app_info = (DesktopAppInfo) default_app_info;

                    this.default_app = new DialogAppInfoItem (d_app_info, "Default App", 0);
                    list_store.append (this.default_app);

                    selection_model.select_item (0, true);
                }

                // Recommended apps
                List<AppInfo> recommended = AppInfo.get_recommended_for_type (content_type);
                foreach (unowned AppInfo app_info in recommended) {
                    // Skip the default app
                    if (default_app != null && app_info.equal (default_app.app_info)) {
                        continue;
                    }

                    if (app_info.should_show () && app_info is DesktopAppInfo) {
                        DesktopAppInfo d_app_info = (DesktopAppInfo) app_info;

                        var item = new DialogAppInfoItem (d_app_info, "Recommended Apps", 1);
                        list_store.append (item);
                    }
                }
            }

            // Add all other applications
            string all_apps_category = content_type == null ? "All Apps" : "Other Apps";
            foreach (unowned AppInfo app_info in AppInfo.get_all ()) {
                // Skip the default app
                if (default_app != null && app_info.equal (default_app.app_info)) {
                    continue;
                }

                if (app_info.should_show () && app_info is DesktopAppInfo) {
                    DesktopAppInfo d_app_info = (DesktopAppInfo) app_info;

                    var item = new DialogAppInfoItem (d_app_info, all_apps_category, 2);
                    list_store.append (item);
                }
            }

            list_view.scroll_to (0, Gtk.ListScrollFlags.NONE, null);
        }

        public async DesktopAppInfo ?choose (Gtk.Widget ?parent) {
            closed.connect (() => choose.callback ());
            present (parent);

            yield;
            close ();

            // Return null if selected the already default application
            if (selected_app != null && default_app != null) {
                if (selected_app.app_info.equal (default_app.app_info)) {
                    return null;
                }
            }
            return selected_app?.app_info;
        }

        [GtkCallback]
        private void cancel_button_clicked_cb () {
            selected_app = null;
            close ();
        }

        [GtkCallback]
        private void select_button_clicked_cb () {
            close ();
        }
    }
}
