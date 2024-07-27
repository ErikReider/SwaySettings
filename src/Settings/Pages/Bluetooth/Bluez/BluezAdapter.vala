namespace Bluez {
    [DBus (name = "org.bluez.Adapter1")]
    public interface Adapter1 : Object {
        [DBus (name = "StartDiscovery")]
        public abstract async void start_discovery () throws DBusError, IOError;
        [DBus (name = "SetDiscoveryFilter")]
        public abstract void set_discovery_filter (HashTable<string, Variant> properties) throws DBusError, IOError;
        [DBus (name = "StopDiscovery")]
        public abstract async void stop_discovery () throws DBusError, IOError;
        [DBus (name = "RemoveDevice")]
        public abstract void remove_device (ObjectPath device) throws DBusError, IOError;
        [DBus (name = "GetDiscoveryFilters")]
        public abstract string[] get_discovery_filters () throws DBusError, IOError;

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
        [DBus (name = "Powered")]
        public abstract bool powered { get; set; }
        [DBus (name = "Discoverable")]
        public abstract bool discoverable { get; set; }
        [DBus (name = "DiscoverableTimeout")]
        public abstract uint discoverable_timeout { get; set; }
        [DBus (name = "Pairable")]
        public abstract bool pairable { get; set; }
        [DBus (name = "PairableTimeout")]
        public abstract uint pairable_timeout { get; set; }
        [DBus (name = "Discovering")]
        public abstract bool discovering { get; }
        [DBus (name = "UUIDs")]
        public abstract string[] uuids { owned get; }
        [DBus (name = "Modalias")]
        public abstract string modalias { owned get; }
        [DBus (name = "Roles")]
        public abstract string[] roles { owned get; }
        [DBus (name = "ExperimentalFeatures")]
        public abstract string[] experimental_features { owned get; }
    }
}
