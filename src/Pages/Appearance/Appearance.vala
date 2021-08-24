using Gee;

namespace SwaySettings {
    public class Appearance_Page : Page_Tabbed {

        public Appearance_Page (string label, Hdy.Deck deck, IPC ipc) {
            base (label, deck, ipc);
        }

        public override Page_Tab[] tabs () {
            return {
                       new Background_Widget ("Background", ipc),
                       new Themes_Widget ("Themes", ipc),
            };
        }
    }
}
