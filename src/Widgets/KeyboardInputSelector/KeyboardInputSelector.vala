using Gee;

namespace SwaySettings {
    [GtkTemplate (ui = "/org/erikreider/swaysettings/Widgets/KeyboardInputSelector/KeyboardInputSelector.ui")]
    public class KeyboardInputSelector : Hdy.Window {

        [GtkChild]
        unowned Gtk.ListBox list_box;

        [GtkChild]
        unowned Gtk.Button button_add;
        [GtkChild]
        unowned Gtk.Button button_cancel;

        public KeyboardInputSelector (SwaySettings.Window window,
                                      HashMap<string, Language> all_languages,
                                      ArrayList<Language> used_languages,
                                      OrderListSelector ols) {
            this.set_attached_to (window);
            this.set_transient_for (window);

            button_add.sensitive = false;

            // Sort by description
            var values = all_languages.values.order_by ((a, b) => {
                if (a.description == b.description) return 0;
                return a.description > b.description ? 1 : -1;
            });

            Language[] langs = {};
            while (values.next ()) {
                var lang = values.get ();
                if (used_languages.contains (lang)) continue;
                list_box.add (new Gtk.Label (lang.to_string ()));
                langs += lang;
            }

            list_box.row_selected.connect ((_, r) => {
                button_add.sensitive = r != null && r.get_index () >= 0;
            });

            list_box.row_activated.connect ((_, row) => {
                list_box.select_row (row);
                button_add.clicked ();
            });

            button_add.clicked.connect (() => {
                int index = list_box.get_selected_row ().get_index ();
                unowned Language lang = langs[index];
                if (index < 0 || lang == null) {
                    button_add.sensitive = false;
                    return;
                }

                ols.add_row (lang);
                button_cancel.clicked ();
            });

            button_cancel.clicked.connect (() => {
                this.hide ();
                this.close ();
                this.destroy ();
            });

            this.show_all ();
            list_box.unselect_all ();
            list_box.set_focus_child (null);
        }
    }
}
