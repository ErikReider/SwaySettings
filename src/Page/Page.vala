using Gee;

namespace SwaySettings {
    [GtkTemplate (ui = "/org/erikreider/swaysettings/Page/Page.ui")]
    public abstract class Page : Gtk.Box {

        [GtkChild]
        public unowned Hdy.HeaderBar header_bar;
        [GtkChild]
        public unowned Gtk.Button back_button;
        [GtkChild]
        public unowned Gtk.ButtonBox button_box;
        [GtkChild]
        public unowned Gtk.Box content_box;

        public string label;

        public IPC ipc;

        public virtual bool refresh_on_realize { get; default = true; }

        protected Page (string label, Hdy.Deck deck, IPC ipc) {
            Object ();
            this.ipc = ipc;
            this.label = label;
            header_bar.set_title (this.label);
            back_button.clicked.connect (() => {
                deck.navigate (Hdy.NavigationDirection.BACK);
            });
            deck.notify["visible-child"].connect (() => {
                if (deck.visible_child_name == "main_page") on_back (deck);
            });

            if (refresh_on_realize) {
                this.realize.connect (() => on_refresh ());
            }
        }

        public virtual void on_refresh () {
        }

        public virtual void on_back (Hdy.Deck deck) {
        }

        public static Gtk.Container get_scroll_widget (Gtk.Widget widget, bool have_margin = true, bool shadow = false,
                                                       int clamp_max = 600, int clamp_tight = 400) {
            var scrolled_window = new Gtk.ScrolledWindow (null, null);
            if (shadow) scrolled_window.shadow_type = Gtk.ShadowType.IN;
            scrolled_window.expand = true;
            var clamp = new Hdy.Clamp ();
            clamp.maximum_size = clamp_max;
            clamp.tightening_threshold = clamp_tight;
            clamp.orientation = Gtk.Orientation.HORIZONTAL;
            if (have_margin) {
                int margin = 16;
                clamp.set_margin_top (margin);
                clamp.set_margin_start (margin);
                clamp.set_margin_bottom (margin);
                clamp.set_margin_end (margin);
            }

            clamp.add (widget);
            scrolled_window.add (clamp);
            scrolled_window.show_all ();
            return scrolled_window;
        }
    }

    public abstract class Page_Scroll : Page {

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

        protected Page_Scroll (string label, Hdy.Deck deck, IPC ipc) {
            base (label, deck, ipc);
        }

        public override void on_refresh () {
            foreach (var child in button_box.get_children ()) {
                button_box.remove (child);
            }
            foreach (var child in content_box.get_children ()) {
                content_box.remove (child);
            }
            content_box.add (get_scroll_widget (
                                 set_child (),
                                 have_margin,
                                 shadow,
                                 clamp_max,
                                 clamp_tight));
        }

        public abstract Gtk.Widget set_child ();
    }

    public abstract class Page_Tabbed : Page {

        public Gtk.Stack stack;

        protected Page_Tabbed (string label,
                               Hdy.Deck deck,
                               IPC ipc,
                               string no_tabs_text = "Nothing here...") {
            base (label, deck, ipc);

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

            content_box.add (stack_switcher);
            content_box.add (stack);
            content_box.show_all ();

            var all_tabs = tabs ();
            if (all_tabs.length < 1) {
                stack.add (new Gtk.Label (no_tabs_text));
                stack.show_all ();
            } else {
                foreach (var tab in all_tabs) {
                    stack.add_titled (tab, tab.tab_name, tab.tab_name);
                }
                if (all_tabs.length == 1) {
                    stack_switcher.visible = false;
                    header_bar.set_title (stack.visible_child_name);
                }
            }
        }

        public override void on_back (Hdy.Deck deck) {
            stack.set_visible_child (stack.get_children ().nth_data (0));
        }

        public abstract Page_Tab[] tabs ();
    }

    public abstract class Page_Tab : Gtk.Box {
        public string tab_name;

        public IPC ipc;

        protected Page_Tab (string tab_name, IPC ipc) {
            Object ();
            this.ipc = ipc;

            this.orientation = Gtk.Orientation.VERTICAL;
            this.spacing = 0;
            this.expand = true;

            this.tab_name = tab_name;
            this.show_all ();
        }
    }
}
