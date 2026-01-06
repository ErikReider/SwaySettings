using SwaySettings;

enum WarningState {
    REGULAR = 0,
    LOW = 1,
    CRITICAL = 2,
    ACTION = 3;

    public Notify.Urgency to_urgency () {
        switch (this) {
            default:
            case WarningState.REGULAR:
                return Notify.Urgency.NORMAL;
            case WarningState.LOW:
            case WarningState.CRITICAL:
            case WarningState.ACTION:
                return Notify.Urgency.CRITICAL;
        }
    }
}

enum ChargeState {
    DISCHARGING = 0,
    CHARGING = 1,
    FULLY_CHARGED = 2;
}

class Device : Object {
    Up.Device device;

    ChargeState charge_state = ChargeState.DISCHARGING;
    WarningState state = WarningState.REGULAR;
    Notify.Notification ?active_notification = null;

    public Device (Up.Device device) {
        this.device = device;
        device.notify.connect (device_notify);

        device_notify ();
    }

    private void device_notify () {
        switch ((Up.DeviceState) device.state) {
            case Up.DeviceState.FULLY_CHARGED :
                charge_state = ChargeState.FULLY_CHARGED;
                break;
            case Up.DeviceState.PENDING_CHARGE:
            case Up.DeviceState.CHARGING:
                charge_state = ChargeState.CHARGING;
                break;
            default:
                charge_state = ChargeState.DISCHARGING;
                break;
        }
        switch ((Up.DeviceLevel) device.warning_level) {
            default:
                if (state <= WarningState.REGULAR) {
                    break;
                }
                state = WarningState.REGULAR;
                send_notification ();
                break;
            case Up.DeviceLevel.LOW:
                if (state >= WarningState.LOW) {
                    break;
                }
                state = WarningState.LOW;
                send_notification ();
                break;
            case Up.DeviceLevel.CRITICAL:
                if (state >= WarningState.CRITICAL) {
                    break;
                }
                state = WarningState.CRITICAL;
                send_notification ();
                break;
            case Up.DeviceLevel.ACTION:
                if (state >= WarningState.ACTION) {
                    break;
                }
                state = WarningState.ACTION;
                send_notification ();
                break;
        }
    }

    private void close_notification () {
        if (active_notification != null) {
            try {
                active_notification.close ();
            } catch (Error e) {
                critical (e.message);
            }
            active_notification = null;
        }
    }

    private void send_notification () {
        string device_obj_path = device.get_object_path ();

        string summary = "Battery summary";
        string ?body = null;
        string icon = device.icon_name;
        if (charge_state == ChargeState.CHARGING) {
            // Send status update about disabling Low Power mode
            if (state != WarningState.REGULAR) {
                close_notification ();
                return;
            }
            if (app.ppd_is_holding () && app.display_device_obj_path == device_obj_path) {
                summary = "Battery no longer in Low Power state";
                body = "Disabling Low Power mode. %s".printf (
                    UPower.UPowerBatteryState.get_battery_status (device, false));
                // Release low power mode
                if (device.is_present) {
                    app.ppd_release_profile ();
                }
            } else {
                // Don't send notifications for non-battery devices
                return;
            }
        } else if (charge_state == ChargeState.FULLY_CHARGED) {
            if (app.display_device_obj_path == device_obj_path) {
                summary = "Battery Full";
                body = "The battery is fully charged";
            } else {
                summary = "\"%s\" Battery Full".printf (device.model);
                body = "The battery of \"%s\" is fully charged".printf (device.model);
            }
        } else if (charge_state == ChargeState.DISCHARGING) {
            switch (state) {
                case WarningState.REGULAR:
                    close_notification ();
                    return;
                case WarningState.LOW:
                    if (app.display_device_obj_path == device_obj_path) {
                        summary = "Low Battery";
                        body = "Time to recharge. %s".printf (
                            UPower.UPowerBatteryState.get_battery_status (device, false));
                        icon = "battery-level-20-symbolic";
                        // Hold low power mode
                        if (device.is_present && app.auto_power_saver) {
                            if (!app.ppd_is_power_saver ()) {
                                body = "%s. %s".printf (body, "Enabling Power Saver");
                            }
                            app.ppd_hold_profile ();
                        }
                        break;
                    }
                    summary = "\"%s\" Battery Low".printf (device.model);
                    body = "The battery of \"%s\" is at a low state".printf (device.model);
                    break;
                case WarningState.CRITICAL:
                    if (app.display_device_obj_path == device_obj_path) {
                        summary = "Critical Battery";
                        body = "Time to recharge. %s".printf (
                            UPower.UPowerBatteryState.get_battery_status (device, false));
                        icon = "battery-level-10-symbolic";
                        break;
                    }
                    summary = "\"%s\" Battery Critical".printf (device.model);
                    body = "The battery of \"%s\" is at a critical state".printf (device.model);
                    break;
                case WarningState.ACTION:
                    // No idea even sending this one. The user has bigger fish to fry...
                    close_notification ();
                    return;
            }
        }

        lock (active_notification) {
            if (active_notification == null) {
                active_notification = new Notify.Notification (summary, body, icon);
                active_notification.closed.connect (() => {
                    active_notification = null;
                });
            } else {
                active_notification.update (summary, body, icon);
            }
            active_notification.set_hint ("transient", new Variant.boolean (true));
            active_notification.set_urgency (state.to_urgency ());

            try {
                active_notification.show ();
            } catch (Error e) {
                critical (e.message);
            }
        }
    }
}
