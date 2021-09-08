using Gee;

namespace SwaySettings {
    public class Default_Apps : Page_Scroll {

        public static ArrayList<default_app_data ? > mime_types = new ArrayList<default_app_data ? >.wrap ({
            default_app_data ("Web Browser", "x-scheme-handler/http"),
            default_app_data ("Mail Client", "x-scheme-handler/mailto"),
            default_app_data ("Calendar", "text/calendar"),
            default_app_data ("Music", "audio/x-vorbis+ogg"),
            default_app_data ("Video", "video/x-ogm+ogg"),
            default_app_data ("Photos", "image/jpeg"),
            default_app_data ("Text Editor", "text/plain"),
            default_app_data ("File Browser", "inode/directory"),
        });

        public Default_Apps (string page_label, Hdy.Deck deck, IPC ipc) {
            base (page_label, deck, ipc);
        }

        public override Gtk.Widget set_child () {
            var list_box = new Gtk.ListBox ();
            list_box.selection_mode = Gtk.SelectionMode.NONE;
            list_box.get_style_context ().add_class ("content");
            for (int i = 0; i < mime_types.size; i++) {
                list_box.add (get_item (mime_types[i]));
            }
            list_box.show_all ();
            return list_box;
        }

        Gtk.Widget get_item (default_app_data def_app) {
            var chooser = new Gtk.AppChooserButton (def_app.mime_type);
            chooser.show_dialog_item = true;
            chooser.show_default_item = true;
            chooser.changed.connect ((combo_box) => {
                var selected_app = chooser.get_app_info ();
                if (selected_app == null) return;
                Functions.set_default_for_mimes (def_app, selected_app, def_app.category_name == "Web");
            });
            return new List_Item (def_app.category_name, chooser, 56);
        }
    }

    public struct default_app_data {
        string category_name;
        string mime_type;

        default_app_data (string category_name, string mime_type) {
            this.mime_type = mime_type;
            this.category_name = category_name;
        }
    }
}
