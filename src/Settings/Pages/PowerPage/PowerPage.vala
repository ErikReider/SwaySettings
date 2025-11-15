namespace SwaySettings {
    private errordomain PowerPageErrors {
        UP_DEVICES_NULL,
    }

    public class PowerPage : PageScroll {
        public PowerPage (SettingsItem item,
                          Adw.NavigationPage page) {
            base (item, page);

            typeof (PowerModeRow).ensure ();
            typeof (PowerInfoBanner).ensure ();
            typeof (PowerDeviceList).ensure ();
        }

        public override Gtk.Widget set_child () {
            return new PowerPageContent ();
        }
    }

    [GtkTemplate (ui = "/org/erikreider/swaysettings/ui/PowerPageContent.ui")]
    private class PowerPageContent : Adw.Bin {
        const string STACK_PAGE = "page";
        const string STACK_PLACEHOLDER_PAGE = "placeholder";

        static Power.PowerProfileDaemon ?profile_daemon = null;
        static Up.Client ?up_client = null;

        [GtkChild]
        unowned Gtk.Stack stack;

        [GtkChild]
        unowned Gtk.Box main_box;

        [GtkChild]
        unowned Adw.PreferencesGroup battery_group;
        [GtkChild]
        unowned Adw.PreferencesGroup battery_options_group;

        [GtkChild]
        unowned Adw.PreferencesGroup devices_group;
        [GtkChild]
        unowned PowerDeviceList devices_list;

        [GtkChild]
        unowned Adw.PreferencesGroup power_mode_group;

        [GtkChild]
        unowned Gtk.ListBox modes_listbox;
        [GtkChild]
        unowned Gtk.ListBox power_info_listbox;
        [GtkChild]
        unowned PowerInfoBanner degraded_banner;
        [GtkChild]
        unowned PowerInfoBanner power_mode_banner;

        construct {
            modes_listbox.set_sort_func ((a, b) => {
                unowned PowerModeRow row_a = (PowerModeRow) a;
                unowned PowerModeRow row_b = (PowerModeRow) b;
                return row_a.profile > row_b.profile ? 1 : -1;
            });
            stack.set_visible_child_name (STACK_PAGE);

            Bus.watch_name (
                BusType.SYSTEM,
                Power.POWER_PROFILES_DAEMON_NAME,
                BusNameWatcherFlags.NONE,
                profile_daemon_appear,
                profile_daemon_disappear);

            setup_upower.begin ();

        }

        private void setup_ui_post () {
            for (unowned Gtk.Widget i = main_box.get_first_child ();
                 i != null;
                 i = i.get_next_sibling ()) {
                if (i.visible) {
                    stack.set_visible_child_name (STACK_PAGE);
                    return;
                }
            }
            stack.set_visible_child_name (STACK_PLACEHOLDER_PAGE);
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

            setup_upower_ui ();
            yield setup_upower_devices ();
        }

        private void setup_upower_ui () {
            // TODO: Low power threshold
            // TODO: Auto enable low power mode at percentage
            // TODO: Battery graph
            // TODO: Battery Health
            // TODO: Battery profile selector for plugged in and on battery
            battery_group.set_visible (up_client != null && up_client.on_battery);
            battery_options_group.set_visible (up_client != null && up_client.on_battery);

            if (up_client == null) {
                setup_ui_post ();
                return;
            }
            setup_ui_post ();
        }

        private async void setup_upower_devices () {
            if (up_client == null) {
                devices_group.set_visible (false);
                setup_ui_post ();
                return;
            }

            // TODO:
            // Connected devices
            GenericArray<Up.Device> ?devices;
            try {
                devices = yield up_client.get_devices_async (null);

                if (devices == null) {
                    throw new PowerPageErrors.UP_DEVICES_NULL ("List of devices is null");
                }
            } catch (Error e) {
                critical ("Upower get_devices error: %s", e.message);
                devices_group.set_visible (false);
                setup_ui_post ();
                return;
            }

            up_client.device_added.connect ((device) => {
                devices_list.add_device (device);
                devices_group.set_visible (true);
            });
            up_client.device_removed.connect ((object_path) => {
                devices_list.remove_device (object_path);
                devices_group.set_visible (devices_list.n_devices > 0);
            });

            devices_group.set_visible (true);
            foreach (Up.Device device in devices) {
                devices_list.add_device (device);
            }

            setup_ui_post ();
        }

        ///
        /// Power Profile Daemon
        ///

        private void profile_daemon_appear () {
            get_profile_daemon.begin ();
        }

        private void profile_daemon_disappear () {
            profile_daemon = null;
            setup_power_profiles_ui ();
        }

        private async void get_profile_daemon () {
            if (profile_daemon == null) {
                try {
                    profile_daemon = yield Bus.get_proxy (BusType.SYSTEM,
                                                          Power.POWER_PROFILES_DAEMON_NAME,
                                                          Power.POWER_PROFILES_DAEMON_PATH);

                    profile_daemon.g_properties_changed.connect ((changed) => {
                        // TODO: Proper changed handling
                        setup_power_profiles_ui ();
                    });
                } catch (Error e) {
                    warning (e.message);
                }
            }
            setup_power_profiles_ui ();
        }

        private static void change_profile (Adw.ActionRow action_row) {
            PowerModeRow row = (PowerModeRow) action_row;
            string ?profile_name = row.profile.to_string ();
            if (profile_daemon.active_profile != profile_name
                && profile_name != null) {
                profile_daemon.active_profile = profile_name;
            }
        }

        private void setup_power_profiles_ui () {
            power_mode_group.set_visible (profile_daemon != null);
            if (profile_daemon == null) {
                setup_ui_post ();
                return;
            }

            Power.PowerProfiles active_profile =
                Power.PowerProfiles.parse (profile_daemon.active_profile);
            unowned PowerModeRow ?previous_row = null;
            foreach (unowned var profile in profile_daemon.profiles) {
                if (!profile.contains ("Profile")) {
                    critical ("Profile doesn't contain key \"Profile\"");
                    continue;
                }
                unowned Variant profile_variant = profile.get ("Profile");
                if (!profile_variant.is_of_type (VariantType.STRING)) {
                    critical ("Profile value isn't type \"STRING\"");
                    continue;
                }
                var row = new PowerModeRow (profile_variant.dup_string (),
                                            active_profile);
                row.activated.connect (change_profile);
                row.set_check_button_group (previous_row);
                previous_row = row;
                modes_listbox.append (row);
            }

            bool show_info_row = false;
            // TODO: Holds:
            // Set power_mode_label when swaysettings is holding the power-saver profile due to low battery

            // Degraded performance
            if (profile_daemon.performance_degraded != "") {
                show_info_row = true;
                if (profile_daemon.performance_degraded == "lap-detected") {
                    degraded_banner.set_icon ("info-outline-symbolic");
                    degraded_banner.set_text (
                        "Lap detected: performance mode temporarily unavailable. Move the device to a stable surface to restore.");
                } else if (profile_daemon.performance_degraded == "high-operating-temperature") {
                    degraded_banner.set_icon ("thermometer-symbolic");
                    degraded_banner.set_text ("Performance mode temporarily disabled.");
                } else {
                    degraded_banner.set_icon ("warning-outline-symbolic");
                    degraded_banner.set_text ("Performance mode temporarily disabled.");
                }
            }
            power_info_listbox.set_visible (show_info_row);

            setup_ui_post ();
        }
    }
}
