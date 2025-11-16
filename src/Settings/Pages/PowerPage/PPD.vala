namespace Power {
    public const string POWER_PROFILES_DAEMON_NAME = "net.hadess.PowerProfiles";
    public const string POWER_PROFILES_DAEMON_PATH = "/net/hadess/PowerProfiles";

    enum PowerProfiles {
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

    [DBus (name = "net.hadess.PowerProfiles")]
    /** https://upower.pages.freedesktop.org/power-profiles-daemon/gdbus-org.freedesktop.UPower.PowerProfiles.html */
    public interface PowerProfileDaemon : DBusProxy {
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
}
