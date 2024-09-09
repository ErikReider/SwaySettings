using Gee;

namespace SwaySettings {
    public abstract class Page : Adw.Bin {
        public SettingsItem item;

        public virtual bool refresh_on_realize { get; default = true; }

        protected Page (SettingsItem item, Adw.NavigationPage page) {
            this.item = item;

            if (refresh_on_realize) {
                this.realize.connect (on_refresh);
            }
        }

        // public void set_reveal_child (bool value) {
        //     revealer.set_reveal_child (value);
        // }

        public virtual void on_refresh () {}

        public virtual async void on_back (Adw.NavigationPage page) {}

        public static Adw.Clamp get_clamped_widget (Gtk.Widget widget,
                                                    bool have_margin = true,
                                                    int clamp_max = 600,
                                                    int clamp_tight = 400) {
            var clamp = new Adw.Clamp () {
                maximum_size = clamp_max,
                tightening_threshold = clamp_tight,
                orientation = Gtk.Orientation.HORIZONTAL,
            };
            if (have_margin) {
                int margin = 16;
                clamp.set_margin_top (margin);
                clamp.set_margin_start (margin);
                clamp.set_margin_bottom (margin);
                clamp.set_margin_end (margin);
            }

            clamp.set_child (widget);
            clamp.show ();
            return clamp;
        }

        public static Gtk.ScrolledWindow get_scroll_widget (Gtk.Widget widget,
                                                            bool have_margin = true,
                                                            int clamp_max = 600,
                                                            int clamp_tight = 400) {
            var scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.set_hexpand (true);
            scrolled_window.set_vexpand (true);

            scrolled_window.set_child (get_clamped_widget (widget,
                                              have_margin,
                                              clamp_max,
                                              clamp_tight));

            return scrolled_window;
        }
    }

    public abstract class PageScroll : Page {

        public virtual bool have_margin {
            get {
                return true;
            }
        }
        public virtual bool shadow {
            get {
                return false;
            }
        }
        public virtual int clamp_max {
            get {
                return 600;
            }
        }
        public virtual int clamp_tight {
            get {
                return 400;
            }
        }

        protected PageScroll (SettingsItem item, Adw.NavigationPage page) {
            base (item, page);
        }

        public override void on_refresh () {
            base.set_child (get_scroll_widget (
                           set_child (),
                           have_margin,
                           clamp_max,
                           clamp_tight));
        }

        public new abstract Gtk.Widget set_child ();
    }

    public abstract class PageTabbed : Page {

        public Gtk.Stack stack;

        protected PageTabbed (SettingsItem item,
                              Adw.NavigationPage page,
                              string no_tabs_text = "Nothing here...") {
            base (item, page);

            stack = new Gtk.Stack ();
            stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
            var stack_switcher = new Gtk.StackSwitcher ();
            // stack_switcher.button_release_event.connect ((widget) => {
            // subtitle.set_text (stack.visible_child_name);
            // return false;
            // });
            stack_switcher.stack = stack;
            stack_switcher.set_halign (Gtk.Align.CENTER);
            stack_switcher.set_margin_top (8);
            stack_switcher.set_margin_start (8);
            stack_switcher.set_margin_bottom (8);
            stack_switcher.set_margin_end (8);

            // stack.set_margin_top (margin);
            // stack.set_margin_start (margin);
            // stack.set_margin_bottom (margin);
            // stack.set_margin_end (margin);

            Gtk.Box content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            set_child (content_box);
            content_box.append (stack_switcher);
            content_box.append (stack);


            var all_tabs = tabs ();
            if (all_tabs.length < 1) {
                stack.add_named (new Gtk.Label (no_tabs_text), no_tabs_text);
            } else {
                foreach (var tab in all_tabs) {
                    stack.add_titled (tab, tab.tab_name, tab.tab_name);
                }
                if (all_tabs.length == 1) {
                    stack_switcher.visible = false;
                    page.set_title (stack.visible_child_name);
                }
            }
        }

        public abstract PageTab[] tabs ();
    }

    public abstract class PageTab : Gtk.Box {
        public string tab_name;

        public IPC ipc;

        protected PageTab (string tab_name, IPC ipc) {
            Object ();
            this.ipc = ipc;
            this.tab_name = tab_name;

            orientation = Gtk.Orientation.VERTICAL;
            spacing = 0;
            hexpand = true;
            vexpand = true;
        }
    }
}
