namespace SwaySettings.Pages.Pulse {
    [GtkTemplate (ui = "/org/erikreider/swaysettings/ui/PulseSliderWidget.ui")]
    internal class SliderWidget : Gtk.Box {
        public const string DEFAULT_ICON_NAME_MUTED = "audio-volume-muted-symbolic";
        public const string DEFAULT_ICON_NAME_UNMUTED = "audio-volume-high-symbolic";

        public signal void mute_toggled (bool is_muted);
        public signal void value_changed (double volume);

        [GtkChild]
        unowned Gtk.Adjustment adjustment;
        ulong value_changed_id = 0;

        [GtkChild]
        unowned Gtk.ToggleButton mute_toggle;
        ulong mute_changed_id = 0;

        construct {
            value_changed_id = adjustment.notify["value"].connect (value_changed_cb);
            mute_changed_id = mute_toggle.toggled.connect (mute_toggled_cb);
        }

        public void set_state (double volume, bool is_muted) {
            SignalHandler.block (adjustment, value_changed_id);
            adjustment.set_value (volume);
            SignalHandler.unblock (adjustment, value_changed_id);

            SignalHandler.block (mute_toggle, mute_changed_id);
            mute_toggle.set_active (is_muted);
            SignalHandler.unblock (mute_toggle, mute_changed_id);
        }

        private void value_changed_cb () {
            value_changed (adjustment.value);
        }

        private void mute_toggled_cb (Gtk.ToggleButton toggle_button) {
            mute_toggled (toggle_button.active);
        }

        [GtkCallback]
        private string format_scale_value (double volume) {
            return "%.0lf".printf (Math.round (volume));
        }

        [GtkCallback]
        private string get_mute_icon_name (bool is_muted) {
            return is_muted ? DEFAULT_ICON_NAME_MUTED : DEFAULT_ICON_NAME_UNMUTED;
        }
    }
}
