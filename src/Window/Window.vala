using Gee;

namespace SwaySettings {
    [GtkTemplate (ui = "/org/erikreider/swaysettings/Window/Window.ui")]
    public class Window : Hdy.ApplicationWindow {
        [GtkChild]
        unowned Hdy.Deck deck;
        [GtkChild]
        unowned Gtk.Box content_box;
        [GtkChild]
        unowned Gtk.Box page_box;

        private Item[] items = {};
        private string ? current_page_name = null;

        public void navigato_to_page (string page) {
            if (current_page_name != null
                && current_page_name == page
                && deck.visible_child_name != "main_page") return;
            foreach (var item in items) {
                if (item == null) continue;
                if (item.settings_item.page_name == page) {
                    item.activate ();
                    break;
                }
            }
        }

        public Window (Gtk.Application app) {
            Object (application: app);
            IPC ipc = new IPC ();

            SettingsCategory[] items = {
                SettingsCategory ("Desktop", {
                    SettingsItem ("preferences-desktop-wallpaper",
                                  new Background_Page ("Background", deck, ipc),
                                  "wallpaper"),
                    SettingsItem ("preferences-desktop-theme",
                                  new Themes_Page ("Appearance", deck, ipc),
                                  "appearance"),

                    SettingsItem ("applications-other",
                                  new Startup_Apps ("Startup Applications",
                                                    deck,
                                                    ipc),
                                  "startup-apps"),
                    SettingsItem ("preferences-other",
                                  new Default_Apps ("Default Applications",
                                                    deck,
                                                    ipc),
                                  "default-apps"),
                    SettingsItem ("mail-unread",
                                  new Swaync ("Sway Notification Center",
                                              deck,
                                              ipc),
                                  "swaync",
                                  !Functions.is_swaync_installed ()),
                }),
                SettingsCategory ("Hardware", {
                    SettingsItem ("input-keyboard",
                                  new Keyboard_Page ("Keyboard", deck, ipc),
                                  "keyboard"),
                    SettingsItem ("input-mouse",
                                  new Mouse_Page ("Mouse", deck, ipc),
                                  "mouse"),
                    SettingsItem ("input-touchpad",
                                  new Trackpad_Page ("Trackpad", deck, ipc),
                                  "trackpad"),
                }),
                SettingsCategory ("Administration", {
                    SettingsItem ("system-users",
                                  new Users ("Users", deck, ipc),
                                  "users"),
                }),
            };

            for (int index = 0; index < items.length; index++) {
                var category = items[index];
                var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                if (index % 2 != 0) box.get_style_context ().add_class ("view");

                var title = new Gtk.Label (category.title);
                Pango.AttrList li = new Pango.AttrList ();
                li.insert (Pango.attr_weight_new (Pango.Weight.BOLD));
                li.insert (new Pango.AttrSize (12288));
                title.set_attributes (li);

                title.xalign = 0.0f;
                int margin = 8;
                title.set_margin_top (margin);
                title.set_margin_start (margin);
                title.set_margin_bottom (2);
                title.set_margin_end (margin);

                var flow_box = new Gtk.FlowBox ();
                flow_box.set_homogeneous (true);
                flow_box.vexpand = false;
                flow_box.min_children_per_line = 3;
                flow_box.max_children_per_line = 7;
                flow_box.selection_mode = Gtk.SelectionMode.NONE;
                flow_box.child_activated.connect ((child) => {
                    foreach (var c in page_box.get_children ()) {
                        if (c != null) page_box.remove (c);
                    }
                    Item item = (Item) child;
                    if (item == null) return;
                    current_page_name = item.settings_item.page_name;
                    page_box.add (item.settings_item.page);
                    deck.navigate (Hdy.NavigationDirection.FORWARD);
                });
                foreach (var settings_item in category.items) {
                    if (settings_item.hidden) continue;
                    var item = new Item (settings_item.page.label,
                                         settings_item.image,
                                         settings_item);
                    this.items += item;
                    flow_box.add (item);
                }
                if (flow_box.get_children ().length () <= 0) continue;

                box.add (title);
                box.add (flow_box);
                content_box.add (box);
            }

            content_box.show_all ();
        }
    }

    struct SettingsCategory {
        string title;
        SettingsItem[] items;

        public SettingsCategory (string title, SettingsItem[] items) {
            this.title = title;
            this.items = items;
        }
    }

    public struct SettingsItem {
        string image;
        Page page;
        bool hidden;
        string page_name;

        SettingsItem (string image,
                      Page page,
                      string page_name,
                      bool hidden = false) {
            this.image = image;
            this.page = page;
            this.page_name = page_name;
            this.hidden = hidden;
        }
    }
}
