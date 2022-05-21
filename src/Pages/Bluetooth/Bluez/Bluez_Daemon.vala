namespace Bluez {
    class Daemon : Object {
        private DBusObjectManager ? object_manager;

        public signal void adapter_added (Adapter1 adapter);
        public signal void adapter_removed (Adapter1 adapter);
        public signal void device_added (Device1 device);
        public signal void device_removed (Device1 device);

        public signal void bluetooth_bus_state_change (bool enabled);

        public bool powered { get; private set; }
        public bool discovering { get; private set; }
        public bool discoverable { get; private set; }

        uint watch_bluez_id = 0;

        Rfkill.Rfkill rfkill;
        public bool rfkill_blocking { get; private set; }

        public void start () {
            if (watch_bluez_id > 0) Bus.unwatch_name (watch_bluez_id);

            this.watch_bluez_id = Bus.watch_name (
                BusType.SYSTEM,
                "org.bluez",
                BusNameWatcherFlags.NONE,
                (connection, name, name_owner) => {
                init ();
                bluetooth_bus_state_change (true);
            },
                (connection, name) => {
                bluetooth_bus_state_change (false);
            });

            this.rfkill = new Rfkill.Rfkill (Linux.RfKillType.BLUETOOTH);
            this.rfkill_blocking = rfkill.blocked;
            this.rfkill.on_update.connect ((event, blocked) => {
                this.rfkill_blocking = blocked;
            });
        }

        private void init () {
            try {
                this.object_manager = new DBusObjectManagerClient.for_bus_sync (
                    BusType.SYSTEM,
                    DBusObjectManagerClientFlags.NONE,
                    "org.bluez",
                    "/",
                    this.get_proxy_type_func,
                    null);

                foreach (DBusObject object in object_manager.get_objects ()) {
                    foreach (DBusInterface iface in object.get_interfaces ()) {
                        on_interface_added_cb (object, iface);
                    }
                }
                object_manager.interface_added.connect (this.on_interface_added_cb);
                object_manager.interface_removed.connect (this.on_interface_removed_cb);
                object_manager.object_added.connect (this.on_object_added_cb);
                object_manager.object_removed.connect (this.on_object_removed_cb);

                // Init the powered state and start looking for devices if powered
                if (this.check_adapter_powered ()) {
                    this.set_discovering_state.begin (true);
                }
                check_adapter_discovering ();
                check_adapter_discoverable ();

                bluetooth_bus_state_change (true);
            } catch (Error e) {
                stderr.printf ("Init Error: %s\n", e.message);
                bluetooth_bus_state_change (false);
            }
        }

        private void on_object_added_cb (DBusObject object) {
            foreach (DBusInterface iface in object.get_interfaces ()) {
                on_interface_added_cb (object, iface);
            }
        }

        private void on_object_removed_cb (DBusObject object) {
            foreach (DBusInterface iface in object.get_interfaces ()) {
                on_interface_removed_cb (object, iface);
            }
        }

        private void on_interface_added_cb (DBusObject object, DBusInterface iface) {
            if (iface is Adapter1) {
                Adapter1 adapter = (Adapter1) iface;

                // Watch property changes
                ((DBusProxy) adapter).g_properties_changed.connect ((changed, invalid) => {
                    var powered = changed.lookup_value ("Powered",
                                                        VariantType.BOOLEAN);
                    if (powered != null) {
                        this.check_adapter_powered ();
                    }

                    var discovering = changed.lookup_value ("Discovering",
                                                            VariantType.BOOLEAN);
                    if (discovering != null) {
                        this.check_adapter_discovering ();
                    }

                    var adapter_discoverable = changed.lookup_value ("Discoverable",
                                                                     VariantType.BOOLEAN);
                    if (adapter_discoverable != null) {
                        check_adapter_discoverable ();
                    }
                });

                this.adapter_added (adapter);
            } else if (iface is Device1) {
                Device1 device = (Device1) iface;

                this.device_added (device);
            }
        }

        private void on_interface_removed_cb (DBusObject object, DBusInterface iface) {
            if (iface is Adapter1) {
                if (get_adapters ().is_empty ()) {
                    this.powered = false;
                    this.discovering = false;
                    this.discoverable = false;
                }
                Adapter1 adapter = (Adapter1) iface;
                adapter_removed (adapter);
                // has_object = !get_adapters ().is_empty;
            } else if (iface is Device1) {
                Device1 device = (Device1) iface;
                device_removed (device);
            }
        }

        public bool check_adapter_powered () {
            if (rfkill_blocking) return false;
            foreach (Adapter1 adapter in this.get_adapters ()) {
                if (adapter.powered) {
                    this.powered = true;
                    return true;
                }
            }
            this.powered = false;
            return false;
        }

        public void check_adapter_discovering () {
            foreach (Adapter1 adapter in this.get_adapters ()) {
                if (adapter.discovering) {
                    this.discovering = true;
                    return;
                }
            }
            this.discovering = false;
        }

        public void check_adapter_discoverable () {
            foreach (Adapter1 adapter in this.get_adapters ()) {
                if (adapter.discoverable) {
                    this.discoverable = true;
                    return;
                }
            }
            this.discoverable = false;
        }

        public Bluez.Adapter1 ? get_adapter (ObjectPath path) {
            if (object_manager == null) return null;
            DBusObject ? object = object_manager.get_object (path);
            if (object != null) {
                var iface = object.get_interface ("org.bluez.Adapter1");
                if (iface is Bluez.Adapter1) return (Bluez.Adapter1) iface;
            }
            return null;
        }

        public List<Adapter1> get_adapters () {
            var list = new List<Adapter1> ();
            if (this.object_manager == null) return (owned) list;
            foreach (DBusObject object in object_manager.get_objects ()) {
                DBusInterface ? iface = object.get_interface ("org.bluez.Adapter1");
                if (iface == null) continue;
                list.append ((Adapter1) iface);
            }
            return (owned) list;
        }

        public Bluez.Device1 ? get_device (string path) {
            if (object_manager == null) return null;
            DBusObject ? object = object_manager.get_object (path);
            if (object != null) {
                var iface = object.get_interface ("org.bluez.Device1");
                if (iface is Bluez.Device1) return (Bluez.Device1) iface;
            }
            return null;
        }

        public List<Device1> get_devices () {
            var list = new List<Device1> ();
            if (this.object_manager == null) return (owned) list;
            foreach (DBusObject object in object_manager.get_objects ()) {
                DBusInterface ? iface = object.get_interface ("org.bluez.Device1");
                if (iface == null) continue;
                list.append ((Device1) iface);
            }
            return (owned) list;
        }

        public string ? get_alias () {
            var adapters = get_adapters ();
            if (adapters.is_empty ()) return null;
            return adapters.first ().data.alias;
        }

        public async void change_bluetooth_state (bool state) {
            if (state) {
                this.rfkill.try_set_blocking (false);
            } else {
                // Set discovering to state to false before powering off
                yield this.set_discovering_state (false);

                // Disconnect all connected devices
                foreach (Device1 device in get_devices ()) {
                    if (!device.connected) continue;
                    try {
                        yield device.disconnect ();
                    } catch (Error e) {
                        stderr.printf ("Change_bluetooth_state Error: %s\n",
                                       e.message);
                    }
                }
            }

            // Set Adapter powered state and wait until their
            // powered state has changed
            uint num_powered = 0;
            var adapters = get_adapters ();
            foreach (Adapter1 adapter in adapters) {
                adapter.powered = state;
                DBusProxy pxy = ((DBusProxy) adapter);
                ulong id = 0;
                id = pxy.g_properties_changed.connect ((cgd, inv) => {
                    var powered = cgd.lookup_value ("Powered", VariantType.BOOLEAN);
                    if (powered != null && powered.get_boolean () == state) {
                        num_powered += 1;
                        if (num_powered == adapters.length ()) {
                            change_bluetooth_state.callback ();
                        }
                        pxy.disconnect (id);
                    }
                });
            }
            yield;
            powered = state;

            if (state) {
                // Set discovering to state
                yield this.set_discovering_state (state);
            } else {
                this.rfkill.try_set_blocking (true);
            }
        }

        public async bool set_discovering_state (bool state) {
            bool return_value = true;

            var adapters = get_adapters ();
            if (adapters.is_empty ()) return false;

            foreach (Adapter1 adapter in adapters) {
                try {
                    if (state) {
                        if (adapter.discovering) continue;
                        yield adapter.start_discovery ();
                    } else {
                        if (!adapter.discovering) continue;
                        yield adapter.stop_discovery ();
                    }
                } catch (Error e) {
                    stderr.printf ("Set_discovering_state Error: %s\n", e.message);
                    return_value = false;
                }
            }
            this.discovering = state;
            return return_value;
        }

        Type device1_proxy_type = SwaySettings.Functions.get_proxy_gtype<Device1> ();
        Type adapter1_proxy_type = SwaySettings.Functions.get_proxy_gtype<Adapter1> ();
        private Type get_proxy_type_func (DBusObjectManagerClient manager,
                                          string object_path,
                                          string ? interface_name) {
            if (interface_name == null)
                return typeof (DBusObjectProxy);

            switch (interface_name) {
                case "org.bluez.Device1":
                    return device1_proxy_type;
                case "org.bluez.Adapter1":
                    return adapter1_proxy_type;
                default:
                    return typeof (DBusProxy);
            }
        }
    }
}
