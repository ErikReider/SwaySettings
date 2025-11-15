using Gee;

namespace SwaySettings {
    public enum PageType {
        USERS,
        ABOUT_PC,
        POWER,
        WALLPAPER,
        APPEARANCE,
        STARTUP_APPS,
        DEFAULT_APPS,
        SCREENSHOT,
        // SWAYNC,
        SOUND,
        BLUETOOTH,
        KEYBOARD,
        MOUSE,
        TRACKPAD;

        public string ? get_name () {
            switch (this) {
                case USERS:
                    return "Users";
                case ABOUT_PC:
                    return "About This PC";
                case POWER:
                    return "Power";
                case WALLPAPER:
                    return "Wallpaper";
                case APPEARANCE:
                    return "Appearance";
                case STARTUP_APPS:
                    return "Startup Apps";
                case DEFAULT_APPS:
                    return "Default Apps";
                case SCREENSHOT:
                    return "Screenshot";
                // case SWAYNC:
                //     return "Sway Notification Center";
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
            }
            return null;
        }

        public string ? get_internal_name () {
            switch (this) {
                case USERS:
                    return "users";
                case ABOUT_PC:
                    return "about";
                case POWER:
                    return "power";
                case WALLPAPER:
                    return "wallpaper";
                case APPEARANCE:
                    return "appearance";
                case STARTUP_APPS:
                    return "startup-apps";
                case DEFAULT_APPS:
                    return "default-apps";
                case SCREENSHOT:
                    return "screenshot";
                // case SWAYNC:
                //     return "swaync";
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
            }
            return null;
        }
    }

    public class Window : Adw.ApplicationWindow {
        Adw.NavigationSplitView split_view = new Adw.NavigationSplitView ();
        Gtk.ListBox sidebar_listbox = new Gtk.ListBox ();

        Adw.ToolbarView content_toolbarview = new Adw.ToolbarView ();
        Adw.NavigationPage content_page;

        private (unowned ISidebarListItem)[] sidebar_items = {};
        private string ?current_page_name = null;

        private static IPC ipc = new IPC ();


        // TODO:
        // - Change icons
        // - Add Power, Networking, WiFi
        private static SettingsCategory[] items = {
            SettingsCategory ("User", {
                SettingsItem ("system-users-symbolic", PageType.USERS),
            }),
            SettingsCategory ("Hardware", {
                SettingsItem ("computer-symbolic", PageType.ABOUT_PC),
                SettingsItem ("bluetooth-symbolic", PageType.BLUETOOTH),
                SettingsItem ("audio-speakers-symbolic", PageType.SOUND),
                SettingsItem ("power-page-symbolic", PageType.POWER),
            }),
            SettingsCategory ("Customization", {
                SettingsItem ("preferences-desktop-wallpaper-symbolic",
                              PageType.WALLPAPER),
                SettingsItem ("applications-graphics-symbolic",
                              PageType.APPEARANCE),
                SettingsItem ("application-x-executable-symbolic",
                              PageType.STARTUP_APPS),
                SettingsItem ("preferences-other", PageType.DEFAULT_APPS),
                SettingsItem ("screenshooter-symbolic", PageType.SCREENSHOT),
                // SettingsItem ("mail-unread", PageType.SWAYNC, "swaync", !Functions.is_swaync_installed ()),
            }),
            SettingsCategory ("Input", {
                SettingsItem ("preferences-desktop-keyboard-symbolic",
                              PageType.KEYBOARD, !ipc.inited),
                SettingsItem ("input-mouse-symbolic", PageType.MOUSE,
                              !ipc.inited),
                SettingsItem ("input-touchpad-symbolic", PageType.TRACKPAD,
                              !ipc.inited),
            }),
        };

        construct {
            default_width = 800;
            default_height = 576;
            width_request = 500;
            height_request = 300;

            split_view.set_show_content (true);
            set_content (split_view);

            Adw.BreakpointCondition condition =
                new Adw.BreakpointCondition.length (
                    Adw.BreakpointConditionLengthType.MAX_WIDTH, 650,
                    Adw.LengthUnit.SP);
            Adw.Breakpoint breakpoint = new Adw.Breakpoint (condition.copy ());
            breakpoint.add_setter (split_view, "collapsed", true);
            add_breakpoint (breakpoint);

            // Sidebar
            sidebar_listbox.add_css_class ("navigation-sidebar");
            sidebar_listbox.set_activate_on_single_click (true);
            sidebar_listbox.set_selection_mode (Gtk.SelectionMode.SINGLE);
            sidebar_listbox.row_activated.connect ((row) => {
                if (row == null) return;
                SettingsItem settings_item =
                    ((ISidebarListItem) row).settings_item;
                if (current_page_name == settings_item.internal_name) {
                    split_view.set_show_content (true);
                    return;
                }
                current_page_name = settings_item.internal_name;
                Page ?page = get_page (settings_item);
                if (page != null) {
                    Page prev_page = (Page) content_toolbarview.get_content ();
                    if (prev_page != null) {
                        // TODO: Yield?
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
                SettingsItem before_item =
                    ((ISidebarListItem) before).settings_item;
                if (row_item.group != before_item.group) {
                    Gtk.Separator separator =
                        new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
                    separator.margin_start = ISidebarListItem.MARGIN;
                    separator.margin_end = ISidebarListItem.MARGIN;
                    row.set_header (separator);
                }
            });
            Gtk.ScrolledWindow scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.set_child (sidebar_listbox);
            Adw.ToolbarView toolbarview = new Adw.ToolbarView ();
            toolbarview.set_content (scrolled_window);
            toolbarview.add_top_bar (new Adw.HeaderBar ());
            Adw.NavigationPage page = new Adw.NavigationPage (toolbarview,
                                                              "Sway Settings");
            page.set_tag ("sidebar");
            split_view.set_sidebar (page);

            // Main page
            content_toolbarview.add_top_bar (new Adw.HeaderBar ());
            content_page = new Adw.NavigationPage (content_toolbarview,
                                                   "Settings");
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

            foreach (SettingsCategory category in items) {
                foreach (unowned SettingsItem settings_item in category.items) {
                    settings_item.group = category;
                    if (settings_item.hidden) continue;
                    string ?name = settings_item.page_type.get_internal_name ();
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
                        if (settings_item.page_type == PageType.ABOUT_PC) {
                            item.activate ();
                        }
                    }
                }
            }
        }

        public Page ? get_page (SettingsItem item) {
            Page ?page = null;
            switch (item.page_type) {
                case ABOUT_PC:
                    page = new AboutPC (item, content_page);
                    break;
                case POWER:
                    page = new PowerPage (item, content_page);
                    break;
                case WALLPAPER:
                    page = new BackgroundPage (item, content_page);
                    break;
                case APPEARANCE:
                    page = new ThemesPage (item, content_page);
                    break;
                case STARTUP_APPS:
                    page = new StartupApps (item, content_page);
                    break;
                case DEFAULT_APPS:
                    page = new DefaultApps (item, content_page);
                    break;
                case SCREENSHOT:
                    page = new ScreenshotPage (item, content_page);
                    break;
                // case SWAYNC:
                //     page = new Swaync (item, deck, ipc);
                //     break;
                case BLUETOOTH:
                    page = new BluetoothPage (item, content_page);
                    break;
                case SOUND:
                    page = new PulsePage (item, content_page);
                    break;
                case KEYBOARD:
                    page = new KeyboardPage (item, content_page, ipc);
                    break;
                case MOUSE:
                    page = new MousePage (item, content_page, ipc);
                    break;
                case TRACKPAD:
                    page = new TrackpadPage (item, content_page, ipc);
                    break;
                case USERS:
                    page = new Users (item, content_page);
                    break;
            }

            if (page is IIpcPage) {
                if (!ipc.inited) {
                    return new NoIpcPage (item, content_page);
                }
            }

            return page;
        }
    }

    public struct SettingsCategory {
        string name;
        SettingsItem[] items;

        public SettingsCategory (string name,
                                 SettingsItem[] items) {
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
