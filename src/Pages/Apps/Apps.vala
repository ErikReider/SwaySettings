using Gee;

namespace SwaySettings {
    public class Apps : Page_Tabbed {

        public Apps (string label, Hdy.Deck deck, IPC ipc) {
            base (label, deck, ipc);
        }

        public override Page_Tab[] tabs () {
            return {
                       new Default_Apps ("Default Apps", ipc),
                       new Startup_Apps ("Startup Apps", ipc),
            };
        }
    }
}
