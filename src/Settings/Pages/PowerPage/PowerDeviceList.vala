namespace SwaySettings {
    private class PowerDeviceList : Adw.Bin {
        private Gtk.ListBox list_box;

        private ListStore model;

        public uint n_devices { get; private set; default = 0; }

        construct {
            model = new ListStore (Type.OBJECT);

            list_box = new Gtk.ListBox ();
            list_box.bind_model (model, item_create_cb);
            list_box.add_css_class ("boxed-list");
            list_box.set_selection_mode (Gtk.SelectionMode.NONE);
            set_child (list_box);
        }

        private Gtk.Widget item_create_cb (Object item) {
            PowerDevice power_device = new PowerDevice ((Up.Device) item);

            return power_device;
        }

        public void add_device (owned Up.Device device) {
            if (device.power_supply) {
                return;
            }
            model.append (device);
            n_devices++;
        }

        public void remove_device (string object_path) {
            for (uint i = 0; i < n_devices; i++) {
                Up.Device ?device = (Up.Device ?) model.get_item (i);
                if (device == null) {
                    continue;
                }
                if (device.get_object_path () == object_path) {
                    model.remove (i);
                    n_devices--;
                    return;
                }
            }
        }
    }
}
