using Gee;

namespace SwaySettings {
    public class Background_Widget : Page_Tab {

        private Gtk.Image preview_image = new Gtk.Image ();
        private int preview_image_height = 150;
        private int preview_image_width = 275;
        // Parent for all wallpaper categories
        private Gtk.Box wallpaper_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        private int list_image_height = 115;
        private int list_image_width = 154;

        public Background_Widget (string tab_name, IPC ipc) {
            base (tab_name, ipc);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            // preview_image
            set_preivew_image ();
            preview_image.get_style_context ().add_class ("shadow");
            preview_image.halign = Gtk.Align.CENTER;
            preview_image.valign = Gtk.Align.START;
            preview_image.get_style_context ().add_class ("frame");
            int margin = 24;
            preview_image.set_margin_top (margin - 8);
            preview_image.set_margin_start (margin);
            preview_image.set_margin_bottom (margin);
            preview_image.set_margin_end (margin);

            wallpaper_box.expand = true;
            wallpaper_box.get_style_context ().add_class ("view");

            add_system_wallpapers ();

            this.add (preview_image);
            box.add (wallpaper_box);
            box.show_all ();
            this.add (Page.get_scroll_widget (box, false, true, int.MAX, int.MAX));
            this.show_all ();
        }

        private void set_wallpaper (string path) {
            if (path == null) return;
            string wall_dir = @"$(Environment.get_user_cache_dir())/wallpaper";
            Posix.system (@"cp $(path.replace (" ", "\\ ")) $(wall_dir)");
            ipc.run_command (@"output * bg $(wall_dir) fill");
        }

        void set_preivew_image () {
            string path = @"$(GLib.Environment.get_home_dir())/.cache/wallpaper";
            Functions.scale_image_widget (ref preview_image, path, preview_image_width, preview_image_height);
        }

        void add_system_wallpapers () {
            var wallpaper_header = new Gtk.Label ("System Wallpapers");
            wallpaper_header.xalign = 0.0f;
            wallpaper_header.get_style_context ().add_class ("category-title");
            var wallpaper_flow_box = new Gtk.FlowBox ();
            wallpaper_flow_box.max_children_per_line = 8;
            wallpaper_flow_box.min_children_per_line = 1;
            wallpaper_flow_box.homogeneous = true;
            wallpaper_flow_box.set_margin_start (4);
            wallpaper_flow_box.set_margin_top (4);
            wallpaper_flow_box.set_margin_end (4);
            wallpaper_flow_box.set_margin_bottom (4);

            wallpaper_flow_box.child_activated.connect ((widget) => {
                List_Lazy_Image img = (List_Lazy_Image) widget.get_child ();
                if (img.image_path != null) {
                    set_wallpaper (img.image_path);
                    set_preivew_image ();
                }
            });

            add_images.begin (Functions.get_wallpapers (), wallpaper_flow_box);

            wallpaper_box.add (wallpaper_header);
            wallpaper_box.add (wallpaper_flow_box);
        }

        async void add_images (ArrayList<string> paths, Gtk.FlowBox flow_box) {
            foreach (var path in paths) {
                flow_box.add (new List_Lazy_Image (path, list_image_height, list_image_width));
                Idle.add (add_images.callback);
                yield;
            }
        }
    }
}
