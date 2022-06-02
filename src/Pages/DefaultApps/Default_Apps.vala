using Gee;

namespace SwaySettings {
    public class Default_Apps : Page_Scroll {

        public static default_app_data[] mime_types = {
            default_app_data ("Web Browser", "x-scheme-handler/http",
                              { "text/html", "application/xhtml+xml", "x-scheme-handler/https" }),
            default_app_data ("Mail Client", "x-scheme-handler/mailto"),
            default_app_data ("Calendar", "text/calendar"),
            default_app_data ("Music", "audio/x-vorbis+ogg", { "audio/*" }),
            default_app_data ("Video", "video/x-ogm+ogg", { "video/*" }),
            default_app_data ("Photos", "image/jpeg", { "image/*" }),
            default_app_data ("Text Editor", "text/plain"),
            default_app_data ("File Browser", "inode/directory"),
        };

        public Default_Apps (SettingsItem item, Hdy.Deck deck) {
            base (item, deck);
        }

        public override Gtk.Widget set_child () {
            var list_box = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE,
                vexpand = false,
                valign = Gtk.Align.START,
            };
            list_box.get_style_context ().add_class ("content");
            for (int i = 0; i < mime_types.length; i++) {
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
                set_default_app (def_app, selected_app);
            });
            return new List_Item (def_app.category_name, chooser, 56);
        }

        void set_default_app (default_app_data def_data, AppInfo selected_app) {
            set_default_for_mime (def_data.mime_type, selected_app);

            // Try to set as default for the other extra types
            if (def_data.extra_types.length > 0) {
                PatternSpec[] patterns = {};
                foreach (var type in def_data.extra_types) {
                    patterns += new PatternSpec (type);
                }

                foreach (var mime in selected_app.get_supported_types ()) {
                    bool found_match = false;
                    foreach (unowned PatternSpec pattern in patterns) {
                        if (pattern.match_string (mime)) {
                            found_match = true;
                            continue;
                        }
                    }
                    if (!found_match) continue;
                    set_default_for_mime (mime, selected_app);
                }
            }
        }

        void set_default_for_mime (string mime_type, AppInfo selected_app) {
            try {
                selected_app.set_as_default_for_type (mime_type);
            } catch (Error e) {
                stderr.printf ("Error! Could not set %s as default app!\n",
                               selected_app.get_name ());
            }
        }
    }

    public struct default_app_data {
        string category_name;
        string mime_type;
        string[] extra_types;

        default_app_data (string category_name,
                          string mime_type,
                          string[] extra_types = {}) {
            this.mime_type = mime_type;
            this.category_name = category_name;
            this.extra_types = extra_types;
        }
    }
}
