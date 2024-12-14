namespace Bluez {
    public class PairDialog : Gtk.Dialog {
        Adw.Bin code_widget;

        Gtk.Image image;

        Gtk.Label title_label;
        Gtk.Label message_label;

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
            // Build dialog
            {
                set_resizable (false);
                default_width = 250;

                unowned Gtk.Box box = get_content_area ();
                box.margin_top = 8;
                box.margin_start = 8;
                box.margin_end = 8;
                box.set_orientation (Gtk.Orientation.VERTICAL);
                box.set_spacing (12);

                image = new Gtk.Image.from_icon_name ("video-display") {
                    pixel_size = 96,
                    halign = Gtk.Align.CENTER,
                    margin_top = 8,
                    margin_bottom = 8,
                    margin_start = 8,
                    margin_end = 8,
                };
                box.append (image);

                title_label = new Gtk.Label (null) {
                    wrap = true,
                    hexpand = true,
                    justify = Gtk.Justification.CENTER,
                };
                title_label.add_css_class ("title-2");
                box.append (title_label);
                message_label = new Gtk.Label (null) {
                    wrap = true,
                    hexpand = true,
                    justify = Gtk.Justification.CENTER,
                };
                message_label.add_css_class ("body");
                box.append (message_label);

                code_widget = new Adw.Bin ();
                box.append (code_widget);
            }

            // Logic
            Device1 ? device;
            string device_name = "Unknown Bluetooth Device";
            try {
                device = Bus.get_proxy_sync<Device1 ? > (
                    BusType.SYSTEM,
                    "org.bluez",
                    object_path,
                    DBusProxyFlags.GET_INVALIDATED_PROPERTIES);
                image.set_from_icon_name (device.icon ?? "bluetooth");
                device_name = device.name ?? device.address;
            } catch (IOError e) {
                image.set_from_icon_name ("bluetooth");
                stderr.printf ("Pair dialog construct: %s\n", e.message);
            }

            switch (auth_type) {
                case AuthType.REQUEST_CONFIRMATION:
                    message_label.label =
                        "Make sure the code displayed on “%s” matches the one below."
                         .printf (device_name);

                    var confirm = add_button ("Pair", Gtk.ResponseType.ACCEPT);
                    confirm.add_css_class ("suggested-action");
                    break;
                case AuthType.DISPLAY_PASSKEY:
                    message_label.label =
                        ("“%s” would like to pair with this device."
                         + " Make sure the code displayed on “%s” matches the one below.")
                         .printf (device_name, device_name);

                    var confirm = add_button ("Pair", Gtk.ResponseType.ACCEPT);
                    confirm.add_css_class ("suggested-action");
                    break;
                case AuthType.DISPLAY_PIN_CODE:
                    message_label.label =
                        "Type the code displayed below on “%s”, followed by Enter."
                         .printf (device_name);
                    break;
                case AuthType.REQUEST_AUTHORIZATION:
                    message_label.label = "“%s” would like to pair with this device."
                                           .printf (device_name);

                    var confirm = add_button ("Pair", Gtk.ResponseType.ACCEPT);
                    confirm.add_css_class ("suggested-action");
                    break;
            }

            // Display the passkey
            if (passkey != null && passkey.length > 0) {
                var passkey_label = new Gtk.Label (passkey) {
                    margin_top = 8,
                    margin_bottom = 8,
                    margin_start = 8,
                    margin_end = 8,
                };
                passkey_label.add_css_class ("title-1");

                code_widget.set_child (passkey_label);
            }
        }
    }
}
