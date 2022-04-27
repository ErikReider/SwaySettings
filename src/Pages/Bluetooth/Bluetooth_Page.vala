namespace SwaySettings {
    public class Bluetooth_Page : Page {

        private const string nearby_empty_text = "No devices found";
        private const string paired_empty_text = "No devices paired";

        Gtk.Stack stack;
        Gtk.Box error_box;
        Gtk.Box bluetooth_box;
        Gtk.ScrolledWindow scrolled_window;

        public string error_text { get; private set; }

        Gtk.Label status_label;
        Gtk.Switch status_switch;

        Gtk.Spinner discovering_spinner;

        Gtk.ListBox paired_list_box;
        Gtk.Box paired_box;

        Gtk.ListBox nearby_list_box;
        Gtk.Box nearby_box;

        Bluez.Daemon daemon;

        public Bluetooth_Page (string page_name, Hdy.Deck deck, IPC ipc) {
            base (page_name, deck, ipc);
        }

        public override void on_back (Hdy.Deck deck) {
            this.remove_signals ();
            this.daemon.set_discovering_state.begin (false);
        }

        public override void on_refresh () {
            // Init Bluetooth Daemon
            this.daemon = new Bluez.Daemon ();

            // Remove all children in content_box
            foreach (var child in content_box.get_children ()) {
                content_box.remove (child);
            }

            // Bluetooth status
            Gtk.Box status_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            Gtk.Box toggle_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            status_box.add (toggle_box);
            Hdy.Clamp clamp = get_clamped_widget (status_box, false);
            content_box.add (clamp);

            Gtk.Label title_label = new Gtk.Label ("Bluetooth") {
                hexpand = true,
                halign = Gtk.Align.START,
                valign = Gtk.Align.CENTER,
            };
            title_label.get_style_context ().add_class ("large-title");
            toggle_box.add (title_label);

            this.status_switch = new Gtk.Switch () {
                halign = Gtk.Align.END,
                valign = Gtk.Align.CENTER,
            };
            toggle_box.add (this.status_switch);

            // Discoverable Label
            this.status_label = new Gtk.Label (null) {
                hexpand = true,
                halign = Gtk.Align.START,
                valign = Gtk.Align.CENTER,
                visible = true,
            };
            this.status_label.get_style_context ().add_class ("subtitle");
            status_box.add (this.status_label);

            clamp.show_all ();

            // Bluetooth devices
            stack = new Gtk.Stack () {
                transition_type = Gtk.StackTransitionType.CROSSFADE,
                vhomogeneous = false,
            };

            // Error Page
            error_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 16) {
                sensitive = false,
                vexpand = true,
                valign = Gtk.Align.CENTER,
            };
            stack.add (error_box);
            // Error Image
            Gtk.Image error_image = new Gtk.Image () {
                pixel_size = 128,
                opacity = 0.5,
            };
            error_image.set_from_icon_name ("bluetooth-active-symbolic",
                                            Gtk.IconSize.INVALID);
            error_box.add (error_image);
            // Error Label
            Gtk.Label error_label = new Gtk.Label (null);
            this.bind_property ("error-text",
                                error_label, "label",
                                BindingFlags.SYNC_CREATE);
            error_box.add (error_label);

            // Add the main GTK Box
            bluetooth_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            this.scrolled_window = get_scroll_widget (bluetooth_box);
            stack.add (this.scrolled_window);

            // Setup each ListBox
            // Paired List Box
            paired_list_box = new Gtk.ListBox () {
                valign = Gtk.Align.START,
                selection_mode = Gtk.SelectionMode.NONE,
            };
            this.paired_box = get_list_box (true,
                                            ref paired_list_box,
                                            "Paired Devices");
            bluetooth_box.add (this.paired_box);
            // Nearby List Box
            nearby_list_box = new Gtk.ListBox () {
                valign = Gtk.Align.FILL,
                selection_mode = Gtk.SelectionMode.NONE,
            };
            this.nearby_box = get_list_box (false,
                                            ref nearby_list_box,
                                            "Nearby Devices");
            bluetooth_box.add (this.nearby_box);

            stack.show_all ();
            content_box.add (stack);

            remove_signals ();
            add_signals ();

            // Bind the powered bool value to the switch state
            this.daemon.bind_property ("powered",
                                       this.status_switch, "active",
                                       BindingFlags.SYNC_CREATE);
            // Bind the discoverable bool value to the Label text
            this.daemon.bind_property ("discoverable",
                                       status_label, "label",
                                       BindingFlags.SYNC_CREATE,
                                       (bind, from_value, ref to_value) => {
                to_value = "";
                if (!from_value.holds (Type.BOOLEAN)) return false;
                string ? name = this.daemon.get_alias ();
                if (!from_value.get_boolean () || name == null) return true;
                to_value = @"Discoverable as \"$(name)\"";
                return true;
            });

            this.daemon.start ();

            this.powered_state_change_cb ();

            // Start looking for devices
            if (this.daemon.check_adapter_powered ()) {
                this.daemon.set_discovering_state.begin (true);
            }
        }

        Gtk.Box get_list_box (bool is_paired,
                              ref Gtk.ListBox list_box,
                              string title) {
            list_box.get_style_context ().add_class ("content");
            // Sets the sorting function
            list_box.set_sort_func ((Gtk.ListBoxSortFunc) this.list_box_sort_func);
            // Add placeholder
            var placeholder_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                expand = true,
                valign = Gtk.Align.CENTER,
                halign = Gtk.Align.CENTER,
                margin = 24,
                sensitive = false,
            };

            Gtk.Image placeholder_image = new Gtk.Image () {
                pixel_size = 72,
                opacity = 0.5,
            };
            placeholder_image.set_from_icon_name ("bluetooth-active-symbolic",
                                                  Gtk.IconSize.INVALID);
            placeholder_box.add (placeholder_image);
            // Error Label
            Gtk.Label placeholder_label = new Gtk.Label (
                is_paired ? paired_empty_text : nearby_empty_text);
            placeholder_box.add (placeholder_label);

            placeholder_box.show_all ();
            list_box.set_placeholder (placeholder_box);

            var _box = new Gtk.Box (Gtk.Orientation.VERTICAL, 10) {
                valign = is_paired ? Gtk.Align.START : Gtk.Align.FILL,
                vexpand = !is_paired,
            };

            var label = new Gtk.Label (title) {
                halign = Gtk.Align.START,
                valign = Gtk.Align.CENTER,
            };
            if (!is_paired) {
                var spinner_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
                spinner_box.add (label);
                _box.add (spinner_box);

                // Add discovering spinner
                this.discovering_spinner = new Gtk.Spinner ();
                spinner_box.add (this.discovering_spinner);
            } else {
                _box.add (label);
            }

            _box.add (list_box);
            return _box;
        }

        [CCode (instance_pos = -1)]
        int list_box_sort_func (Bluetooth_Device_Row a, Bluetooth_Device_Row b) {
            Bluez.Device1 a_device = a.device;
            Bluez.Device1 b_device = b.device;

            int16 a_range = a.device.rssi;
            int16 b_range = b.device.rssi;
            if (a_range == b_range) {
                string a_name = a_device.name ?? a_device.address;
                string b_name = b_device.name ?? b_device.address;
                return a_name.collate (b_name);
            }
            // Rows with RSSI values of 0 should be on the bottom
            if (a_range == 0) return 1;
            if (b_range == 0) return -1;
            // Shortest range on top
            return a_range < b_range ? 1 : -1;
        }

        void add_signals () {
            this.daemon.adapter_removed.connect_after (this.adapter_removed_cb);
            this.daemon.device_added.connect_after (this.device_added_cb);
            this.daemon.device_removed.connect_after (this.device_removed_cb);

            this.daemon.bluetooth_bus_state_change.connect (this.bus_state_change_cb);
            this.daemon.notify["powered"].connect (this.powered_state_change_cb);
            this.daemon.notify["discovering"].connect (this.discovering_cb);
            this.status_switch.notify["active"].connect (this.status_switch_cb);
        }

        void remove_signals () {
            this.daemon.adapter_removed.disconnect (this.adapter_removed_cb);
            this.daemon.device_added.disconnect (this.device_added_cb);
            this.daemon.device_removed.disconnect (this.device_removed_cb);

            this.daemon.bluetooth_bus_state_change.disconnect (this.bus_state_change_cb);
            this.daemon.notify["powered"].disconnect (this.powered_state_change_cb);
            this.daemon.notify["discovering"].disconnect (this.discovering_cb);
            this.status_switch.notify["active"].disconnect (this.status_switch_cb);
        }

        void adapter_removed_cb (Bluez.Adapter1 adapter) {
            var adapters = this.daemon.get_adapters ();
            if (adapters.is_empty ()) {
                error_text = "No Bluetooth Adapters available";
                stack.set_visible_child (error_box);
            }
        }

        void device_added_cb (Bluez.Device1 device) {
            unowned Gtk.ListBox list_box = device.paired ? paired_list_box : nearby_list_box;

            var adapter = this.daemon.get_adapter (device.adapter);
            var _device = this.daemon.get_device (
                ((DBusProxy) device).get_object_path ());
            var row = new Bluetooth_Device_Row (_device, adapter);
            // Watch property changes
            row.on_update.connect (this.device_changed_cb);
            list_box.add (row);
        }

        void device_removed_cb (Bluez.Device1 device) {
            unowned Gtk.ListBox list_box = device.paired ? paired_list_box : nearby_list_box;

            foreach (var child in list_box.get_children ()) {
                if (child == null || !(child is Bluetooth_Device_Row)) continue;
                var row = (Bluetooth_Device_Row) child;
                if (row.device == device) {
                    // Remove watch property changes
                    row.on_update.disconnect (this.device_changed_cb);
                    list_box.remove (child);
                    break;
                }
            }
        }

        void device_changed_cb (Bluetooth_Device_Row row) {
            Gtk.Container parent = row.parent;
            bool paired = row.device.paired;
            // bool trusted = row.device.trusted;
            // bool blocked = row.device.blocked;

            // Move the Row to the correct LisBox
            // Moving the Row causes a few GTK critical warnings, so
            // creating a new row is the only option...
            Gtk.ListBox * remove_list_box = null;
            Gtk.ListBox * add_list_box = null;
            if (paired && parent != paired_list_box) {
                add_list_box = paired_list_box;
                remove_list_box = nearby_list_box;
            }
            if (!paired && parent != nearby_list_box) {
                add_list_box = nearby_list_box;
                remove_list_box = paired_list_box;
            }

            if (remove_list_box != null && add_list_box != null) {
                var adapter = this.daemon.get_adapter (row.device.adapter);
                var device = new Bluetooth_Device_Row (row.device, adapter);
                add_list_box->add (device);
                remove_list_box->remove (row);
            }
        }

        async void status_switch_cb () {
            this.status_switch.notify["active"].disconnect (this.status_switch_cb);
            this.status_switch.sensitive = false;

            bool active = this.status_switch.active;
            yield this.daemon.change_bluetooth_state (active);

            this.status_switch.notify["active"].connect (this.status_switch_cb);
            this.status_switch.sensitive = true;
        }

        void bus_state_change_cb (bool state) {
            if (!state) {
                error_text = "The Bluetooth service is not running...";
                stack.set_visible_child (error_box);
            } else {
                this.powered_state_change_cb ();
            }
        }

        void discovering_cb () {
            bool discovering = this.daemon.discovering;
            if (discovering) {
                this.discovering_spinner.start ();
            } else {
                this.discovering_spinner.stop ();
            }
        }

        void powered_state_change_cb () {
            bool powered = this.daemon.powered;
            if (powered) {
                stack.set_visible_child (scrolled_window);
            } else {
                error_text = "Bluetooth is disabled";
                stack.set_visible_child (error_box);
            }
        }
    }
}
