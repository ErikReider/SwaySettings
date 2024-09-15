using Gee;

namespace SwaySettings {
    public enum PageType {
        USERS,
        WALLPAPER,
        APPEARANCE,
        STARTUP_APPS,
        DEFAULT_APPS,
        SWAYNC,
        SOUND,
        BLUETOOTH,
        KEYBOARD,
        MOUSE,
        TRACKPAD,
        SYSTEM;

        public string ? get_name () {
            switch (this) {
                case USERS:
                    return "Users";
                case WALLPAPER:
                    return "Wallpaper";
                case APPEARANCE:
                    return "Appearance";
                case STARTUP_APPS:
                    return "Startup Apps";
                case DEFAULT_APPS:
                    return "Default Apps";
                case SWAYNC:
                    return "Sway Notification Center";
                case BLUETOOTH:
                    return "Bluetooth";
                case SOUND:
                    return "Sound";
                case KEYBOARD:
                    return "Keyboard";
                case MOUSE:
                    return "Mouse";
                case TRACKPAD:
                    return "Trackpad";
                case SYSTEM:
                    return "About this PC";
            }
            return null;
        }

        public string ? get_internal_name () {
            switch (this) {
                case USERS:
                    return "users";
                case WALLPAPER:
                    return "wallpaper";
                case APPEARANCE:
                    return "appearance";
                case STARTUP_APPS:
                    return "startup-apps";
                case DEFAULT_APPS:
                    return "default-apps";
                case SWAYNC:
                    return "swaync";
                case BLUETOOTH:
                    return "bluetooth";
                case SOUND:
                    return "sound";
                case KEYBOARD:
                    return "keyboard";
                case MOUSE:
                    return "mouse";
                case TRACKPAD:
                    return "trackpad";
                case SYSTEM:
                    return "about";
            }
            return null;
        }
    }

    public class Window : Adw.ApplicationWindow {
        Adw.NavigationSplitView split_view = new Adw.NavigationSplitView ();
        Gtk.ListBox sidebar_listbox = new Gtk.ListBox ();

        Adw.ToolbarView content_toolbarview = new Adw.ToolbarView();
        Adw.NavigationPage content_page;

        private (unowned ISidebarListItem)[] sidebar_items = {};
        private string ? current_page_name = null;

        private IPC ipc;

        // TODO:
        // - Change icons
        // - Add Power, Networking, WiFi, About this PC
        private static SettingsCategory[] items = {
            SettingsCategory ("User", {
                SettingsItem ("system-users-symbolic", PageType.USERS),
            }),
            SettingsCategory ("Hardware", {
                SettingsItem ("computer-symbolic", PageType.SYSTEM),
                SettingsItem ("bluetooth-symbolic", PageType.BLUETOOTH),
                SettingsItem ("audio-speakers-symbolic", PageType.SOUND),
            }),
            SettingsCategory ("Customization", {
                SettingsItem ("preferences-desktop-wallpaper-symbolic", PageType.WALLPAPER),
                SettingsItem ("applications-graphics-symbolic", PageType.APPEARANCE),
                SettingsItem ("application-x-executable-symbolic", PageType.STARTUP_APPS),
                SettingsItem ("preferences-other", PageType.DEFAULT_APPS),
                // SettingsItem ("mail-unread", PageType.SWAYNC, "swaync", !Functions.is_swaync_installed ()),
            }),
            SettingsCategory ("Input", {
                SettingsItem ("preferences-desktop-keyboard-symbolic", PageType.KEYBOARD),
                SettingsItem ("input-mouse-symbolic", PageType.MOUSE),
                SettingsItem ("input-touchpad-symbolic", PageType.TRACKPAD),
            }),
        };

        construct {
            default_width = 800;
            default_height = 576;
            width_request = 500;
            height_request = 500;

            split_view.set_show_content (true);
            set_content (split_view);

            Adw.BreakpointCondition condition = new Adw.BreakpointCondition.length (
                Adw.BreakpointConditionLengthType.MAX_WIDTH, 650, Adw.LengthUnit.SP);
            Adw.Breakpoint breakpoint = new Adw.Breakpoint (condition);
            breakpoint.add_setter (split_view, "collapsed", true);
            add_breakpoint (breakpoint);

            // Sidebar
            sidebar_listbox.add_css_class ("navigation-sidebar");
            sidebar_listbox.set_activate_on_single_click (true);
            sidebar_listbox.set_selection_mode (Gtk.SelectionMode.SINGLE);
            sidebar_listbox.row_activated.connect ((row) => {
                if (row == null) return;
                SettingsItem settings_item = ((ISidebarListItem) row).settings_item;
                if (current_page_name == settings_item.internal_name) {
                    debug ("Ignoring change to same page...");
                    return;
                }
                current_page_name = settings_item.internal_name;
                Page ? page = get_page (settings_item);
                if (page != null) {
                    Page prev_page = (Page) content_toolbarview.get_content ();
                    if (prev_page != null) {
                        prev_page.on_back.begin (content_page);
                    }
                    split_view.set_show_content (true);
                    content_toolbarview.set_content (page);
                    content_page.set_title (settings_item.name);
                }
            });
            // Add separators
            sidebar_listbox.set_header_func ((row, before) => {
                if (before == null) return;
                SettingsItem row_item = ((ISidebarListItem) row).settings_item;
                SettingsItem before_item = ((ISidebarListItem) before).settings_item;
                if (row_item.group != before_item.group) {
                    Gtk.Separator separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
                    separator.margin_start = ISidebarListItem.MARGIN;
                    separator.margin_end = ISidebarListItem.MARGIN;
                    row.set_header (separator);
                }
            });
            Gtk.ScrolledWindow scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.set_child (sidebar_listbox);
            Adw.ToolbarView toolbarview = new Adw.ToolbarView();
            toolbarview.set_content (scrolled_window);
            toolbarview.add_top_bar (new Adw.HeaderBar ());
            Adw.NavigationPage page = new Adw.NavigationPage (toolbarview, "Sway Settings");
            page.set_tag ("sidebar");
            split_view.set_sidebar (page);

            // Main page
            content_toolbarview.add_top_bar (new Adw.HeaderBar ());
            content_page = new Adw.NavigationPage (content_toolbarview, "Settings");
            content_page.set_tag ("content");
            split_view.set_content (content_page);
        }

        public void navigato_to_page (string page) {
            if (current_page_name != null && current_page_name == page) return;

            foreach (var item in sidebar_items) {
                if (item == null) continue;
                if (item.settings_item.internal_name == page) {
                    if (item is Gtk.ListBoxRow) {
                        ((Gtk.ListBoxRow) item).activate ();
                    }
                    break;
                }
            }
        }

        public Window (Gtk.Application app) {
            Object (application: app);
            ipc = new IPC ();

            foreach (SettingsCategory category in items) {
                foreach (unowned SettingsItem settings_item in category.items) {
                    settings_item.group = category;
                    if (settings_item.hidden) continue;
                    string ? name = settings_item.page_type.get_internal_name ();
                    if (name == null) continue;
                    if (settings_item.page_type == PageType.USERS) {
                        var item = new UserListItem (settings_item);
                        this.sidebar_items += item;
                        sidebar_listbox.append (item);
                    } else {
                        var item = new SidebarListItem (settings_item);
                        this.sidebar_items += item;
                        sidebar_listbox.append (item);
                        // Start in the System page
                        if (settings_item.page_type == PageType.SYSTEM) {
                            sidebar_listbox.select_row (item);
                        }
                    }
                }
            }
        }

        public Page ? get_page (SettingsItem item) {
            switch (item.page_type) {
                default:
                    return null;
                case WALLPAPER:
                    return new BackgroundPage (item, content_page);
                case APPEARANCE:
                    return new ThemesPage (item, content_page);
                case STARTUP_APPS:
                    return new StartupApps (item, content_page);
                case DEFAULT_APPS:
                    return new DefaultApps (item, content_page);
                // case SWAYNC:
                //     return new Swaync (item, deck, ipc);
                case BLUETOOTH:
                    return new BluetoothPage (item, content_page);
                case SOUND:
                    return new PulsePage (item, content_page);
                // case KEYBOARD:
                //     return new KeyboardPage (item, deck, ipc);
                // case MOUSE:
                //     return new MousePage (item, deck, ipc);
                // case TRACKPAD:
                //     return new TrackpadPage (item, deck, ipc);
                case USERS:
                    return new Users (item, content_page);
            }
            return null;
        }
    }

    public struct SettingsCategory {
        string name;
        SettingsItem[] items;

        public SettingsCategory (string name, SettingsItem[] items) {
            this.name = name;
            this.items = items;
        }
    }

    public struct SettingsItem {
        public unowned SettingsCategory group;

        string image;
        bool hidden;
        PageType page_type;

        string internal_name;
        string name;

        SettingsItem (string image,
                      PageType page_type,
                      bool hidden = false) {
            this.image = image;
            this.page_type = page_type;
            this.hidden = hidden;

            this.internal_name = page_type.get_internal_name ();
            this.name = page_type.get_name ();
        }
    }
}
