namespace SwaySettings {
    public interface IIpcPage {
        public abstract unowned IPC ipc { get; set; }
    }

    public class NoIpcPage : Page {
        public NoIpcPage (SettingsItem item, Adw.NavigationPage page) {
            base (item, page);

            set_sensitive (false);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            box.set_valign (Gtk.Align.CENTER);
            set_child (box);

            var image = new Gtk.Image.from_icon_name ("arrows-questionmark-symbolic");
            image.set_pixel_size (128);
            box.append (image);

            var label = new Gtk.Label ("No Socket connection");
            box.append (label);
        }
    }
}
