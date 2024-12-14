namespace SwaySettings {
    public class BluetoothPage : Page {

        private const string NEARBY_EMPTY_TEXT = "No devices found";
        private const string PAIRED_EMPTY_TEXT = "No devices paired";

        Gtk.Stack stack;
        Gtk.Box error_box;
        Gtk.Box bluetooth_box;
        Gtk.ScrolledWindow scrolled_window;

        public string error_text { get; private set; }

        Gtk.Label status_label;
        Gtk.Switch status_switch;
        bool pending_status_switch = false;

        Gtk.Spinner discovering_spinner;

        Gtk.ListBox paired_list_box;

        Gtk.ListBox nearby_list_box;

        Bluez.Daemon daemon;

        public BluetoothPage (SettingsItem item, Adw.NavigationPage page) {
            base (item, page);
        }

        public override async void on_back (Adw.NavigationPage page) {
            this.freeze_notify ();
            if (this.daemon.powered || this.daemon.discovering) {
                yield this.daemon.set_discovering_state (false);
            }
            yield this.daemon.unregister_agent ();
        }

        public override void on_refresh () {
            // Init Bluetooth Daemon
            this.daemon = new Bluez.Daemon ();

            Gtk.Box content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            set_child (content_box);

            // Bluetooth status
            Gtk.Box status_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            Gtk.Box toggle_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            status_box.append (toggle_box);
            Adw.Clamp clamp = get_clamped_widget (status_box, false);
            content_box.append (clamp);

            Gtk.Label title_label = new Gtk.Label ("Bluetooth") {
                hexpand = true,
                halign = Gtk.Align.START,
                valign = Gtk.Align.CENTER,
            };
            // TODO: Replace with title-1?
            title_label.add_css_class ("large-title");
            toggle_box.append (title_label);

            this.status_switch = new Gtk.Switch () {
                halign = Gtk.Align.END,
                valign = Gtk.Align.CENTER,
            };
            toggle_box.append (this.status_switch);

            // Discoverable Label
            this.status_label = new Gtk.Label (null) {
                hexpand = true,
                halign = Gtk.Align.START,
                valign = Gtk.Align.CENTER,
                visible = true,
            };
            this.status_label.add_css_class ("subtitle");
            status_box.append (this.status_label);

            // Bluetooth devices
            stack = new Gtk.Stack () {
                // TODO: FIX fade when disabled
                transition_type = Gtk.StackTransitionType.CROSSFADE,
                vhomogeneous = false,
            };
            // stack.set_transition_type (Gtk.StackTransitionType.CROSSFADE);

            // Add the main GTK Box
            bluetooth_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            this.scrolled_window = get_scroll_widget (bluetooth_box);
            stack.add_child (this.scrolled_window);

            // Error Page
            error_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 16) {
                sensitive = false,
                vexpand = true,
                valign = Gtk.Align.CENTER,
            };
            stack.add_child (error_box);
            // Error Image
            Gtk.Image error_image = new Gtk.Image () {
                pixel_size = 128,
            };
            error_image.set_from_icon_name ("bluetooth-symbolic");
            error_box.append (error_image);
            // Error Label
            Gtk.Label error_label = new Gtk.Label (null);
            this.bind_property ("error-text",
                                error_label, "label",
                                BindingFlags.SYNC_CREATE);
            error_box.append (error_label);

            // Setup each ListBox
            // Paired List Box
            paired_list_box = new Gtk.ListBox () {
                valign = Gtk.Align.START,
                selection_mode = Gtk.SelectionMode.NONE,
            };
            Gtk.Box paired_box = get_list_box (true,
                                               ref paired_list_box,
                                               "Paired Devices");
            bluetooth_box.append (paired_box);
            // Nearby List Box
            nearby_list_box = new Gtk.ListBox () {
                valign = Gtk.Align.FILL,
                selection_mode = Gtk.SelectionMode.NONE,
            };
            Gtk.Box nearby_box = get_list_box (false,
                                               ref nearby_list_box,
                                               "Nearby Devices");
            bluetooth_box.append (nearby_box);

            content_box.append (stack);

            remove_signals ();
            add_signals ();

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
        }

        Gtk.Box get_list_box (bool is_paired,
                              ref Gtk.ListBox list_box,
                              string title) {
            list_box.add_css_class ("content");
            // Sets the sorting function
            list_box.set_sort_func ((Gtk.ListBoxSortFunc) this.list_box_sort_func);
            // Add placeholder
            var placeholder_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                vexpand = true,
                hexpand = true,
                valign = Gtk.Align.CENTER,
                halign = Gtk.Align.CENTER,
                margin_top = 24,
                margin_bottom = 24,
                margin_start = 24,
                margin_end = 24,
                sensitive = false,
            };

            Gtk.Image placeholder_image = new Gtk.Image () {
                pixel_size = 72,
            };
            placeholder_image.set_from_icon_name ("bluetooth-symbolic");
            placeholder_box.append (placeholder_image);
            // Error Label
            Gtk.Label placeholder_label = new Gtk.Label (
                is_paired ? PAIRED_EMPTY_TEXT : NEARBY_EMPTY_TEXT);
            placeholder_box.append (placeholder_label);

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
                spinner_box.append (label);
                _box.append (spinner_box);

                // Add discovering spinner
                this.discovering_spinner = new Gtk.Spinner ();
                spinner_box.append (this.discovering_spinner);
            } else {
                _box.append (label);
            }

            _box.append (list_box);
            return _box;
        }

        [CCode (instance_pos = -1)]
        int list_box_sort_func (BluetoothDeviceRow a, BluetoothDeviceRow b) {
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
            this.daemon.adapter_added.connect_after (this.adapter_added_cb);
            this.daemon.adapter_removed.connect_after (this.adapter_removed_cb);
            this.daemon.device_added.connect_after (this.device_added_cb);
            this.daemon.device_removed.connect_after (this.device_removed_cb);

            this.daemon.bluetooth_bus_state_change.connect (this.bus_state_change_cb);
            this.daemon.notify["powered"].connect (this.powered_state_change_cb);
            this.daemon.notify["rfkill-blocking"].connect (this.powered_state_change_cb);
            this.daemon.notify["discovering"].connect (this.discovering_cb);
            this.status_switch.state_set.connect (this.status_switch_cb);
        }

        void remove_signals () {
            this.daemon.adapter_added.disconnect (this.adapter_added_cb);
            this.daemon.adapter_removed.disconnect (this.adapter_removed_cb);
            this.daemon.device_added.disconnect (this.device_added_cb);
            this.daemon.device_removed.disconnect (this.device_removed_cb);

            this.daemon.bluetooth_bus_state_change.disconnect (this.bus_state_change_cb);
            this.daemon.notify["powered"].disconnect (this.powered_state_change_cb);
            this.daemon.notify["rfkill-blocking"].disconnect (this.powered_state_change_cb);
            this.daemon.notify["discovering"].disconnect (this.discovering_cb);
            this.status_switch.state_set.disconnect (this.status_switch_cb);
        }

        void adapter_added_cb (Bluez.Adapter1 adapter) {
            error_text = "";
            powered_state_change_cb ();
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
            var row = new BluetoothDeviceRow (_device, adapter);
            // Watch property changes
            row.on_update.connect (this.device_changed_cb);
            list_box.append (row);
        }

        void device_removed_cb (Bluez.Device1 device) {
            BoolFunc<Gtk.Widget> func = (widget) => {
                if (widget is BluetoothDeviceRow) {
                    BluetoothDeviceRow row = (BluetoothDeviceRow) widget;
                    if (row.device == device) {
                        // Remove watch property changes
                        row.before_destroy ();
                        row.destroy ();
                        return true;
                    }
                }
                return false;
            };
            Functions.iter_listbox_children (paired_list_box, func);
            Functions.iter_listbox_children (nearby_list_box, func);
        }

        void device_changed_cb (BluetoothDeviceRow row) {
            if (!(row.parent is Gtk.ListBox)) {
                return;
            }
            Gtk.ListBox parent = (Gtk.ListBox) row.parent;
            bool paired = row.device.paired;

            // Move the Row to the correct LisBox
            // Moving the Row causes a few GTK critical warnings, so
            // creating a new row is the only option...
            unowned Gtk.ListBox ? remove_list_box = null;
            unowned Gtk.ListBox ? add_list_box = null;
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
                var device = new BluetoothDeviceRow (row.device, adapter);
                add_list_box.append (device);
                row.before_destroy ();
                row.destroy ();
            }
        }

        /**
         * Called when ever the status switch is clicked.
         * Waits until the powered state changes.
         */
        bool status_switch_cb (Gtk.Switch _switch, bool state) {
            pending_status_switch = true;
            _switch.sensitive = false;
            _switch.state_set.disconnect (this.status_switch_cb);
            this.daemon.change_bluetooth_state.begin (state, () => {
                pending_status_switch = false;
                _switch.sensitive = true;
                _switch.set_state (state);
                _switch.state_set.connect (this.status_switch_cb);
            });
            return true;
        }

        void bus_state_change_cb (bool state) {
            if (!state) {
                error_text = "The Bluetooth service is not running...";
                stack.set_visible_child (error_box);
            } else {
                this.powered_state_change_cb ();
                this.daemon.register_agent.begin (
                    (Gtk.Window) this.get_root ());
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
            bool blocking = this.daemon.rfkill_blocking;
            this.status_switch.state_set.disconnect (this.status_switch_cb);
            if (!blocking && powered) {
                stack.set_visible_child (scrolled_window);
                if (!pending_status_switch) status_switch.set_active (true);
            } else {
                error_text = "Bluetooth is disabled";
                stack.set_visible_child (error_box);
                if (!pending_status_switch) status_switch.set_active (false);
            }
            this.status_switch.state_set.connect (this.status_switch_cb);
        }
    }
}
