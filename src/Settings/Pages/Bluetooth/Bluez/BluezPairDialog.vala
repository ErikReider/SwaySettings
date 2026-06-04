namespace Bluez {
    [GtkTemplate (ui = "/org/erikreider/swaysettings/ui/BluezPairDialog.ui")]
    public class PairDialog : Adw.AlertDialog {
        public string icon_name { get; construct; }
        public string header_text { get; construct; }
        public string body_text { get; construct; }

        public enum AuthType {
            REQUEST_CONFIRMATION,
            REQUEST_AUTHORIZATION,
            DISPLAY_PASSKEY,
            DISPLAY_PIN_CODE
        }

        public ObjectPath object_path { get; construct; }
        public AuthType auth_type { get; construct; }
        public string ?passkey { get; construct; }
        public bool cancelled { get; set; }

        private PairDialog () {}

        public PairDialog.request_authorization (ObjectPath object_path) {
            Object (
                auth_type: AuthType.REQUEST_AUTHORIZATION,
                object_path: object_path,
                header_text: "Confirm Bluetooth Pairing"
            );
        }

        public PairDialog.display_passkey (ObjectPath object_path,
                                           uint32 passkey,
                                           uint16 entered) {
            Object (
                auth_type: AuthType.DISPLAY_PASSKEY,
                object_path: object_path,
                passkey: "%u".printf (passkey),
                header_text: "Confirm Bluetooth Passkey"
            );
        }

        public PairDialog.request_confirmation (ObjectPath object_path, uint32 passkey) {
            Object (
                auth_type: AuthType.REQUEST_CONFIRMATION,
                object_path: object_path,
                passkey: "%u".printf (passkey),
                header_text: "Confirm Bluetooth Passkey"
            );
        }

        public PairDialog.display_pin_code (ObjectPath object_path, string pincode) {
            Object (
                auth_type: AuthType.DISPLAY_PIN_CODE,
                object_path: object_path,
                passkey: pincode,
                header_text: "Enter Bluetooth PIN"
            );
        }

        construct {
            icon_name = "bluetooth";

            // Get device info
            string device_name = "Unknown Bluetooth Device";
            try {
                Device1 ?device = Bus.get_proxy_sync<Device1 ?> (
                    BusType.SYSTEM,
                    "org.bluez",
                    object_path,
                    DBusProxyFlags.GET_INVALIDATED_PROPERTIES);
                if (device.icon != null) {
                    icon_name = device.icon;
                }
                device_name = device.name ?? device.address;
            } catch (IOError e) {
                critical ("Bluez pair dialog error: %s\n", e.message);
            }

            add_response ("pair", "Pair");
            set_response_appearance ("pair", Adw.ResponseAppearance.SUGGESTED);
            add_response ("cancel", "Cancel");
            set_default_response ("cancel");
            set_close_response ("cancel");

            switch (auth_type) {
                case AuthType.REQUEST_CONFIRMATION:
                    body_text =
                        "Make sure the code displayed on “%s” matches the one below."
                         .printf (device_name);
                    break;
                case AuthType.DISPLAY_PASSKEY:
                    body_text =
                        ("“%s” would like to pair with this device."
                         + " Make sure the code displayed on “%s” matches the one below.")
                         .printf (device_name, device_name);
                    break;
                case AuthType.DISPLAY_PIN_CODE:
                    body_text =
                        "Type the code displayed below on “%s”, followed by Enter."
                         .printf (device_name);

                    remove_response ("pair");
                    break;
                case AuthType.REQUEST_AUTHORIZATION:
                    body_text = "“%s” would like to pair with this device."
                         .printf (device_name);
                    break;
            }
        }

        [GtkCallback]
        private bool get_has_passkey (string ?passkey) {
            return passkey != null && passkey.length > 0;
        }
    }
}
