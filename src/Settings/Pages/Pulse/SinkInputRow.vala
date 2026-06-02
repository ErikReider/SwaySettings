using Gee;
using PulseAudio;

namespace SwaySettings.Pages.Pulse {
    [GtkTemplate (ui = "/org/erikreider/swaysettings/ui/PulseSinkInputRow.ui")]
    public class SinkInputRow : Gtk.ListBoxRow {
        public signal void mute_toggled (bool is_muted);
        public signal void value_changed (double volume);

        [GtkChild]
        unowned Gtk.Image icon;

        [GtkChild]
        unowned Gtk.Label title;
        [GtkChild]
        unowned Gtk.Label media_name;

        [GtkChild]
        unowned SliderWidget slider;

        public PulseSinkInput sink_input { get; private set; }

        public SinkInputRow (PulseSinkInput sink_input) {
            this.sink_input = sink_input;

            sink_input.changed.connect (update_ui);

            slider.mute_toggled.connect ((is_muted) => mute_toggled (is_muted));
            slider.value_changed.connect ((volume) => value_changed (volume));

            update_ui ();
        }

        public void update_ui () {
            title.set_markup (Markup.printf_escaped (
                                  "<span text_transform=\"capitalize\">%s</span>",
                                  sink_input.name));
            title.set_visible (sink_input.name != null && sink_input.name.length > 0);

            media_name.set_visible (sink_input.media_name != null
                                    && sink_input.media_name.length > 0);
            media_name.set_markup (Markup.printf_escaped (
                                       "<span text_transform=\"capitalize\">%s</span>",
                                       sink_input.media_name));

            icon.set_from_icon_name (
                sink_input.application_icon_name ?? "application-x-executable");

            slider.set_state (sink_input.volume, sink_input.is_muted);
        }
    }
}
