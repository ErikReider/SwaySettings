using Gee;

namespace SwaySettings {
    public class Mouse_Widget : Input_Tab {

        public Mouse_Widget (string tab_name, Input_Device mouse, IPC ipc) {
            base (tab_name, Input_Types.pointer, mouse, ipc);
        }

        public override ArrayList<Gtk.Widget> get_options () {
            return new ArrayList<Gtk.Widget>.wrap ({
                get_scroll_factor (),
                get_natural_scroll (),
                get_accel_profile (),
                get_pointer_accel (),
            });
        }
    }
}
