namespace SwaySettings {
    struct RegexPathPriority {
        string regex;
        int priority;
    }

    [GtkTemplate (ui = "/org/erikreider/swaysettings/ui/StorageRow.ui")]
    class StorageRow : Gtk.ListBoxRow {
        const string DEVICE_ICON_DRIVE = "drive-harddisk";
        const string DEVICE_ICON_REMOVABLE_DRIVE = "drive-removable-media";
        const string DEVICE_ICON_REMOVABLE_FLASH = "media-flash";
        const string DEVICE_ICON_REMOVABLE_FLOPPY = "media-floppy";
        const string DEVICE_ICON_OPTICAL = "media-optical";

        unowned UDisks.Client client;

        UDisks.Block block;
        UDisks.Filesystem filesystem;
        UDisks.Drive ?drive;

        [GtkChild]
        unowned Gtk.Image icon;
        [GtkChild]
        unowned Gtk.Label type_label;

        [GtkChild]
        unowned Gtk.Label name_label;
        [GtkChild]
        unowned Gtk.Label size_label;
        [GtkChild]
        unowned Gtk.Button browse_button;
        [GtkChild]
        unowned Gtk.ProgressBar usage_bar;

        bool mounted = false;
        uint64 total = 0;
        uint64 used = 0;
        uint64 available = 0;
        string ?total_str = null;
        string ?available_str = null;

        public int sorting_priority { get; private set; default = int.MAX; }
        public bool removable { get; private set; default = false; }
        public string drive_name { get; private set; default = ""; }

        public StorageRow(UDisks.Client client,
                          UDisks.Object object) {
            this.client = client;

            this.block = object.block;
            this.filesystem = object.filesystem;
            this.drive = client.get_drive_for_block (block);

            this.mounted = filesystem.mount_points.length > 0;

            this.total = block.size;
            this.total_str = format_size (total, FormatSizeFlags.IEC_UNITS);
            if (mounted) {
                Posix.statvfs buf;
                Posix.statvfs_exec (filesystem.mount_points[0], out buf);

                uint64 total = buf.f_blocks * buf.f_bsize;
                this.available = buf.f_bfree * buf.f_bsize;
                this.used = total - this.available;

                this.available_str = format_size (available,
                                                  FormatSizeFlags.IEC_UNITS);

                usage_bar.set_fraction ((double) used / total);

                browse_button.clicked.connect (() => {
                    File disk = File.new_for_path (filesystem.mount_points[0]);
                    if (!disk.query_exists ()) {
                        return;
                    }
                    var file_launcher = new Gtk.FileLauncher (disk);
                    file_launcher.launch.begin (null, null);
                });
            }
            this.set_sensitive (mounted);

            // Icon
            string icon = DEVICE_ICON_DRIVE;
            if (!block.hint_system) {
                removable = true;
                icon = DEVICE_ICON_REMOVABLE_DRIVE;
            }
            if (drive != null) {
                if (drive.media_removable || drive.removable) {
                    removable = true;
                    icon = DEVICE_ICON_REMOVABLE_DRIVE;
                }

                var media_icon = get_drive_icon_from_media_hint (drive);
                if (media_icon != null) {
                    icon = media_icon;
                }
            }
            this.icon.set_from_icon_name (icon);

            // FS
            type_label.set_text (block.id_type.up ());

            // Name
            drive_name = block.id_label;
            if (drive_name.length == 0) {
                drive_name = "%s %s Partition".printf (total_str,
                                                       block.id_type.up ());
            }
            if (block.read_only) {
                drive_name = "%s %s".printf (drive_name, "(Read-Only)");
            }
            name_label.set_text (drive_name);

            // Size
            string size_text = "Not Mounted";
            if (mounted) {
                size_text = "%s available of %s".printf (available_str,
                                                         total_str);
            }
            size_label.set_text (size_text);

            set_priority ();
        }

        private string ? get_drive_icon_from_media_hint (UDisks.Drive drive) {
            const ReplaceStrings STRINGS[] = {
                { "^thumb.*", DEVICE_ICON_REMOVABLE_DRIVE},
                { "^flash.*", DEVICE_ICON_REMOVABLE_FLASH},
                { "^floppy.*", DEVICE_ICON_REMOVABLE_FLOPPY},
                { "^optical.*", DEVICE_ICON_OPTICAL},
            };

            string pretty = Markup.escape_text (drive.media).strip ();
            if (pretty.length < 1) {
                return null;
            }

            try {
                foreach (ReplaceStrings replace_string in STRINGS) {
                    Regex re = new Regex (replace_string.regex, 0, 0);
                    bool matched = re.match (pretty);
                    pretty = re.replace (pretty, -1, 0,
                                         replace_string.replacement, 0);
                    if (matched) {
                        break;
                    }
                }
            } catch (Error e) {
                critical ("Couldn't cleanup vendor string: %s", e.message);
            }

            return pretty;
        }

        private void set_priority () {
            if (removable) {
                sorting_priority = -1;
                return;
            }
            if (!mounted) {
                return;
            }
            string mount_point = filesystem.mount_points[0];
            switch (mount_point) {
                case "/":
                    sorting_priority = 0;
                    return;
                case "/home":
                    sorting_priority = 1;
                    return;
                case "/usr":
                case "/data":
                    sorting_priority = 2;
                    return;
                case "/var":
                    sorting_priority = 3;
                    return;
                default:
                    break;
            }

            const RegexPathPriority PRIORITIES[] = {
                { "^/(usr|data|var).*", 2},
                { "^/mnt/.*", 3},
                { "^/run/.*", 4},
            };

            string pretty = Markup.escape_text (mount_point).strip ();
            if (pretty.length < 1) {
                return;
            }

            try {
                foreach (var priority in PRIORITIES) {
                    Regex re = new Regex (priority.regex, 0, 0);
                    bool matched = re.match (pretty);
                    if (matched) {
                        sorting_priority = priority.priority;
                        return;
                    }
                }
            } catch (Error e) {
                critical (e.message);
            }
        }
    }
}














