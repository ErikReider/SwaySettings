namespace Bluez {
    // https://git.kernel.org/pub/scm/bluetooth/bluez.git/tree/doc/device-api.txt
    [DBus (name = "org.bluez.Device1")]
    public interface Device1 : Object {
        [DBus (name = "Disconnect")]
        public abstract async void disconnect () throws DBusError, IOError;
        [DBus (name = "Connect")]
        public abstract async void connect () throws DBusError, IOError;
        [DBus (name = "ConnectProfile")]
        public abstract void connect_profile (string UUID) throws DBusError, IOError;
        [DBus (name = "DisconnectProfile")]
        public abstract void disconnect_profile (string UUID) throws DBusError, IOError;
        [DBus (name = "Pair")]
        public abstract async void pair () throws DBusError, IOError;
        [DBus (name = "CancelPairing")]
        public abstract void cancel_pairing () throws DBusError, IOError;

        [DBus (name = "Address")]
        public abstract string address { owned get; }
        [DBus (name = "AddressType")]
        public abstract string address_type { owned get; }
        [DBus (name = "Name")]
        public abstract string name { owned get; }
        [DBus (name = "Alias")]
        public abstract string alias { owned get; set; }
        [DBus (name = "Class")]
        public abstract uint class_ { get; }
        [DBus (name = "Appearance")]
        public abstract uint appearance { get; }
        [DBus (name = "Icon")]
        public abstract string icon { owned get; }
        [DBus (name = "Paired")]
        public abstract bool paired { get; }
        [DBus (name = "Trusted")]
        public abstract bool trusted { get; set; }
        [DBus (name = "Blocked")]
        public abstract bool blocked { get; set; }
        [DBus (name = "LegacyPairing")]
        public abstract bool legacy_pairing { get; }
        [DBus (name = "RSSI")]
        public abstract int16 rssi { get; }
        [DBus (name = "Connected")]
        public abstract bool connected { get; }
        [DBus (name = "UUIDs")]
        public abstract string[] uuids { owned get; }
        [DBus (name = "Modalias")]
        public abstract string modalias { owned get; }
        [DBus (name = "Adapter")]
        public abstract ObjectPath adapter { owned get; }
        [DBus (name = "ManufacturerData")]
        public abstract HashTable<uint16, Variant> manufacturer_data { owned get; }
        [DBus (name = "ServiceData")]
        public abstract HashTable<string, Variant> service_data { owned get; }
        [DBus (name = "TxPower")]
        public abstract int16 tx_power { get; }
        [DBus (name = "ServicesResolved")]
        public abstract bool services_resolved { get; }
        [DBus (name = "WakeAllowed")]
        public abstract bool wake_allowed { get; set; }
    }
}
