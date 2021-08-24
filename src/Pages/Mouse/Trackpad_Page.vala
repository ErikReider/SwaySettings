using Gee;

namespace SwaySettings {
    public class Trackpad_Widget : Input_Tab {

        public Trackpad_Widget (string tab_name, Input_Device touchpad, IPC ipc) {
            base (tab_name, Input_Types.touchpad, touchpad, ipc);
        }

        public override ArrayList<Gtk.Widget> get_options () {
            return new ArrayList<Gtk.Widget>.wrap ({
                get_scroll_factor (),
                get_natural_scroll (),
                get_tap (),
                get_click_method (),
                get_dwt (),
                get_doem (),
                get_accel_profile (),
                get_pointer_accel (),
            });
        }
    }
}
