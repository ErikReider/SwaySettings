namespace SwaySettings {
    private struct DefaultAppData {
        string category_name;
        string mime_type;
        string[] extra_types;

        DefaultAppData (string category_name,
                        string mime_type,
                        string[] extra_types = {}) {
            this.mime_type = mime_type;
            this.category_name = category_name;
            this.extra_types = extra_types;
        }
    }

    public class DefaultApps : PageScroll {
        private static DefaultAppData[] mime_types = {
            DefaultAppData ("Web Browser", "x-scheme-handler/http",
                            { "text/html", "application/xhtml+xml", "x-scheme-handler/https" }),
            DefaultAppData ("Mail Client", "x-scheme-handler/mailto"),
            DefaultAppData ("Calendar", "text/calendar"),
            DefaultAppData ("Music", "audio/x-vorbis+ogg", { "audio/*" }),
            DefaultAppData ("Video", "video/x-ogm+ogg", { "video/*" }),
            DefaultAppData ("Photos", "image/jpeg", { "image/*" }),
            DefaultAppData ("Text Editor", "text/plain"),
            DefaultAppData ("File Browser", "inode/directory"),
        };

        public DefaultApps (SettingsItem item, Adw.NavigationPage page) {
            base (item, page);
        }

        public override Gtk.Widget set_child () {
            var group = new Adw.PreferencesGroup ();
            foreach (unowned DefaultAppData type in mime_types) {
                group.add (get_item (type));
            }
            return group;
        }

        Adw.PreferencesRow get_item (DefaultAppData app_data) {
            AppChooserDropDown chooser = new AppChooserDropDown (app_data.mime_type) {
                title = app_data.category_name,
            };
            chooser.app_picked.connect ((selected_app) => {
                set_default_app (app_data, selected_app);
            });
            return chooser;
        }

        void set_default_app (DefaultAppData def_data, DesktopAppInfo selected_app) {
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
                    if (!found_match) {
                        continue;
                    }
                    set_default_for_mime (mime, selected_app);
                }
            }
        }

        void set_default_for_mime (string mime_type, DesktopAppInfo selected_app) {
            try {
                selected_app.set_as_default_for_type (mime_type);
            } catch (Error e) {
                stderr.printf ("Error! Could not set %s as default app!\n",
                               selected_app.get_name ());
            }
        }
    }
}
