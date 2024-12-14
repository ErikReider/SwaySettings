using Gee;

namespace SwaySettings {
    [GtkTemplate (ui =
                      "/org/erikreider/swaysettings/ui/KeyboardInputSelector.ui")]
    public class KeyboardInputSelector : Adw.Dialog {

        [GtkChild]
        unowned Gtk.ListBox list_box;

        [GtkChild]
        unowned Gtk.Button button_add;
        [GtkChild]
        unowned Gtk.Button button_cancel;

        public KeyboardInputSelector (HashMap<string, Language> all_languages,
                                      ArrayList<Language> used_languages,
                                      OrderListSelector ols) {
            set_follows_content_size (true);

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
                var label = new Gtk.Label (lang.to_string ());
                label.set_xalign (0.0f);
                label.set_yalign (0.5f);
                label.set_single_line_mode (true);
                Pango.AttrList attrs = new Pango.AttrList ();
                attrs.insert (Pango.attr_scale_new (1.1));
                label.attributes = attrs;
                list_box.append (label);
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

            list_box.unselect_all ();
            list_box.set_focus_child (null);
        }
    }
}
