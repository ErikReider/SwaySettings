using Gee;
using PulseAudio;
using Utils;

namespace SwaySettings.Pages.Pulse {
    // TODO: Simplify all of these. Only use one class instead
    public class PulsePage : PageScroll {
        Content content;

        public PulsePage (SettingsItem item, Adw.NavigationPage page) {
            base (item, page);
        }

        public override Gtk.Widget set_child () {
            content = new Content ();
            return content;
        }

        public override async void on_back (Adw.NavigationPage page) {
            yield content.on_back ();
        }
    }

    [GtkTemplate (ui = "/org/erikreider/swaysettings/ui/PulsePage.ui")]
    private class Content : Adw.Bin {
        [GtkChild]
        unowned Gtk.Stack stack;

        // Sink
        [GtkChild]
        unowned DeviceComboRow output_combo_row;
        [GtkChild]
        unowned SliderWidget output_slider;

        // Bluetooth Profile ComboBox
        [GtkChild]
        unowned Adw.ComboRow profile_combo_row;
        ListStore profile_list_store;
        ulong profile_changed_id = 0;

        // Source
        [GtkChild]
        unowned DeviceComboRow input_combo_row;
        [GtkChild]
        unowned SliderWidget input_slider;

        // Sink inputs
        [GtkChild]
        public unowned Gtk.ListBox levels_listbox;
        ListStore sink_inputs_list_store;

        private PulseDaemon client = null;

        construct {
            client = new PulseDaemon ();
            client.change_device.connect (device_change);
            client.new_device.connect (device_added);
            client.remove_device.connect (device_removed);
            client.default_device_changed.connect (default_device_changed);

            client.new_active_sink.connect (sink_input_added);
            client.remove_active_sink.connect (sink_input_removed);

            //
            // Sinks/Sources UI signals
            //

            // Hide / show the page depending on the service state
            client.bind_property ("running", stack, "visible-child-name",
                                  BindingFlags.SYNC_CREATE,
                                  (bind, from_value, ref to_value) => {
                to_value = from_value.get_boolean () ? "pulse-page" : "error-page";
                return true;
            });

            // Set slider sensitivity depending on if there's a default device
            client.notify["default-sink"].connect (() => {
                output_slider.sensitive = client.default_sink != null;
            });
            client.notify["default-source"].connect (() => {
                input_slider.sensitive = client.default_source != null;
            });
            // Handle mute toggles
            output_slider.mute_toggled.connect ((is_muted) => {
                if (client.default_sink != null) {
                    client.set_device_mute (is_muted, client.default_sink);
                }
            });
            input_slider.mute_toggled.connect ((is_muted) => {
                if (client.default_source != null) {
                    client.set_device_mute (is_muted, client.default_source);
                }
            });
            // Handle volume slider change
            output_slider.value_changed.connect ((volume) => {
                if (client.default_sink != null) {
                    client.set_device_volume (client.default_sink, (float) volume);
                }
            });
            input_slider.value_changed.connect ((volume) => {
                if (client.default_source != null) {
                    client.set_device_volume (client.default_source, (float) volume);
                }
            });

            output_combo_row.selected_changed.connect (device_combo_row_changed);
            input_combo_row.selected_changed.connect (device_combo_row_changed);

            //
            // Sink Bluetooth Profiles
            //

            profile_changed_id =
                profile_combo_row.notify["selected"].connect (profile_combo_row_changed);
            profile_list_store = new ListStore (typeof (PulseCardProfile));
            profile_list_store.bind_property ("n-items",
                                              profile_combo_row, "visible",
                                              BindingFlags.SYNC_CREATE);
            var expression = new Gtk.PropertyExpression (typeof (PulseCardProfile),
                                                         null,
                                                         "description");
            profile_combo_row.set_expression (expression);
            profile_combo_row.set_model (profile_list_store);

            //
            // Sink inputs
            //

            sink_inputs_list_store = new ListStore (typeof (PulseSinkInput));
            levels_listbox.bind_model (sink_inputs_list_store, create_sink_input_row_cb);

            // Begin
            client.start ();
        }

        public async void on_back () {
            if (profile_changed_id > 0) {
                profile_combo_row.disconnect (profile_changed_id);
                profile_changed_id = 0;
            }

            client.change_device.disconnect (device_change);
            client.new_device.disconnect (device_added);
            client.remove_device.disconnect (device_removed);
            client.default_device_changed.disconnect (default_device_changed);

            client.new_active_sink.disconnect (sink_input_added);
            client.remove_active_sink.disconnect (sink_input_removed);

            client.close ();
        }

        /*
         * Sinks/Sources
         */

        private async void device_combo_row_changed (PulseDevice ?device) {
            if (device == null) {
                return;
            }
            PulseDevice ?prev_default = device.direction == PulseAudio.Direction.INPUT ?
                client.default_source : client.default_sink;

            // Check if setting the same device
            if (prev_default != null && device.cmp (prev_default)) {
                return;
            }

            yield client.set_default_device (device);
        }

        private async void profile_combo_row_changed () {
            unowned PulseCardProfile ?profile =
                (PulseCardProfile ?) profile_combo_row.get_selected_item ();
            if (profile == null) {
                return;
            }

            // Check if setting the same profile for the default sink
            PulseDevice ?device = client.default_sink;
            if (device != null &&
                device.active_profile != null &&
                profile.cmp (device.active_profile)) {
                return;
            }

            SignalHandler.block (profile_combo_row, profile_changed_id);
            yield client.set_bluetooth_card_profile (profile, device);

            SignalHandler.unblock (profile_combo_row, profile_changed_id);
        }

        private void set_device_profiles (PulseDevice device) {
            SignalHandler.block (profile_combo_row, profile_changed_id);

            uint selected_index = Gtk.INVALID_LIST_POSITION;
            profile_list_store.remove_all ();
            for (uint i = 0; i < device.profiles.length; i++) {
                unowned PulseCardProfile profile = device.profiles.data[i];
                profile_list_store.insert_sorted (profile, (_a, _b) => {
                    return strcmp (((PulseCardProfile) _a).name, ((PulseCardProfile) _b).name);
                });

                // Check if active profile
                if (profile.name == device.card_active_profile) {
                    selected_index = i;
                }
            }

            profile_combo_row.set_selected (selected_index);

            SignalHandler.unblock (profile_combo_row, profile_changed_id);
        }

        private void device_change (PulseDevice device) {
            // Change UI if device is default device
            unowned PulseDevice ?default_device =
                device.is_input ? client.default_source : client.default_sink;
            if (default_device == null || !device.cmp (default_device)) {
                return;
            }

            if (!device.is_input) {
                if (device.is_bluetooth && device.has_card) {
                    set_device_profiles (device);
                } else {
                    SignalHandler.block (profile_combo_row, profile_changed_id);
                    profile_list_store.remove_all ();
                    SignalHandler.unblock (profile_combo_row, profile_changed_id);
                }
            }

            // Set the default device as selected
            DeviceComboRow combo_row =
                device.is_input ? input_combo_row : output_combo_row;
            combo_row.update_default_device (device);

            // Set volume and mute state
            SliderWidget slider =
                device.is_input ? input_slider : output_slider;
            slider.set_state (device.volume, device.is_muted);
        }

        private void device_added (PulseDevice device) {
            DeviceComboRow combo_row =
                device.is_input ? input_combo_row : output_combo_row;
            combo_row.add_device (device);
        }

        private void device_removed (PulseDevice device) {
            DeviceComboRow combo_row =
                device.is_input ? input_combo_row : output_combo_row;
            combo_row.remove_device (device);
        }

        private void default_device_changed (PulseDevice device) {
            if (device == null) {
                return;
            }
            switch (device.direction) {
                case Direction.INPUT:
                    input_combo_row.update_default_device (device);
                    break;
                case Direction.OUTPUT:
                    output_combo_row.update_default_device (device);
                    break;
            }
        }

        /*
         * Sink Inputs
         */

        /** Sorts by each device HashMap id */
        private int sink_inputs_sort_fn (Object _a, Object _b) {
            PulseSinkInput a = ((PulseSinkInput) _a);
            PulseSinkInput b = ((PulseSinkInput) _b);
            if (a.index == b.index) {
                return 0;
            }
            return a.index < b.index ? -1 : 1;
        }

        /** Adds a new `SinkInputRow` */
        private void sink_input_added (PulseSinkInput sink_input) {
            sink_inputs_list_store.insert_sorted (sink_input, sink_inputs_sort_fn);
        }

        /** Removes the correct `SinkInputRow` */
        private void sink_input_removed (PulseSinkInput sink_input) {
            uint position;
            bool found = sink_inputs_list_store.find_with_equal_func (sink_input,
                                                                      IPulseModuleType.equals,
                                                                      out position);
            if (!found) {
                return;
            }

            sink_inputs_list_store.remove (position);
        }

        private void sink_input_row_mute_toggled (SinkInputRow row, bool is_muted) {
            client.set_sink_input_mute (is_muted, row.sink_input);
        }

        private void sink_input_row_volume_changed (SinkInputRow row, double volume) {
            client.set_sink_input_volume (row.sink_input, (float) volume);
        }

        private Gtk.Widget create_sink_input_row_cb (Object item) {
            unowned PulseSinkInput sink_input = (PulseSinkInput) item;
            SinkInputRow row = new SinkInputRow (sink_input);
            row.mute_toggled.connect (sink_input_row_mute_toggled);
            row.value_changed.connect (sink_input_row_volume_changed);
            return row;
        }
    }
}
