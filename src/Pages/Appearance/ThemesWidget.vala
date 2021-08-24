using Gee;

namespace SwaySettings {
    public class Themes_Widget : Page_Tab {

        private Gtk.ListBox list_box;

        public Themes_Widget (string tab_name, IPC ipc) {
            base (tab_name, ipc);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            list_box = new Gtk.ListBox ();
            list_box.get_style_context ().add_class ("content");

            gtk_theme ("GTK Application Theme", "gtk-theme", "themes");
            gtk_theme ("GTK Icon Theme", "icon-theme", "icons");

            box.add (list_box);
            box.set_margin_top (8);
            box.set_margin_start (8);
            box.set_margin_bottom (8);
            box.set_margin_end (8);
            box.show_all ();
            this.add (Page.get_scroll_widget (box, false));
        }

        public void gtk_theme (string title, string setting_name, string folder_name) {
            var gtk_theme_expander = new Hdy.ComboRow ();
            gtk_theme_expander.set_title (title);

            ListStore liststore = new ListStore (typeof (Hdy.ValueObject));
            string current_theme = Functions.get_current_gtk_theme (setting_name);
            ArrayList<string> gtk_themes = Functions.get_gtk_themes (folder_name);
            int selected_index = 0;
            for (int i = 0; i < gtk_themes.size; i++) {
                var theme_name = gtk_themes[i];
                liststore.append (new Hdy.ValueObject (theme_name));
                if (current_theme == theme_name) selected_index = i;
            }

            gtk_theme_expander.bind_name_model ((ListModel) liststore, (item) => {
                return ((Hdy.ValueObject)item).get_string ();
            });
            gtk_theme_expander.set_selected_index (selected_index);
            gtk_theme_expander.notify["selected-index"].connect ((sender, property) => {
                var theme = gtk_themes.get (((Hdy.ComboRow)sender).get_selected_index ());
                Functions.set_gtk_theme (setting_name, theme);
            });

            list_box.add (gtk_theme_expander);
        }
    }
}
