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
            typeof (BatteryGraphWidget).ensure ();
        }

        public override Gtk.Widget set_child () {
            return new PowerPageContent ();
        }
    }

    [GtkTemplate (ui = "/org/erikreider/swaysettings/ui/PowerPageContent.ui")]
    private class PowerPageContent : Adw.Bin {
        const string STACK_PAGE = "page";
        const string STACK_PLACEHOLDER_PAGE = "placeholder";

        static unowned UPower.PowerProfileDaemon ?profile_daemon = null;
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
        unowned Adw.PreferencesGroup battery_history_row;
        [GtkChild]
        unowned BatteryGraphWidget history_graph;

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
        unowned Adw.SwitchRow auto_power_saver_row;

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
        ListStore power_info_liststore;

        UPower.PowerProfileDaemonHelper ppd_helper = new UPower.PowerProfileDaemonHelper ();

        Up.Device display_device = null;
        ulong display_device_notify_id = 0;
        Up.Device ?ref_display_device = null;
        UPower.UPowerDeviceProxy ?ref_display_device_proxy = null;
        ulong ref_display_device_notify_id = 0;

        construct {
            modes_liststore = new ListStore (typeof (PowerModeRow));
            modes_listbox.bind_model (modes_liststore, (obj) => {
                PowerModeRow row = (PowerModeRow) obj;
                return row;
            });

            power_info_liststore = new ListStore (typeof (PowerInfoBanner));
            power_info_listbox.bind_model (power_info_liststore, (obj) => {
                PowerInfoBanner row = (PowerInfoBanner) obj;
                return row;
            });

            self_settings.bind (Constants.SETTINGS_POWER_AUTO_POWER_SAVER,
                                auto_power_saver_row, "active",
                                SettingsBindFlags.DEFAULT);

            stack.set_visible_child_name (STACK_PAGE);

            // PowerProfileDaemon
            ppd_helper.profile_released.connect ((cookie) => {
                setup_power_profiles_ui ();
            });
            ppd_helper.properties_changed.connect (() => {
                // TODO: Proper changed handling
                setup_power_profiles_ui ();
            });
            ppd_helper.disappear.connect (() => {
                profile_daemon = null;
                setup_power_profiles_ui ();
            });
            ppd_helper.appear.connect ((ppd) => {
                profile_daemon = ppd;
                setup_power_profiles_ui ();
            });
            ppd_helper.get_async.begin ((obj, res) => {
                profile_daemon = ppd_helper.get_async.end (res);
                setup_power_profiles_ui ();
            });
            // UPower
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
                    ref_display_device_proxy = UPower.get_device_proxy (ref_display_device);
                    break;
                }
            }

            bool has_history = ref_display_device != null && ref_display_device.has_history;

            battery_history_row.set_visible (has_history);
            if (has_history) {
                history_graph.init.begin (ref_display_device);
            }

            display_device_notify_id = display_device.notify.connect (() => {
                setup_upower_battery_status ();
            });
        }

        private async void setup_upower_battery () {
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

            // TODO:
            options_group.set_visible (display_device.is_present);

            setup_ui_post ();
        }

        private void setup_upower_battery_status () {
            // TODO: Support multiple batteries and UPS

            battery_group.set_visible (display_device.is_present);

            // Percent
            battery_group_percent.set_text (
                UPower.UPowerBatteryState.get_battery_percent (display_device, true));

            // Icon
            battery_group_icon.set_from_icon_name (display_device.icon_name);

            // Status
            string ?state = UPower.UPowerBatteryState.get_battery_status (display_device);
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
                            ref_display_device_proxy.enable_charge_threshold (
                                threshold_toggle.active);
                        } catch (Error e) {
                            critical (e.message);
                        }
                    }
                });
                threshold_toggle.set_subtitle (
                    "Limit set to %.0f%% charge".printf (
                        ref_display_device.charge_end_threshold));
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

            UPower.PowerProfiles active_profile =
                UPower.PowerProfiles.parse (profile_daemon.active_profile);
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

            // Profile information
            power_info_liststore.remove_all ();

            // Display if any profile is being held
            HashTable<string, Variant>[] holds = profile_daemon.active_profile_holds;
            if (holds.length > 0) {
                foreach (unowned var info in holds) {
                    if (!info.contains ("Profile")) {
                        critical ("Profile doesn't contain key \"Profile\"");
                        continue;
                    }
                    string profile = info["Profile"].dup_string ();
                    if (!info.contains ("Reason")) {
                        critical ("Profile doesn't contain key \"Profile\"");
                        continue;
                    }
                    string reason = info["Reason"].dup_string ();

                    PowerInfoBanner holds_banner = new PowerInfoBanner ();
                    if (profile == "performance") {
                        holds_banner.set_icon ("power-profile-performance-symbolic");
                    } else if (profile == "power-saver") {
                        holds_banner.set_icon ("power-profile-power-saver-symbolic");
                    } else {
                        holds_banner.set_icon ("power-profile-balanced-symbolic");
                    }
                    holds_banner.set_text (reason);
                    power_info_liststore.append (holds_banner);
                }
            }

            // Display if the performance is degraded
            if (profile_daemon.performance_degraded != "") {
                PowerInfoBanner degraded_banner = new PowerInfoBanner ();
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
                power_info_liststore.append (degraded_banner);
            }

            power_info_listbox.set_visible (power_info_liststore.n_items > 0);

            setup_ui_post ();
        }
    }
}
