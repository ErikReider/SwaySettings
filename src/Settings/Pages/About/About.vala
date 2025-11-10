namespace SwaySettings {
    [DBus (name = "net.hadess.SwitcherooControl")]
    public interface SwitcherooControl : Object {
        [DBus (name = "HasDualGpu")]
        public abstract bool has_dual_gpu { owned get; }

        [DBus (name = "GPUs")]
        public abstract HashTable<string,Variant>[] gpus { owned get; }
    }

    struct ReplaceStrings {
        string regex;
        string replacement;
    }

    public class AboutPC : PageScroll {
        public AboutPC (SettingsItem item,
                        Adw.NavigationPage page) {
            base (item, page);
        }

        public override Gtk.Widget set_child () {
            return new AboutPCContent ();
        }
    }

    [GtkTemplate (ui = "/org/erikreider/swaysettings/ui/AboutPCContent.ui")]
    private class AboutPCContent : Adw.Bin {
        string os_name = "Unknown";
        string version = "Unknown";
        string kernel_version = "Unknown";
        string logo = "item-missing-symbolic";
        string cpu_info = "Unknown";
        string memory = "Unknown";
        string graphics = "Unknown";

        unowned SwitcherooControl switcheroo = null;

        [GtkChild]
        unowned Gtk.Image os_image;
        [GtkChild]
        unowned Gtk.Label os_name_label;
        [GtkChild]
        unowned Gtk.Label os_version_label;
        [GtkChild]
        unowned Gtk.Label kernel_label;
        [GtkChild]
        unowned Gtk.Label cpu_label;
        [GtkChild]
        unowned Gtk.Label mem_label;
        [GtkChild]
        unowned Gtk.Label graphics_label;

        [GtkChild]
        unowned Gtk.ListBox storage_list_box;

        construct {
            storage_list_box.set_sort_func ((r1, r2) => {
                StorageRow row1 = (StorageRow)r1;
                StorageRow row2 = (StorageRow)r2;

                // Sort by name
                if (row1.sorting_priority == row2.sorting_priority) {
                    return row1.drive_name < row2.drive_name? -1 : 1;
                }
                // Sort by priority
                return row1.sorting_priority < row2.sorting_priority? -1: 1;
            });

            storage_list_box.set_header_func ((r, before) => {
                StorageRow row = (StorageRow)r;
                StorageRow before_row = (StorageRow)before;

                if (before == null || before_row.removable != row.removable) {
                    Gtk.Label header = new Gtk.Label (row.removable ?
                                                      "External Storage":
                                                      "Storage");
                    header.set_xalign (0.0f);
                    header.add_css_class ("title-2");
                    header.margin_top = 12;
                    header.margin_bottom = 12;
                    row.set_header (header);
                } else {
                    row.set_header (null);
                }
            });

            get_os_info ();
        }

        private void get_os_info () {
            // Distro Logo
            string ?logo = Environment.get_os_info ("LOGO");
            if (logo != null) {
                this.logo = logo;
            }
            os_image.set_from_icon_name (this.logo);

            // Distro name
            string ?os_name = Environment.get_os_info (OsInfoKey.NAME);
            if (os_name != null) {
                this.os_name = os_name;
            }
            os_name_label.set_text (this.os_name);

            // Distro version
            string ?version = Environment.get_os_info (OsInfoKey.VERSION);
            if (version != null) {
                this.version = version;
            }
            os_version_label.set_markup ("<b>Version</b>  %s".printf (
                                             this.version));

            // Kernel version
            var utsname = Posix.utsname ();
            kernel_version = "%s %s".printf (utsname.sysname,
                                             clean_name (utsname.release));
            kernel_label.set_markup ("<b>Kernel</b>  %s".printf (
                                         this.kernel_version));

            // CPU
            string ?cpu_info = get_cpu_string ();
            if (cpu_info != null) {
                this.cpu_info = cpu_info;
            }
            cpu_label.set_markup ("<b>CPU</b>  %s".printf (this.cpu_info));

            // Memory
            this.memory = get_mem_string ();
            mem_label.set_markup ("<b>Memory</b>  %s".printf (this.memory));

            // GPU
            get_gpu_info.begin (() => {
                graphics_label.set_markup (
                    "<b>Graphics</b>  %s".printf (this.graphics));
            });

            get_storage_devices.begin ();
        }

        private string ? get_cpu_string () {
            unowned GLibTop.sysinfo ?info = GLibTop.get_sysinfo ();
            if (info == null) {
                return null;
            }

            const string[] MODEL_KEYS = { "model name", "cpu", "Processor" };

            var cpus = new Gee.HashSet<string>();
            for (int i = 0; i < info.ncpu; i++) {
                unowned HashTable<string,
                                  string> values = info.cpuinfo[i].values;

                foreach (string key in MODEL_KEYS) {
                    string value;
                    if (values.lookup_extended (key, null, out value)) {
                        cpus.add (clean_name (value));
                        break;
                    }
                }
            }

            if (cpus.size > 0) {
                return string.joinv ("\n\t\t", cpus.to_array ());
            }

            return null;
        }

        private string get_mem_string () {
            GLibTop.mem mem;
            GLibTop.get_mem (out mem);
            return format_size (mem.total, FormatSizeFlags.IEC_UNITS);
        }

        private async void get_gpu_info () {
            if (switcheroo == null) {
                try {
                    switcheroo = yield Bus.get_proxy (
                        BusType.SYSTEM,
                        "net.hadess.SwitcherooControl",
                        "/net/hadess/SwitcherooControl");
                } catch (Error e) {
                    warning (e.message);
                    return;
                }
            }

            var gpus = new Gee.HashSet<string>();
            foreach (unowned HashTable<string,Variant> gpu in switcheroo.gpus) {
                Variant value;
                if (gpu.lookup_extended ("Name", null, out value)
                    && value.is_of_type (VariantType.STRING)) {
                    gpus.add (clean_name (value.get_string ()));
                }
            }

            if (gpus.size > 0) {
                graphics = string.joinv ("\n\t\t", gpus.to_array ());
            }
        }

        private async void get_storage_devices () {
            UDisks.Client client;
            try {
                client = yield new UDisks.Client (null);
            } catch (Error e) {
                warning (e.message);
                return;
            }

            List<DBusObject> objects = client.object_manager.get_objects ();
            foreach (unowned var obj in objects) {
                var object = ((UDisks.Object)obj);
                UDisks.Block block = object.block;
                UDisks.Filesystem filesystem = object.filesystem;

                if (block == null || block.hint_ignore
                    || filesystem == null) {
                    continue;
                }

                bool gvfs_show = true;
                if (block.configuration.n_children () > 0) {
                    gvfs_show = false;
                    Variant tuple =
                        block.configuration.get_child_value (0);
                    Variant args = tuple.get_child_value (1);
                    var value = args.lookup_value ("opts", null);
                    if (value != null) {
                        string opts = value.get_bytestring ();
                        gvfs_show = opts.contains ("x-gvfs-show");
                    }
                }

                bool is_boot_partition = false;
                foreach (var path in filesystem.mount_points) {
                    try {
                        Regex re = new Regex ("^(/boot|/efi).*", 0, 0);
                        bool matched = re.match (path);
                        if (matched) {
                            is_boot_partition = true;
                            break;
                        }
                    } catch (Error e) {
                        warning (e.message);
                    }
                }

                // Only display boot partitions if they are explicitly set
                // to be visible.
                if (!gvfs_show && is_boot_partition) {
                    continue;
                }

                storage_list_box.append (new StorageRow (client, object));
            }
        }

        // Thanks Elementary OS:
        // https://github.com/elementary/switchboard-plug-about
        private string clean_name (string info) {

            string pretty = Markup.escape_text (info).strip ();

            const ReplaceStrings REPLACE_STRINGS[] = {
                { "(\\d+\\.\\d+.\\d.-\\d+).*", "\\1"}, // Linux version
                { "Mesa DRI ", ""},
                { "Mesa (.*)", "\\1"},
                { "[(]R[)]", "®"},
                { "[(]TM[)]", "™"},
                { "Gallium .* on (AMD .*)", "\\1"},
                { "^(AMD .*) [(].*", "\\1"},
                { "^(AMD Ryzen) (.*)", "\\1 \\2"},
                { "^(AMD [A-Z])(.*)", "\\1\\L\\2\\E"},
                { "^Advanced Micro Devices, Inc\\. \\[.*?\\] .*? \\[(.*?)\\] .*",
                  "AMD \\1"},
                { "^Advanced Micro Devices, Inc\\. \\[.*?\\] (.*)", "AMD \\1"},
                { "Graphics Controller", "Graphics"},
                { "Intel Corporation", "Intel"},
                { "NVIDIA Corporation (.*) \\[(\\S*) (\\S*) (.*)\\]",
                  "NVIDIA® \\2 \\3 \\4"},
            };

            try {
                foreach (ReplaceStrings replace_string in REPLACE_STRINGS) {
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
    }
}
