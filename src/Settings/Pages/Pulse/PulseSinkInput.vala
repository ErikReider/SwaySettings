using PulseAudio;
using Gee;

namespace SwaySettings {
    public class PulseSinkInput : Object {
        /** The card index: ex. `Sink Input #227` */
        public uint32 index;
        /** The sink index: ex. `55` */
        public uint32 sink_index;
        /** The client index: ex. `266` */
        public uint32 client_index;

        /** The name of the application: `application.name` */
        public string name;
        /** The name of the application binary: `application.process.binary` */
        public string application_binary;
        /** The application icon. Can be null: `application.icon_name` */
        public string? application_icon_name;
        /** The name of the media: `media.name` */
        public string media_name;

        /** The mute state: `Mute` */
        public bool is_muted;

        public double volume;
        public float balance { get; set; default = 0; }
        public CVolume cvolume;
        public ChannelMap channel_map;
        public LinkedList<Operation> volume_operations;

        /** Gets the name to be shown to the user:
         * "application_name"
         */
        public string ? get_display_name () {
            return name;
        }

        public bool cmp (PulseSinkInput sink_input) {
            return sink_input.index == index
                   && sink_input.sink_index == sink_index
                   && sink_input.client_index == client_index
                   && sink_input.name == name
                   && sink_input.application_binary == application_binary
                   && sink_input.is_muted == is_muted
                   && sink_input.volume == volume;
        }

        /** Gets the name to be shown to the user:
         * "index:application_name"
         */
        public static uint32 get_hash_map_key (uint32 i) {
            return i;
        }

        construct {
            volume_operations = new LinkedList<Operation> ();
        }
    }

    [GtkTemplate (ui = "/org/erikreider/swaysettings/ui/PulseSinkInput.ui")]
    public class SinkInputRow : Gtk.ListBoxRow {
        [GtkChild]
        unowned Gtk.ToggleButton mute_toggle;

        [GtkChild]
        unowned Gtk.Label output_value;

        [GtkChild]
        unowned Gtk.Scale scale;

        [GtkChild]
        unowned Gtk.Image icon;

        [GtkChild]
        unowned Gtk.Label title;
        [GtkChild]
        unowned Gtk.Label media_name;

        public unowned PulseSinkInput sink_input;

        private unowned PulseDaemon client;

        public SinkInputRow (PulseSinkInput sink_input, PulseDaemon client) {
            this.client = client;

            update (sink_input);

            this.set_activatable (false);
            this.set_selectable (false);

            scale.add_mark (25, Gtk.PositionType.TOP, null);
            scale.add_mark (50, Gtk.PositionType.TOP, null);
            scale.add_mark (75, Gtk.PositionType.TOP, null);

            mute_toggle.bind_property ("active",
                                       scale, "sensitive",
                                       BindingFlags.INVERT_BOOLEAN);
            mute_toggle.toggled.connect ((button) => {
                string icon = button.active
                    ? PulseContent.TOGGLE_ICON_MUTED
                    : PulseContent.TOGGLE_ICON_UNMUTED;
                button.set_icon_name (icon);

                client.set_sink_input_mute (button.active, sink_input);
            });
            scale.value_changed.connect (() => {
                output_value.label = "%.0lf".printf(Math.round (scale.get_value ()));
                output_value.label = ((int) scale.get_value ()).to_string ();
                client.set_sink_input_volume (
                    sink_input,
                    (float) scale.get_value ());
            });
        }

        public void update (PulseSinkInput sink_input) {
            this.sink_input = sink_input;

            title.set_markup (Markup.printf_escaped (
                    "<span text_transform='capitalize'>%s</span>", sink_input.name));
            title.set_visible (sink_input.name != null && sink_input.name.length > 0);

            media_name.set_visible (sink_input.media_name != null
                && sink_input.media_name.length > 0);
            media_name.set_markup (Markup.printf_escaped (
                    "<span text_transform='capitalize'>%s</span>", sink_input.media_name));

            icon.set_from_icon_name (
                sink_input.application_icon_name ?? "application-x-executable");

            mute_toggle.set_active (sink_input.is_muted);

            scale.set_value (sink_input.volume);
            output_value.label = "%.0lf".printf(Math.round (scale.get_value ()));
        }
    }
}
