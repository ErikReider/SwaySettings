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
        unowned Gtk.Box battery_group;
        [GtkChild]
        unowned Gtk.Image battery_group_icon;
        [GtkChild]
        unowned Gtk.Label battery_group_percent;
        [GtkChild]
        unowned Gtk.Label battery_group_status;
        [GtkChild]
        unowned Gtk.ProgressBar battery_group_progress;

        [GtkChild]
        unowned Adw.PreferencesGroup battery_health_group;
        [GtkChild]
        unowned Gtk.Label health_status_label;
        [GtkChild]
        unowned Gtk.Label health_capacity_label;
        [GtkChild]
        unowned Adw.ActionRow health_cycles_row;
        [GtkChild]
        unowned Gtk.Label health_cycles_label;
        [GtkChild]
        unowned Adw.SwitchRow threshold_toggle;
        ulong threshold_toggle_toggle_id = 0;

        [GtkChild]
        unowned Adw.PreferencesGroup options_group;

        [GtkChild]
        unowned Adw.PreferencesGroup devices_group;
        [GtkChild]
        unowned PowerDeviceList devices_list;

        [GtkChild]
        unowned Adw.PreferencesGroup power_mode_group;

        [GtkChild]
        unowned Gtk.ListBox modes_listbox;
        ListStore modes_liststore;

        [GtkChild]
        unowned Gtk.ListBox power_info_listbox;
        [GtkChild]
        unowned PowerInfoBanner degraded_banner;
        [GtkChild]
        unowned PowerInfoBanner power_mode_banner;

        Up.Device display_device = null;
        ulong display_device_notify_id = 0;
        Up.Device ?ref_display_device = null;
        Up.DeviceProxy ?ref_display_device_proxy = null;
        ulong ref_display_device_notify_id = 0;

        construct {
            modes_liststore = new ListStore (typeof (PowerModeRow));
            modes_listbox.bind_model (modes_liststore, (obj) => {
                PowerModeRow row = (PowerModeRow) obj;
                return row;
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

            setup_display_device ();

            setup_upower_battery.begin ();
            setup_upower_devices.begin ();
        }

        private void setup_display_device () {
            if (ref_display_device != null) {
                if (ref_display_device_notify_id > 0) {
                    ref_display_device.disconnect (ref_display_device_notify_id);
                    ref_display_device_notify_id = 0;
                }
            }
            if (display_device != null) {
                if (display_device_notify_id > 0) {
                    display_device.disconnect (display_device_notify_id);
                    display_device_notify_id = 0;
                }
            }

            display_device = up_client.get_display_device ();
            ref_display_device = null;
            foreach (unowned Up.Device device in up_client.get_devices2 ()) {
                if (device.kind == Up.DeviceKind.BATTERY && device.power_supply) {
                    ref_display_device = device;
                    ref_display_device_notify_id = ref_display_device.notify.connect (() => {
                        setup_upower_battery_health ();
                    });
                    ref_display_device_proxy = Up.get_device_proxy (ref_display_device);
                    break;
                }
            }

            display_device_notify_id = display_device.notify.connect (() => {
                setup_upower_battery_status ();
            });
        }

        private async void setup_upower_battery () {
            // TODO: swaysettings UPower daemon:
            // - Auto set low power when reach threshold
            // - Auto set profile depending on if charging or not
            // - Above handle if no battery is present
            // - Notify when devices and battery reach multiple thresholds (25%, 10%, etc...)
            // TODO: Battery graph
            // TODO: Battery profile selector for plugged in and on battery
            battery_group.set_visible (up_client != null);
            options_group.set_visible (up_client != null);
            battery_health_group.set_visible (up_client != null);

            if (up_client == null) {
                setup_ui_post ();
                return;
            }

            setup_upower_battery_status ();
            setup_upower_battery_health ();

            options_group.set_visible (display_device.is_present);
            // TODO:
            options_group.set_visible (false);

            setup_ui_post ();
        }

        private void setup_upower_battery_status () {
            // TODO: Support multiple batteries and UPS

            battery_group.set_visible (display_device.is_present);

            // Percent
            battery_group_percent.set_text (
                PowerBatteryState.get_battery_percent (display_device, true));

            // Icon
            battery_group_icon.set_from_icon_name (display_device.icon_name);

            // Status
            string ?state = PowerBatteryState.get_battery_status (display_device);
            battery_group_status.set_text (state);
            battery_group_status.set_visible (state != null);

            // Progress
            double percent = display_device.percentage;
            uint percent_max = 100;
            if (ref_display_device != null
                && ref_display_device.charge_threshold_supported
                && ref_display_device.charge_threshold_enabled) {
                percent_max = ref_display_device.charge_end_threshold;
            }
            battery_group_progress.set_fraction (percent / percent_max);
        }

        private void setup_upower_battery_health () {
            battery_health_group.set_visible (false);

            if (ref_display_device == null) {
                return;
            }

            battery_health_group.set_visible (display_device.is_present);

            // Health state
            health_status_label.set_text (ref_display_device.capacity_level);

            // Max capacity
            health_capacity_label.set_text ("%.0lf%%".printf (ref_display_device.capacity));

            // Cycles
            health_cycles_row.set_visible (ref_display_device.charge_cycles > -1);
            health_cycles_label.set_text (ref_display_device.charge_cycles.to_string ());

            // Charge threshold
            bool has_threshold = ref_display_device.charge_threshold_supported
                && ref_display_device_proxy != null;
            threshold_toggle.set_visible (has_threshold);
            if (threshold_toggle_toggle_id > 0) {
                threshold_toggle.disconnect (threshold_toggle_toggle_id);
                threshold_toggle_toggle_id = 0;
            }
            if (has_threshold) {
                threshold_toggle.set_active (ref_display_device.charge_threshold_enabled);
                threshold_toggle_toggle_id = threshold_toggle.notify["active"].connect (() => {
                    if (threshold_toggle.active != ref_display_device.charge_threshold_enabled) {
                        try {
                            ref_display_device_proxy.enable_charge_threshold (threshold_toggle.active);
                        } catch (Error e) {
                            critical (e.message);
                        }
                    }
                });
            }
        }

        private async void setup_upower_devices () {
            if (up_client == null) {
                devices_group.set_visible (false);
                setup_ui_post ();
                return;
            }

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
                devices_group.set_visible (devices_list.n_devices > 0);
                setup_display_device ();
            });
            up_client.device_removed.connect ((object_path) => {
                devices_list.remove_device (object_path);
                devices_group.set_visible (devices_list.n_devices > 0);
                setup_display_device ();
            });

            foreach (Up.Device device in devices) {
                devices_list.add_device (device);
            }
            devices_group.set_visible (devices_list.n_devices > 0);

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
            if (modes_liststore.n_items == 0) {
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
                    PowerModeRow row = new PowerModeRow (profile_variant.dup_string (),
                                                         active_profile);
                    row.activated.connect (change_profile);
                    row.set_check_button_group (previous_row);
                    previous_row = row;
                    modes_liststore.append (row);
                }
                modes_liststore.sort ((a, b) => {
                    unowned PowerModeRow row_a = (PowerModeRow) a;
                    unowned PowerModeRow row_b = (PowerModeRow) b;
                    return row_a.profile > row_b.profile ? 1 : -1;
                });
            } else {
                // Set the active row on external change
                for (uint i = 0; i < modes_liststore.n_items; i++) {
                    PowerModeRow row = (PowerModeRow) modes_liststore.get_item (i);
                    if (row.set_active (active_profile)) {
                        break;
                    }
                }
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
