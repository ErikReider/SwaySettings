namespace SwaySettings {
    [GtkTemplate (ui = "/org/erikreider/swaysettings/Pages/Bluetooth/Bluetooth_Device_Row.ui")]
    class Bluetooth_Device_Row : Gtk.ListBoxRow {
        [GtkChild]
        private unowned Gtk.Image device_image;
        [GtkChild]
        private unowned Gtk.Label device_name;

        [GtkChild]
        private unowned Gtk.Label status_label;
        public string status { get; private set; }

        [GtkChild]
        private unowned Gtk.Button remove_button;
        [GtkChild]
        private unowned Gtk.Button connect_button;

        public Bluez.Device1 device { get; private set; }
        public Bluez.Adapter1 adapter { get; private set; }

        /** Gets called when Device Paired, Trusted or Blocked changes */
        public signal void on_update (Bluetooth_Device_Row row);

        public Bluetooth_Device_Row (Bluez.Device1 device, Bluez.Adapter1 adapter) {
            this.device = device;
            this.adapter = adapter;

            this.connect_button.clicked.connect (() => {
                if (device.connected) {
                    device.disconnect.begin ();
                } else {
                    device.connect.begin ();
                }
            });

            this.remove_button.clicked.connect (this.remove_button_clicked_cb);

            this.bind_property ("status",
                                status_label, "label",
                                BindingFlags.SYNC_CREATE);

            // Watch property changes
            ((DBusProxy) device).g_properties_changed.connect ((changed, invalid) => {
                // Only update when Paired, Trusted or Blocked changes
                var paired = changed.lookup_value ("Paired", VariantType.BOOLEAN);
                var trusted = changed.lookup_value ("Trusted", VariantType.BOOLEAN);
                var blocked = changed.lookup_value ("Blocked", VariantType.BOOLEAN);
                if (paired != null || trusted != null || blocked != null) {
                    on_update (this);
                }

                update_widget ();

                // Updates the ListBox sorting order
                this.changed ();
                // Without this, the style of each row would not be updated.
                // If the row has rounded borders, those borders would not update.
                // Would result in rounded rows in the middle
                this.parent.get_style_context ().changed ();
            });

            update_widget ();
        }

        /**
         * Sets all relevant widgets sensitivity to value.
         * Makes sure that remove_button sensitivity is always true
         */
        public void set_row_sensitivity (bool value) {
            this.remove_button.set_sensitive (true);
            this.device_image.set_sensitive (value);
            this.status_label.set_sensitive (value);
            this.device_name.set_sensitive (value);
            this.connect_button.set_sensitive (value);
        }

        public void update_widget () {
            // Only show devices with low RSSI if paired
            if (device.rssi == 0 && !device.connected) {
                set_row_sensitivity (false);
                if (this.device.paired) {
                    set_visible (true);
                    this.status = "Not in range";
                } else {
                    set_visible (false);
                    this.status = "";
                }
            } else {
                set_row_sensitivity (true);
                set_visible (true);
                if (device.connected) {
                    this.status = "Connected";
                } else {
                    this.status = "";
                }
            }

            device_name.set_label (device.alias);

            remove_button.set_visible (this.device.paired);

            connect_button.label = device.connected ? "Disconnect" : "Connect";

            const string default_icon = "bluetooth-symbolic.symbolic";
            string icon = default_icon;
            if (device.icon != null && device.icon.length > 0) icon = device.icon;
            if (!Gtk.IconTheme.get_default ().has_icon (icon)) {
                icon = default_icon;
            }
            device_image.set_from_icon_name (icon, Gtk.IconSize.INVALID);
            device_image.icon_size = 48;
        }

        private async void remove_button_clicked_cb () {
            if (!device.paired) return;

            const string title = "<b><big>Remove \"%s\"?</big></b>";
            const string sub = "If you remove the device, you will have to repair the device to use it.";
            var window = (Hdy.ApplicationWindow) this.get_toplevel ();

            var dialog = new Gtk.MessageDialog.with_markup (
                window,
                Gtk.DialogFlags.DESTROY_WITH_PARENT,
                Gtk.MessageType.QUESTION,
                Gtk.ButtonsType.OK_CANCEL,
                title,
                device.alias) {
                secondary_text = sub,
                secondary_use_markup = false,
            };
            var result = (Gtk.ResponseType) dialog.run ();
            dialog.close ();
            if (result == Gtk.ResponseType.OK) {
                try {
                    adapter.remove_device (new ObjectPath (((DBusProxy) device).g_object_path));
                } catch (Error e) {
                    stderr.printf ("Remove device Error: %s\n", e.message);
                }
            }
        }
    }
}
