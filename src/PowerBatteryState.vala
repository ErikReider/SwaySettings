namespace Power {
    private class PowerBatteryState {
        public static string ?get_battery_state (Up.DeviceState state) {
            switch (state) {
                case PENDING_CHARGE:
                    return "Charge limit reached, not charging";
                case CHARGING:
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

        public static string get_battery_percent (Up.Device device, bool show_extra) {
            if (device.battery_level != Up.DeviceLevel.NONE) {
                return Up.Device.level_to_string (device.battery_level);
            }

            string percent = "%.0f%%".printf (device.percentage);
            if (show_extra) {
                switch (device.state) {
                    case Up.DeviceState.FULLY_CHARGED:
                    case Up.DeviceState.PENDING_CHARGE:
                        return "%s Full".printf (percent);
                    case Up.DeviceState.EMPTY:
                        return "%s Empty".printf (percent);
                    default:
                        break;
                }
            }
            return percent;
        }

        public static string ?get_battery_status (Up.Device device,
                                                  bool include_rate = true) {
            string[] status_items = {};

            string ?status = null;
            string ?time = null;
            string ?energy_rate = null;
            switch (device.state) {
                case Up.DeviceState.PENDING_CHARGE:
                    status = get_battery_state (device.state);
                    break;
                case Up.DeviceState.CHARGING:
                    status = get_battery_state (device.state);
                    string parsed_time;
                    if (parse_time (device.time_to_full, out parsed_time)) {
                        time = "%s until fully charged".printf (parsed_time);
                    }
                    break;
                case Up.DeviceState.DISCHARGING:
                case Up.DeviceState.PENDING_DISCHARGE:
                    status = get_battery_state (device.state);
                    if (device.energy_rate > 0 && include_rate) {
                        energy_rate = "%.0lf W".printf (device.energy_rate);
                    }
                    string parsed_time;
                    if (parse_time (device.time_to_empty, out parsed_time)) {
                        time = "%s remaining".printf (parsed_time);
                    }
                    break;
                case Up.DeviceState.FULLY_CHARGED:
                    status = get_battery_state (device.state);
                    break;
                case Up.DeviceState.EMPTY:
                    status = get_battery_state (device.state);
                    if (device.energy_rate > 0 && include_rate) {
                        energy_rate = "%.0lf W".printf (device.energy_rate);
                    }
                    string parsed_time;
                    if (parse_time (device.time_to_empty, out parsed_time)) {
                        time = "%s remaining".printf (parsed_time);
                    }
                    break;
                default:
                    break;
            }

            if (status != null) {
                status_items += status;
            }
            if (energy_rate != null) {
                status_items += energy_rate;
            }
            if (time != null) {
                status_items += time;
            }
            if (status_items.length == 0) {
                return null;
            }
            return string.joinv (" - ", status_items);
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

        private static bool parse_time (int64 sec, out string time) {
            int minutes = (int) ((sec / 60.0) + 0.5);
            if (minutes <= 0) {
                time = "Unknown time";
                return false;
            }

            if (minutes < 60) {
                time = ngettext ("%i minute", "%i minutes", minutes).printf (minutes);
                return true;
            }

            int hours = minutes / 60;
            minutes %= 60;

            if (minutes == 0) {
                time = ngettext ("%i hour", "%i hour", hours).printf (hours);
                return true;
            }

            time = "%s %s".printf (
                ngettext ("%i hour", "%i hour", hours).printf (hours),
                ngettext ("%i minute", "%i minutes", minutes).printf (minutes));
            return true;
        }
    }
}
