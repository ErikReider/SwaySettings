static Settings self_settings;
static UPowerMonitor app;

class UPowerMonitor : Application {
    static Power.PowerProfileDaemon ?profile_daemon = null;
    static Up.Client ?up_client = null;

    public bool auto_power_saver { get; internal set; }

    HashTable<string, Device> devices = new HashTable<string, Device> (str_hash, str_equal);
    public Up.Device ?display_device { get; private set; }
    public string ?display_device_obj_path { get; private set; }

    private uint cookie = 0;

    public UPowerMonitor () {
        Object (
            application_id : "org.erikreider.swaysettings-upower-monitor",
            flags : ApplicationFlags.IS_SERVICE
        );
        Notify.init (application_id);
    }

    protected override void startup () {
        base.startup ();

        self_settings.bind (Constants.SETTINGS_POWER_AUTO_POWER_SAVER,
                            this, "auto-power-saver", SettingsBindFlags.GET);

        Bus.watch_name (
            BusType.SYSTEM,
            Power.POWER_PROFILES_DAEMON_NAME,
            BusNameWatcherFlags.NONE,
            profile_daemon_appear,
            profile_daemon_disappear);
        setup_upower.begin ();

        hold ();
    }

    ///
    /// UPower
    ///

    private async void setup_upower () {
        if (up_client == null) {
            try {
                up_client = yield new Up.Client.async ();
            } catch (Error e) {
                warning ("Could not connect to UPower: %s", e.message);
            }
        }

        // TODO: Auto set profile depending on if charging or not

        setup_display_device ();

        // Setup devices
        foreach (Up.Device device in up_client.get_devices2 ()) {
            devices.set (device.get_object_path (), new Device (device));
        }
        up_client.device_added.connect ((device) => {
            lock (devices) {
                devices.set (device.get_object_path (), new Device (device));
            }
            setup_display_device ();
        });
        up_client.device_removed.connect ((object_path) => {
            lock (devices) {
                devices.remove (object_path);
            }
            setup_display_device ();
        });
    }

    private void setup_display_device () {
        display_device = up_client.get_display_device ();
        display_device_obj_path = null;
        foreach (unowned Up.Device device in up_client.get_devices2 ()) {
            if (device.kind == Up.DeviceKind.BATTERY && device.power_supply) {
                display_device_obj_path = device.get_object_path ();
                break;
            }
        }
    }

    ///
    /// Power Profile Daemon
    ///

    private void profile_daemon_appear () {
        get_profile_daemon.begin ();
    }

    private void profile_daemon_disappear () {
        cookie = 0;
        profile_daemon = null;
    }

    private async void get_profile_daemon () {
        if (profile_daemon == null) {
            try {
                profile_daemon = yield Bus.get_proxy (BusType.SYSTEM,
                                                      Power.POWER_PROFILES_DAEMON_NAME,
                                                      Power.POWER_PROFILES_DAEMON_PATH);

                profile_daemon.profile_released.connect ((cookie) => {
                    if (cookie == this.cookie) {
                        this.cookie = 0;
                    }
                });
            } catch (Error e) {
                warning (e.message);
            }
        }
    }

    public bool ppd_is_holding () {
        return cookie != 0;
    }

    public void ppd_hold_profile () {
        if (profile_daemon == null) {
            cookie = 0;
            return;
        }

        // Don't change to power saver mode if disabled
        if (!auto_power_saver) {
            if (ppd_is_holding ()) {
                ppd_release_profile ();
            }
            return;
        }

        try {
            cookie = profile_daemon.hold_profile ("power-saver", "Battery power is low",
                                                  application_id);
        } catch (Error e) {
            cookie = 0;
            warning (e.message);
        }
    }

    public void ppd_release_profile () {
        if (profile_daemon == null) {
            return;
        }
        try {
            if (cookie != 0) {
                profile_daemon.release_profile (cookie);
                cookie = 0;
            }
        } catch (Error e) {
            warning (e.message);
        }
    }

    public bool ppd_is_power_saver () {
        if (profile_daemon == null) {
            return false;
        }
        return profile_daemon.active_profile == "power-saver";
    }

    public static int main (string[] args) {
        self_settings = new Settings ("org.erikreider.swaysettings");

        app = new UPowerMonitor ();
        return app.run ();
    }
}
