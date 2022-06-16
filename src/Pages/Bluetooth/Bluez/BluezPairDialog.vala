namespace Bluez {
    [GtkTemplate (ui = "/org/erikreider/swaysettings/Pages/Bluetooth/Bluez/BluezPairDialog.ui")]
    public class PairDialog : Gtk.Dialog {
        [GtkChild]
        unowned Gtk.Box custom_box;

        [GtkChild]
        unowned Gtk.Image image;
        [GtkChild]
        unowned Gtk.Image badge;

        [GtkChild]
        unowned Gtk.Label title_label;
        [GtkChild]
        unowned Gtk.Label message_label;

        public enum AuthType {
            REQUEST_CONFIRMATION,
            REQUEST_AUTHORIZATION,
            DISPLAY_PASSKEY,
            DISPLAY_PIN_CODE
        }

        public ObjectPath object_path { get; construct; }
        public AuthType auth_type { get; construct; }
        public string passkey { get; construct; }
        public bool cancelled { get; set; }

        private PairDialog () {
            this.add_button ("Cancel", Gtk.ResponseType.CANCEL);
        }

        public PairDialog.request_authorization (ObjectPath object_path,
                                                 Gtk.Window main_window) {
            Object (
                auth_type: AuthType.REQUEST_AUTHORIZATION,
                object_path: object_path,
                transient_for: main_window
            );
            title_label.label = "Confirm Bluetooth Pairing";
            this.add_button ("Cancel", Gtk.ResponseType.CANCEL);
        }

        public PairDialog.display_passkey (ObjectPath object_path,
                                           uint32 passkey,
                                           uint16 entered,
                                           Gtk.Window main_window) {
            Object (
                auth_type: AuthType.DISPLAY_PASSKEY,
                object_path: object_path,
                passkey: "%u".printf (passkey),
                transient_for: main_window
            );
            title_label.label = "Confirm Bluetooth Passkey";
            this.add_button ("Cancel", Gtk.ResponseType.CANCEL);
        }

        public PairDialog.request_confirmation (ObjectPath object_path,
                                                uint32 passkey,
                                                Gtk.Window main_window) {
            Object (
                auth_type: AuthType.REQUEST_CONFIRMATION,
                object_path: object_path,
                passkey: "%u".printf (passkey),
                transient_for: main_window
            );
            title_label.label = "Confirm Bluetooth Passkey";
            this.add_button ("Cancel", Gtk.ResponseType.CANCEL);
        }

        public PairDialog.display_pin_code (ObjectPath object_path,
                                            string pincode,
                                            Gtk.Window main_window) {
            Object (
                auth_type: AuthType.DISPLAY_PIN_CODE,
                object_path: object_path,
                passkey: pincode,
                transient_for: main_window
            );
            title_label.label = "Enter Bluetooth PIN";
            this.add_button ("Cancel", Gtk.ResponseType.CANCEL);
        }

        construct {
            Device1 ? device;
            string device_name = "Unknown Bluetooth Device";
            try {
                device = Bus.get_proxy_sync<Device1 ? > (
                    BusType.SYSTEM,
                    "org.bluez",
                    object_path,
                    DBusProxyFlags.GET_INVALIDATED_PROPERTIES);
                image.set_from_icon_name (device.icon ?? "bluetooth",
                                          Gtk.IconSize.INVALID);
                device_name = device.name ?? device.address;
            } catch (IOError e) {
                image.set_from_icon_name ("bluetooth", Gtk.IconSize.INVALID);
                stderr.printf ("Pair dialog construct: %s\n", e.message);
            }

            switch (auth_type) {
                case AuthType.REQUEST_CONFIRMATION:
                    badge.set_from_icon_name ("dialog-password",
                                              Gtk.IconSize.INVALID);
                    message_label.label =
                        "Make sure the code displayed on “%s” matches the one below."
                         .printf (device_name);

                    var confirm = add_button ("Pair",
                                              Gtk.ResponseType.ACCEPT);
                    confirm.get_style_context ().add_class (
                        Gtk.STYLE_CLASS_SUGGESTED_ACTION);
                    break;
                case AuthType.DISPLAY_PASSKEY:
                    badge.set_from_icon_name ("dialog-password",
                                              Gtk.IconSize.INVALID);
                    message_label.label =
                        ("“%s” would like to pair with this device."
                         + " Make sure the code displayed on “%s” matches the one below.")
                         .printf (device_name, device_name);

                    var confirm = add_button ("Pair", Gtk.ResponseType.ACCEPT);
                    confirm.get_style_context ().add_class (
                        Gtk.STYLE_CLASS_SUGGESTED_ACTION);
                    break;
                case AuthType.DISPLAY_PIN_CODE:
                    badge.set_from_icon_name ("dialog-password",
                                              Gtk.IconSize.INVALID);
                    message_label.label =
                        "Type the code displayed below on “%s”, followed by Enter."
                         .printf (device_name);
                    break;
                case AuthType.REQUEST_AUTHORIZATION:
                    badge.set_from_icon_name ("dialog-question",
                                              Gtk.IconSize.INVALID);
                    message_label.label = "“%s” would like to pair with this device."
                                           .printf (device_name);

                    var confirm = add_button ("Pair", Gtk.ResponseType.ACCEPT);
                    confirm.get_style_context ().add_class (
                        Gtk.STYLE_CLASS_SUGGESTED_ACTION);
                    break;
            }

            // Display the passkey
            if (passkey != null && passkey.length > 0) {
                var passkey_label = new Gtk.Label (passkey);
                passkey_label.get_style_context ().add_class (
                    Gtk.STYLE_CLASS_HEADER);

                custom_box.add (passkey_label);
                custom_box.show_all ();
            }

            modal = true;
        }
    }
}
