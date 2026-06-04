namespace SwaySettings.Pages.Pulse {
    // TODO: Move into ListItem.vala?
    [GtkTemplate (ui = "/org/erikreider/swaysettings/ui/PulseDeviceComboRow.ui")]
    internal class DeviceComboRow : Adw.ComboRow {
        ListStore list_store;

        public bool is_empty { get; set; default = true; }

        public signal void selected_changed (PulseDevice ?device);

        private ulong selection_handler_id = 0;

        construct {
            list_store = new ListStore (typeof (PulseDevice));
            model = list_store;

            selection_handler_id = notify["selected"].connect (selection_changed_cb);
        }

        private void selection_changed_cb () {
            selected_changed ((PulseDevice ?) get_selected_item ());
        }

        [GtkCallback]
        private void factory_setup_cb (Gtk.SignalListItemFactory factory, Object obj) {
            Gtk.ListItem list_item = (Gtk.ListItem) obj;
            var row = new DeviceComboRowItem ();
            list_item.set_child (row);
        }

        [GtkCallback]
        private void factory_bind_cb (Gtk.SignalListItemFactory factory, Object obj) {
            Gtk.ListItem list_item = (Gtk.ListItem) obj;
            DeviceComboRowItem row = (DeviceComboRowItem) list_item.child;
            row.bind (this, list_item);
        }

        [GtkCallback]
        private void factory_unbind_cb (Gtk.SignalListItemFactory factory, Object obj) {
            Gtk.ListItem list_item = (Gtk.ListItem) obj;
            DeviceComboRowItem row = (DeviceComboRowItem) list_item.child;
            row.unbind ();
        }

        private static int combo_row_sort_func (Object _a, Object _b) {
            PulseDevice a = (PulseDevice) _a;
            PulseDevice b = (PulseDevice) _b;
            return strcmp (
                a.get_current_hash_key (),
                b.get_current_hash_key ());
        }

        public void add_device (PulseDevice device) {
            SignalHandler.block (this, selection_handler_id);
            list_store.insert_sorted (device, combo_row_sort_func);
            SignalHandler.unblock (this, selection_handler_id);

            is_empty = false;
        }

        public void remove_device (PulseDevice device) {
            uint position;
            bool found = list_store.find_with_equal_func (device,
                                                          IPulseModuleType.equals,
                                                          out position);
            if (!found) {
                return;
            }

            SignalHandler.block (this, selection_handler_id);
            list_store.remove (position);
            SignalHandler.unblock (this, selection_handler_id);

            if (list_store.n_items == 0) {
                is_empty = true;
            }
        }

        public void update_default_device (PulseDevice default_device) {
            // Skip if same
            unowned Object ?selected = get_selected_item ();
            if (selected is PulseDevice && default_device.cmp ((PulseDevice) selected)) {
                return;
            }

            for (uint i = 0; i < list_store.n_items; i++) {
                PulseDevice device = (PulseDevice) list_store.get_item (i);
                if (default_device.cmp (device)) {
                    SignalHandler.block (this, selection_handler_id);
                    set_selected (i);
                    SignalHandler.unblock (this, selection_handler_id);
                    return;
                }
            }
        }
    }
}
