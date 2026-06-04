namespace SwaySettings.Pages.Pulse {
    [GtkTemplate (ui = "/org/erikreider/swaysettings/ui/PulseDeviceComboRowItem.ui")]
    private class DeviceComboRowItem : Gtk.Box {
        public string icon { get; private set; }
        public string display_name { get; private set; }
        public bool selected { get; set; default = false; }

        private bool is_in_popup = false;

        private unowned DeviceComboRow ?combo_row;
        private unowned PulseDevice ?device;

        private ulong device_id = 0;
        private ulong root_id = 0;
        private ulong selected_item_id = 0;

        public void bind (DeviceComboRow combo_row, Gtk.ListItem list_item) {
            this.combo_row = combo_row;
            device = (PulseDevice) list_item.item;

            // Update the row on PulseDevice changes
            if (device_id == 0) {
                device_id = device.changed.connect (update_ui);
                update_ui ();
            }

            // Hide the checkmark for non-popup items
            if (root_id == 0) {
                root_id = notify["root"].connect (check_is_popup);
                check_is_popup ();
            }

            // Update each rows checkmark on selected-item change
            if (selected_item_id == 0) {
                selected_item_id = combo_row.notify["selected-item"].connect (selection_changed_cb);
                selection_changed_cb ();
            }
        }

        public void unbind () {
            if (device_id > 0) {
                device.disconnect (device_id);
                device_id = 0;
            }
            if (root_id > 0) {
                disconnect (root_id);
                root_id = 0;
            }
            if (selected_item_id > 0) {
                combo_row.disconnect (selected_item_id);
                selected_item_id = 0;
            }
            combo_row = null;
            device = null;
            icon = "";
            display_name = "";
        }

        private void update_ui () {
            if (device == null) {
                icon = "";
                display_name = "";
                return;
            }
            icon = "%s-symbolic".printf (device.icon_name);
            display_name = device.get_display_name ();
        }

        private void check_is_popup () {
            unowned Gtk.Widget ?popover = get_ancestor (typeof (Gtk.Popover));
            this.is_in_popup = popover != null
                && popover.get_ancestor (typeof (Adw.ComboRow)) == combo_row;
        }

        private void selection_changed_cb () {
            this.selected = is_in_popup && combo_row.selected_item == device;
        }
    }
}
