using Linux;

namespace Rfkill {

    private class Device {
        public uint32 idx;
        public bool soft;
        public bool hard;
    }

    public class Rfkill : Object {
        private RfKillType rfkill_type;
        private int file_descriptor = -1;
        private IOSource source;
        private HashTable<uint32, Device> devices;

        public bool blocked { get; private set; default = false; }
        public signal void on_update (RfKillEvent event, bool blocked);

        public Rfkill (RfKillType rfkill_type) {
            this.rfkill_type = rfkill_type;
            this.devices = new HashTable<uint32, Device> (direct_hash,
                                                          direct_equal);

            file_descriptor = Posix.open ("/dev/rfkill",
                                          Posix.O_RDWR | Posix.O_NONBLOCK);
            if (file_descriptor < 0) {
                stderr.printf ("RFKILL: Cannot open RFKILL path as READONLY: %i\n",
                               file_descriptor);
                Posix.close (file_descriptor);
                file_descriptor = -1;
                return;
            }
            // Fill the devices HashTable
            while (on_event ());
            // Creates the listener
            IOChannel channel = new IOChannel.unix_new (file_descriptor);
            source = new IOSource (channel, IOCondition.IN);
            source.set_callback ((channel, cond) => {
                on_event ();
                return true;
            });
            source.attach (MainContext.default ());
        }

        protected override void dispose () {
            source.destroy ();
            if (file_descriptor >= 0) {
                Posix.close (file_descriptor);
                file_descriptor = -1;
            }
            base.dispose ();
        }

        /** Sets the blocking state for the Rfkill type */
        public bool try_set_blocking (bool block) {
            if (this.file_descriptor < 0 || this.blocked == block) return false;

            // Try to soft-block all the bluetooth devices
            RfKillEvent event = RfKillEvent () {
                op = RfKillOp.CHANGE_ALL,
                type = this.rfkill_type,
                soft = (uint8) block,
            };

            ssize_t bytes_written = Posix.write (file_descriptor,
                                                 &event,
                                                 sizeof (RfKillEvent));
            if (bytes_written < 0) {
                stderr.printf ("RFKILL: Could not write rfkill event! %s %i\n",
                               strerror (errno), file_descriptor);
                return false;
            }
            return true;
        }

        private bool on_event () {
            RfKillEvent event = RfKillEvent ();
            ulong len = sizeof (RfKillEvent);
            ssize_t bytes_read = Posix.read (file_descriptor, &event, len);
            if (bytes_read != len) return false;

            // Only check for provided RfkillType
            if (event.type != this.rfkill_type) return true;
            switch (event.op) {
                case RfKillOp.ADD:
                case RfKillOp.CHANGE:
                    Device device = new Device () {
                        idx = event.idx,
                        soft = event.soft != 0,
                        hard = event.hard != 0,
                    };
                    devices.insert (device.idx, device);
                    break;
                case RfKillOp.DEL:
                    devices.remove (event.idx);
                    break;
                default:
                    break;
            }
            bool blocked = false;
            foreach (var device in devices.get_values ()) {
                if (device.soft || device.hard) {
                    blocked = true;
                    break;
                }
            }
            this.blocked = blocked;

            on_update (event, this.blocked);
            return true;
        }
    }
}
