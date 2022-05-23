namespace Bluez {
    [DBus (name = "org.bluez.AgentManager1", timeout = 120000)]
    public interface AgentManager1 : Object {
        /**
         * This registers an agent handler.
         *
         * The object path defines the path of the agent
         * that will be called when user input is needed.
         *
         * Every application can register its own agent and
         * for all actions triggered by that application its
         * agent is used.
         *
         * It is not required by an application to register
         * an agent. If an application does chooses to not
         * register an agent, the default agent is used. This
         * is on most cases a good idea. Only application
         * like a pairing wizard should register their own
         * agent.
         *
         * An application can only register one agent. Multiple
         * agents per application is not supported.
         *
         * The capability parameter can have the values
         * "DisplayOnly", "DisplayYesNo", "KeyboardOnly",
         * "NoInputNoOutput" and "KeyboardDisplay" which
         * reflects the input and output capabilities of the
         * agent.
         *
         * If an empty string is used it will fallback to
         * "DisplayYesNo".
         *
         * Possible errors:
         * - org.bluez.Error.InvalidArguments
         * - org.bluez.Error.AlreadyExists
         */
        [DBus (name = "RegisterAgent")]
        public abstract void register_agent (ObjectPath agent, string capability) throws Error;

        /**
         * This unregisters the agent that has been previously
         * registered. The object path parameter must match the
         * same value that has been used on registration.
         *
         * Possible errors:
         * - org.bluez.Error.DoesNotExist
         */
        [DBus (name = "UnregisterAgent")]
        public abstract void unregister_agent (ObjectPath agent) throws Error;

        /**
         * This requests is to make the application agent
         * the default agent. The application is required
         * to register an agent.
         *
         * Special permission might be required to become
         * the default agent.
         *
         * Possible errors:
         * - org.bluez.Error.DoesNotExist
         */
        [DBus (name = "RequestDefaultAgent")]
        public abstract void request_default_agent (ObjectPath agent) throws Error;
    }

    [DBus (name = "org.bluez.Error")]
    public errordomain BluezError {
        REJECTED, CANCELED
    }

    // https://github.com/pauloborges/bluez/blob/master/doc/agent-api.txt
    [DBus (name = "org.bluez.Agent1", timeout = 120000)]
    public class Agent1 : Object {
        private const string PATH = "/org/bluez/agent/swaysettings";
        public static ObjectPath path { get; default = new ObjectPath (PATH); }

        Gtk.Window main_window;

        private PairDialog ? pair_dialog;

        private uint register_id = 0;
        private DBusConnection ? connection;

        [DBus (visible = false)]
        public Agent1 (Gtk.Window main_window) {
            this.main_window = main_window;
            try {
                this.connection = Bus.get_sync (BusType.SYSTEM);
                this.register_id = this.connection.register_object<Agent1> (PATH,
                                                                            this);
            } catch (Error e) {
                stderr.printf ("Agent creation error: %s\n", e.message);
            }
        }

        /**
         * This method gets called when the service daemon
         * unregisters the agent. An agent can use it to do
         * cleanup tasks. There is no need to unregister the
         * agent, because when this method gets called it has
         * already been unregistered.
         */
        [DBus (name = "Release")]
        public void release () throws Error {
            debug ("Agent: Release\n");
            if (register_id != 0) {
                if (connection == null || connection.is_closed ()) {
                    this.connection = Bus.get_sync (BusType.SYSTEM);
                }
                connection.unregister_object (register_id);
                register_id = 0;
            }
        }

        /**
         * This method gets called when the service daemon
         * needs to get the passkey for an authentication.
         *
         * The return value should be a string of 1-16 characters
         * length. The string can be alphanumeric.
         *
         * Possible errors:
         * - BluezError.REJECTED
         * - BluezError.CANCELED
         * */
        [DBus (name = "RequestPinCode")]
        public async string request_pin_code (ObjectPath device) throws Error, BluezError {
            debug ("Agent: Request pin code\n");
            throw new BluezError.REJECTED ("Pairing method not supported");
        }

        /**
         * This method gets called when the service daemon
         * needs to display a pincode for an authentication.
         *
         * An empty reply should be returned. When the pincode
         * needs no longer to be displayed, the Cancel method
         * of the agent will be called.
         *
         * This is used during the pairing process of keyboards
         * that don't support Bluetooth 2.1 Secure Simple Pairing,
         * in contrast to DisplayPasskey which is used for those
         * that do.
         *
         * This method will only ever be called once since
         * older keyboards do not support typing notification.
         *
         * Note that the PIN will always be a 6-digit number,
         * zero-padded to 6 digits. This is for harmony with
         * the later specification.
         *
         * Possible errors:
         * - BluezError.REJECTED
         * - BluezError.CANCELED
         */
        [DBus (name = "DisplayPinCode")]
        public async void display_pin_code (ObjectPath device,
                                            string pincode) throws Error, BluezError {
            debug ("Agent: Display pin code\n");
            pair_dialog = new PairDialog.display_pin_code (device, pincode, main_window);
            pair_dialog.present ();
        }

        /**
         * This method gets called when the service daemon
         * needs to get the passkey for an authentication.
         *
         * The return value should be a numeric value
         * between 0-999999.
         *
         * Possible errors:
         * - BluezError.REJECTED
         * - BluezError.CANCELED
         */
        [DBus (name = "RequestPasskey")]
        public async uint32 request_passkey (ObjectPath device) throws Error, BluezError {
            debug ("Agent: Request passkey\n");
            throw new BluezError.REJECTED ("Pairing method not supported");
        }

        /**
         * This method gets called when the service daemon
         * needs to display a passkey for an authentication.
         *
         * The entered parameter indicates the number of already
         * typed keys on the remote side.
         *
         * An empty reply should be returned. When the passkey
         * needs no longer to be displayed, the Cancel method
         * of the agent will be called.
         *
         * During the pairing process this method might be
         * called multiple times to update the entered value.
         *
         * Note that the passkey will always be a 6-digit number,
         * so the display should be zero-padded at the start if
         * the value contains less than 6 digits.
         */
        [DBus (name = "DisplayPasskey")]
        public async void display_passkey (ObjectPath device,
                                           uint32 passkey,
                                           uint16 entered) throws Error {
            debug ("Agent: Display passkey\n");
            pair_dialog = new PairDialog.display_passkey (device, passkey, entered, main_window);
            pair_dialog.present ();
        }

        /**
         * This method gets called when the service daemon
         * needs to confirm a passkey for an authentication.
         *
         * To confirm the value it should return an empty reply
         * or an error in case the passkey is invalid.
         *
         * Note that the passkey will always be a 6-digit number,
         * so the display should be zero-padded at the start if
         * the value contains less than 6 digits.
         *
         * Possible errors:
         * - BluezError.REJECTED
         * - BluezError.CANCELED
         */
        [DBus (name = "RequestConfirmation")]
        public async void request_confirmation (ObjectPath device,
                                                uint32 passkey) throws Error, BluezError {
            debug ("Agent: Request confirmation\n");
            pair_dialog = new PairDialog.request_confirmation (device, passkey, main_window);
            yield check_pairing_response (pair_dialog);
        }

        /**
         * This method gets called to request the user to
         * authorize an incoming pairing attempt which
         * would in other circumstances trigger the just-works
         * model.
         *
         * To confirm the value it should return an empty reply
         * or an error in case the passkey is invalid.
         *
         * Possible errors:
         * - BluezError.REJECTED
         * - BluezError.CANCELED
         */
        [DBus (name = "RequestAuthorization")]
        public async void request_authorization (ObjectPath device) throws Error, BluezError {
            debug ("Agent: Request authorization\n");
            pair_dialog = new PairDialog.request_authorization (device, main_window);
            yield check_pairing_response (pair_dialog);
        }

        /**
         * This method gets called when the service daemon
         * needs to authorize a connection/service request.
         *
         * Called to authorize the use of a specific service (Audio/HID/etc),
         * so we restrict this to paired devices only.
         *
         * Possible errors:
         * - BluezError.REJECTED
         * - BluezError.CANCELED
         */
        [DBus (name = "AuthorizeService")]
        public void authorize_service (ObjectPath device_path,
                                       string uuid) throws Error, BluezError {
            debug ("Agent: Authorize service\n");
            Device1 device = Bus.get_proxy_sync<Device1> (
                BusType.SYSTEM,
                "org.bluez",
                device_path,
                DBusProxyFlags.GET_INVALIDATED_PROPERTIES);

            // Authorize if paired. Make device trusted if not already trusted
            if (device.paired) {
                if (!device.trusted) device.trusted = true;
                return;
            }

            // Reject everything else
            throw new BluezError.REJECTED (
                      "Rejecting service auth, not paired or trusted");
        }

        /**
         * This method gets called to indicate that the agent
         * request failed before a reply was returned.
         */
        [DBus (name = "Cancel")]
        public void cancel () throws Error {
            debug ("Agent: Cancel\n");
            if (pair_dialog != null) {
                pair_dialog.cancelled = true;
                pair_dialog.destroy ();
            }
        }

        private async void check_pairing_response (PairDialog dialog) throws BluezError {
            debug ("Agent: Check pairing response\n");
            SourceFunc callback = check_pairing_response.callback;
            BluezError ? error = null;

            dialog.response.connect ((response) => {
                if (response != Gtk.ResponseType.ACCEPT || dialog.cancelled) {
                    if (dialog.cancelled) {
                        error = new BluezError.CANCELED ("Pairing cancelled");
                    } else {
                        error = new BluezError.REJECTED ("Pairing rejected");
                    }
                }

                Idle.add ((owned) callback);
                dialog.destroy ();
            });

            dialog.present ();

            // Wait until the user has accepted or rejected pairing
            yield;

            if (error != null) throw error;
        }
    }
}
