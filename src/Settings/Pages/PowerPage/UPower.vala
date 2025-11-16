namespace Up {
    public const string UPOWER_NAME = "org.freedesktop.UPower";
    public const string UPOWER_PATH = "/org/freedesktop/UPower/devices/";

    [DBus (name = "org.freedesktop.UPower.Device")]
    /** https://upower.freedesktop.org/docs/Device.html */
    public interface DeviceProxy : DBusProxy {
        [DBus (name = "EnableChargeThreshold")]
        public abstract void enable_charge_threshold (bool chargeThreshold) throws Error;
    }

    public static DeviceProxy ?get_device_proxy (Up.Device device) {
        try {
            return Bus.get_proxy_sync<DeviceProxy> (BusType.SYSTEM,
                                                    UPOWER_NAME, device.get_object_path (),
                                                    DBusProxyFlags.NONE);
        } catch (Error e) {
            critical (e.message);
            return null;
        }
    }
}
