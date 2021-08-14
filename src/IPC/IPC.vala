/* window.vala
 *
 * Copyright 2021 Erik Reider
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gee;

namespace SwaySettings {

    public enum Sway_commands {
        GET_WORKSPACES = 1,
        SUBSCRIBE = 2,
        GET_OUTPUTS = 3,
        GET_TREE = 4,
        GET_MARKS = 5,
        GET_BAR_CONFIG = 6,
        GET_VERSION = 7,
        GET_BINDING_MODES = 8,
        GET_CONFIG = 9,
        SEND_TICK = 10,
        SYNC = 11,
        GET_BINDING_STATE = 12,
        GET_IMPUTS = 100,
        GET_SEATS = 101,
    }

    public class IPC {
        private uint8[] magic_number = "i3-ipc".data;
        private int bytes_to_payload = 14;

        // Max reply size
        private int buffer_size = 1024 * 64;

        private Socket socket = null;

        public IPC () {
            try {
                socket = new Socket (GLib.SocketFamily.UNIX,
                                     GLib.SocketType.STREAM,
                                     GLib.SocketProtocol.DEFAULT);
                socket.connect (new GLib.UnixSocketAddress (get_sock_path ()));
                socket.set_blocking (true);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        ~IPC () {
            if (socket != null && !socket.is_closed ()) {
                try {
                    socket.close ();
                } catch (Error e) {
                    stderr.printf (e.message + "\n");
                    Process.exit (1);
                }
            }
        }

        private string get_sock_path () {
            string[] paths = {
                GLib.Environment.get_variable ("SWAYSOCK"),
                GLib.Environment.get_variable ("I3SOCK"),
            };
            string path = null;
            foreach (string p in paths) {
                if (p != null) {
                    path = p;
                    break;
                }
            }
            if (path == null) {
                stderr.printf ("COULD NOT FIND SWAY SOCKET ENVIRONMENT VARIABLE!!!");
                Process.exit (1);
            }
            return path;
        }

        private uint8[] int32_to_uint8_array (int32 input) {
            Variant val = new Variant.int32 (input);
            return val.get_data_as_bytes ().get_data ();
        }

        public Json.Node get_reply (Sway_commands cmd) {
            try {
                ByteArray np = new ByteArray ();
                np.append (magic_number);
                np.append (int32_to_uint8_array (0));
                np.append (int32_to_uint8_array (cmd));

                Bytes message = ByteArray.free_to_bytes (np);
                socket.send (message.get_data ());


                uint8[] buffer = new uint8[buffer_size];
                socket.receive (buffer);

                Bytes responseBytes = new Bytes.take (buffer);
                string response = (string) responseBytes.slice (
                    bytes_to_payload, responseBytes.length).get_data ();

                Json.Parser parser = new Json.Parser ();
                parser.load_from_data (response);
                return parser.get_root ();
            } catch (Error e) {
                stderr.printf (e.message + "\n");
                Process.exit (1);
            }
        }

        public bool run_command (string cmd) {
            try {
                ByteArray np = new ByteArray ();

                np.append (magic_number);
                np.append (int32_to_uint8_array (cmd.length));
                np.append (int32_to_uint8_array (0));
                np.append (cmd.data);

                Bytes message = ByteArray.free_to_bytes (np);

                socket.send (message.get_data ());
            } catch (Error e) {
                stderr.printf (e.message + "\n");
                return false;
            }
            return true;
        }
    }
}
