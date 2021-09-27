namespace SwaySettings {
    [GtkTemplate (ui = "/org/erikreider/swaysettings/Widgets/ActionDialog/ActionDialog.ui")]
    public class ActionDialog : Hdy.Window {
        [GtkChild]
        unowned Hdy.HeaderBar header_bar;

        [GtkChild]
        unowned Gtk.ButtonBox actions_box;

        [GtkChild]
        unowned Gtk.Box content;

        int response = -1;


        public ActionDialog (string title, Gtk.Window window) {
            header_bar.set_title (title);
            set_transient_for (window);
        }

        public Gtk.ResponseType run () {
            this.show();
            while (response == -1) {
            }
            return Gtk.ResponseType.NONE;
        }
    }
}
