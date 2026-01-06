namespace SwaySettings.UPower {
    [DBus (name = "org.freedesktop.UPower.PowerProfiles")]
    /** https://upower.pages.freedesktop.org/power-profiles-daemon/gdbus-org.freedesktop.UPower.PowerProfiles.html */
    public interface PowerProfileDaemon : DBusProxy {
        [DBus (name = "HoldProfile")]
        public abstract uint hold_profile (string profile,
                                           string reason,
                                           string app_id) throws Error;

        [DBus (name = "ReleaseProfile")]
        public abstract void release_profile (uint cookie) throws Error;

        [DBus (name = "SetActionEnabled")]
        public abstract void set_action_enabled (string action, bool enabled) throws Error;

        [DBus (name = "ProfileReleased")]
        public signal void profile_released (uint cookie);

        [DBus (name = "ActiveProfile")]
        public abstract string active_profile { owned get; set; }

        [DBus (name = "PerformanceInhibited")]
        public abstract string performance_inhibited { owned get; }

        [DBus (name = "PerformanceDegraded")]
        public abstract string performance_degraded { owned get; }

        [DBus (name = "Profiles")]
        public abstract HashTable<string, Variant>[] profiles { owned get; }

        [DBus (name = "Actions")]
        public abstract string[] actions { owned get; }

        [DBus (name = "ActionsInfo")]
        public abstract HashTable<string, Variant>[] actions_info { owned get; }

        [DBus (name = "ActiveProfileHolds")]
        public abstract HashTable<string, Variant>[] active_profile_holds { owned get; }

        [DBus (name = "Version")]
        public abstract string version { owned get; }

        [DBus (name = "BatteryAware")]
        public abstract bool battery_aware { owned get; set; }
    }

    public class PowerProfileDaemonHelper : Object {
        private const string POWER_PROFILES_DAEMON_NAME = "org.freedesktop.UPower.PowerProfiles";
        private const string POWER_PROFILES_DAEMON_PATH = "/org/freedesktop/UPower/PowerProfiles";

        private static PowerProfileDaemon ?instance = null;

        public signal void appear (PowerProfileDaemon ppd);
        public signal void disappear ();
        public signal void profile_released (uint cookie);
        public signal void properties_changed (Variant changed_properties,
                                               string[] invalidated_properties);

        public async unowned PowerProfileDaemon ?get_async () {
            if (PowerProfileDaemonHelper.instance != null) {
                return PowerProfileDaemonHelper.instance;
            }
            Bus.watch_name (
                BusType.SYSTEM,
                POWER_PROFILES_DAEMON_NAME,
                BusNameWatcherFlags.NONE,
                () => {
                    // Appear
                    profile_daemon_appear.begin ((obj, res) => {
                        get_async.callback ();
                    });
                },
                () => {
                    // Disappear
                    PowerProfileDaemonHelper.instance = null;
                    disappear ();
                });
            yield;

            return instance;
        }

        private async bool profile_daemon_appear () {
            if (PowerProfileDaemonHelper.instance != null) {
                appear (PowerProfileDaemonHelper.instance);
                return true;
            }

            try {
                PowerProfileDaemonHelper.instance
                    = yield Bus.get_proxy (BusType.SYSTEM,
                                           POWER_PROFILES_DAEMON_NAME,
                                           POWER_PROFILES_DAEMON_PATH);

                PowerProfileDaemonHelper.instance.profile_released.connect (
                    (cookie) => profile_released (cookie));
                PowerProfileDaemonHelper.instance.g_properties_changed.connect (
                    (changed, invalidated) => properties_changed (changed, invalidated));

                return true;
            } catch (Error e) {
                warning (e.message);
            }
            return false;
        }
    }

    public enum PowerProfiles {
        PERFORMANCE,
        BALANCED,
        POWERSAVER,
        NUM_PROFILES,
        UNKNOWN;

        public static PowerProfiles parse (string profile_name) {
            switch (profile_name) {
                case "power-saver":
                    return POWERSAVER;
                case "balanced":
                    return BALANCED;
                case "performance":
                    return PERFORMANCE;
                default:
                    return UNKNOWN;
            }
        }

        public string ?to_string () {
            switch (this) {
                case POWERSAVER:
                    return "power-saver";
                case BALANCED:
                    return "balanced";
                case PERFORMANCE:
                    return "performance";
                default:
                    return null;
            }
        }

        public string get_title () {
            switch (this) {
                case POWERSAVER:
                    return "Power Saver";
                case BALANCED:
                    return "Balanced";
                case PERFORMANCE:
                    return "Performance";
                default:
                    return "Unknown";
            }
        }

        public string get_subtitle () {
            switch (this) {
                case POWERSAVER:
                    return "Reduced performance and power usage";
                case BALANCED:
                    return "Standard performance and power usage";
                case PERFORMANCE:
                    return "High performance and power usage";
                default:
                    return "Unknown";
            }
        }
    }
}
