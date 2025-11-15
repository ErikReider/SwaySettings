namespace SwaySettings {
    private class PowerBatteryState {
        public static string ? get_battery_state (Up.DeviceState state) {
            switch (state) {
                case CHARGING:
                case PENDING_CHARGE:
                    return "Charging";
                case DISCHARGING:
                case PENDING_DISCHARGE:
                    return "Discharging";
                case FULLY_CHARGED:
                    return "Full";
                case EMPTY:
                    return "Empty";
                default:
                    return null;
            }
        }

        public static string get_device_icon_name (Up.DeviceKind kind, bool use_symbolic) {
            string ?symbolic = null;
            string ?regular = null;
            switch (kind) {
                case LINE_POWER:
                    symbolic = "ac-adapter-symbolic";
                    break;
                case BATTERY:
                    symbolic = "battery-symbolic";
                    break;
                case UPS:
                    symbolic = "uninterruptible-power-supply-symbolic";
                    break;
                case MONITOR:
                    symbolic = "video-display-symbolic";
                    regular = "video-display";
                    break;
                case MOUSE:
                    symbolic = "input-mouse-symbolic";
                    regular = "input-mouse";
                    break;
                case KEYBOARD:
                    symbolic = "input-keyboard-symbolic";
                    regular = "input-keyboard";
                    break;
                case PDA:
                    symbolic = "pda-symbolic";
                    break;
                case PHONE:
                    symbolic = "phone-symbolic";
                    regular = "phone";
                    break;
                case MEDIA_PLAYER:
                    symbolic = "multimedia-player-symbolic";
                    break;
                case TABLET:
                    symbolic = "computer-apple-ipad-symbolic";
                    break;
                case COMPUTER:
                    symbolic = "computer-symbolic";
                    regular = "computer";
                    break;
                case GAMING_INPUT:
                    symbolic = "input-gaming-symbolic";
                    regular = "input-gaming";
                    break;
                case PEN:
                    symbolic = "input-tablet-symbolic";
                    break;
                case TOUCHPAD:
                    symbolic = "input-touchpad-symbolic";
                    break;
                case MODEM:
                    symbolic = "modem-symbolic";
                    break;
                case NETWORK:
                    symbolic = "network-wired-symbolic";
                    regular = "network-wired";
                    break;
                case HEADSET:
                    symbolic = "audio-headset-symbolic";
                    regular = "audio-headset";
                    break;
                case HEADPHONES:
                    symbolic = "audio-headphones-symbolic";
                    regular = "audio-headphones";
                    break;
                case OTHER_AUDIO:
                case SPEAKERS:
                    symbolic = "audio-speakers-symbolic";
                    regular = "audio-speakers";
                    break;
                case VIDEO:
                    symbolic = "camera-web-symbolic";
                    regular = "camera-web";
                    break;
                case PRINTER:
                    symbolic = "printer-symbolic";
                    regular = "printer";
                    break;
                case SCANNER:
                    symbolic = "scanner-symbolic";
                    regular = "scanner";
                    break;
                case CAMERA:
                    symbolic = "camera-photo-symbolic";
                    regular = "camera-web";
                    break;
                case BLUETOOTH_GENERIC:
                    symbolic = "bluetooth-active-symbolic";
                    break;
                default:
                    break;
            }

            unowned Gdk.Display display = Gdk.Display.get_default ();
            unowned Gtk.IconTheme theme = Gtk.IconTheme.get_for_display (display);
            if (!use_symbolic && regular != null) {
                if (theme.has_icon (regular)) {
                    return regular;
                }
            }
            if (theme.has_icon (symbolic)) {
                return symbolic;
            }

            return "battery-symbolic";
        }
    }
}
