namespace SwaySettings {
    [GtkTemplate (ui = "/org/erikreider/swaysettings/ui/PowerDevice.ui")]
    public class PowerDevice : Gtk.ListBoxRow {
        [GtkChild]
        unowned Gtk.Image icon;

        [GtkChild]
        unowned Gtk.Label device_name;

        [GtkChild]
        unowned Gtk.Label battery_charging_state;

        [GtkChild]
        unowned Gtk.Separator separator;

        [GtkChild]
        unowned Gtk.Image battery_icon;

        [GtkChild]
        unowned Gtk.Label battery_percent;

        unowned Up.Device device;

        public PowerDevice (Up.Device device) {
            this.device = device;

            add_css_class ("power-device");

            device.notify["is-present"].connect (() => {
                set_visible (device.is_present);
            });

            device.notify.connect (set_ui);

            set_ui ();
        }

        private void set_ui () {
            icon.set_from_icon_name (UPower.UPowerBatteryState.get_device_icon_name (device.kind,
                                                                                   false));
            device_name.set_text (device.model);

            string ?state = UPower.UPowerBatteryState.get_battery_status (device);
            battery_charging_state.set_text (state);
            battery_charging_state.set_visible (state != null);

            separator.set_visible (battery_charging_state.visible);

            battery_icon.set_from_icon_name (device.icon_name);

            battery_percent.set_text (UPower.UPowerBatteryState.get_battery_percent (device, true));
        }
    }
}
