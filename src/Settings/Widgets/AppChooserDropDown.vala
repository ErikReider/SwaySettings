namespace SwaySettings {
    private class DropDownAppInfoItem : Object {
        public DesktopAppInfo ?app_info { get; construct; }
        public bool is_app { get; construct; }

        public string display_name { get; construct; }
        public Icon ?gicon { get; construct; }

        public DropDownAppInfoItem (DesktopAppInfo app_info) {
            Object (
                app_info: app_info,
                is_app: true,
                display_name: app_info.get_display_name (),
                gicon: app_info.get_icon ()
            );
        }

        public DropDownAppInfoItem.custom () {
            Object (
                app_info: null,
                is_app: false,
                display_name: "Other Apps...",
                gicon: null
            );
        }

        public static bool equals (Object _a, Object _b) {
            unowned DropDownAppInfoItem a = (DropDownAppInfoItem) _a;
            unowned DropDownAppInfoItem b = (DropDownAppInfoItem) _b;
            // One of them is null, but the other isn't
            if (a.app_info == null ^ b.app_info == null) {
                return false;
            }
            return a.is_app == b.is_app
                   && (a.app_info != null && a.app_info.equal (b.app_info));
        }
    }

    public class AppChooserDropDown : Adw.ComboRow {
        public string content_type { get; construct; }

        public signal void app_picked (DesktopAppInfo app_info);

        private ListStore list_store;

        private ulong selection_handler_id = 0;

        construct {
            list_store = new ListStore (typeof (DropDownAppInfoItem));
            set_model (list_store);

            var factory = new Gtk.BuilderListItemFactory.from_resource (
                null, "/org/erikreider/swaysettings/ui/AppChooserDropDownItem.ui");
            set_factory (factory);

            selection_handler_id = notify["selected"].connect (selected_cb);

            repopulate_popover ();
        }

        public AppChooserDropDown (string content_type) {
            Object (content_type: content_type);
        }

        private async void selected_cb () {
            if (!get_realized ()) {
                return;
            }
            unowned Object ?obj = get_selected_item ();
            if (obj == null || !(obj is DropDownAppInfoItem)) {
                return;
            }
            DropDownAppInfoItem item = (DropDownAppInfoItem) obj;

            if (!item.is_app) {
                SignalHandler.block (this, selection_handler_id);
                set_sensitive (false);

                var dialog = new AppChooserDialog (content_type);
                DesktopAppInfo ?chosen_app_info = yield dialog.choose (get_root ());

                if (chosen_app_info != null) {
                    // Prepend the selected app or move it if it already exists
                    var chosen_item = new DropDownAppInfoItem (chosen_app_info);

                    uint position;
                    bool found = list_store.find_with_equal_func (chosen_item,
                                                                  DropDownAppInfoItem.equals,
                                                                  out position);
                    if (found) {
                        list_store.remove (position);
                    }
                    list_store.insert (0, chosen_item);
                }
                // Select the newly added default app or the previous default if cancelled
                set_selected (0);

                set_sensitive (true);
                SignalHandler.unblock (this, selection_handler_id);
                return;
            }

            if (item.app_info == null) {
                warn_if_reached ();
                return;
            }
            app_picked (item.app_info);
        }

        public void refresh () {
            repopulate_popover ();
        }

        private void repopulate_popover () {
            SignalHandler.block (this, selection_handler_id);

            list_store.remove_all ();

            AppInfo ?default_app = AppInfo.get_default_for_type (content_type, false);
            if (default_app != null && default_app is DesktopAppInfo) {
                DesktopAppInfo d_app_info = (DesktopAppInfo) default_app;

                var item = new DropDownAppInfoItem (d_app_info);
                list_store.append (item);
            }

            var apps = AppInfo.get_recommended_for_type (content_type);
            foreach (unowned AppInfo app_info in apps) {
                if (default_app != null && default_app.equal (app_info)) {
                    continue;
                }

                DesktopAppInfo d_app_info = (DesktopAppInfo) app_info;
                var item = new DropDownAppInfoItem (d_app_info);
                list_store.append (item);
            }

            var other_apps = new DropDownAppInfoItem.custom ();
            list_store.append (other_apps);

            SignalHandler.unblock (this, selection_handler_id);
        }
    }
}
