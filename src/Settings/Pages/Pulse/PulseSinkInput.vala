using Gee;
using PulseAudio;

namespace SwaySettings.Pages.Pulse {
    public class PulseSinkInput : Object, IPulseModuleType<PulseSinkInput> {
        /** The card index: ex. `Sink Input #227` */
        public uint32 index { get; set; }
        /** The sink index: ex. `55` */
        public uint32 sink_index { get; set; }
        /** The client index: ex. `266` */
        public uint32 client_index { get; set; }

        /** The name of the application: `application.name` */
        public string name { get; set; }
        /** The name of the application binary: `application.process.binary` */
        public string application_binary { get; set; }
        /** The application icon. Can be null: `application.icon_name` */
        public string ?application_icon_name { get; set; }
        /** The name of the media: `media.name` */
        public string media_name { get; set; }

        /** The mute state: `Mute` */
        public bool is_muted { get; set; }

        public double volume { get; set; }
        public float balance { get; set; default = 0; }
        public CVolume cvolume;
        public ChannelMap channel_map;
        public LinkedList<Operation> volume_operations;

        public signal void changed ();

        /** Gets the name to be shown to the user:
         * "application_name"
         */
        public string ?get_display_name () {
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
}
