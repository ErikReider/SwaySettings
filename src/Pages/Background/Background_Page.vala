using Gee;

namespace SwaySettings {
    public class Background_Widget : Page {

        private Granite.AsyncImage preview_image = new Granite.AsyncImage (true, false);
        private int preview_image_height = 216;
        private int preview_image_width = 384;
        // Parent for all wallpaper categories
        private Gtk.Box wallpaper_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        private int list_image_height = 144;
        private int list_image_width = 256;

        private Gtk.FlowBox system_wallpaper_flow_box = new Gtk.FlowBox ();

        private ArrayList<Wallpaper ?> system_wallpapers = new ArrayList<Wallpaper ?>();

        public Background_Widget (string page_name, Hdy.Deck deck, IPC ipc) {
            base (page_name, deck, ipc);

            realize.connect (()=> {
                set_preivew_image ();
                add_wallpapers (Functions.get_system_wallpapers (),
                                ref system_wallpapers,
                                ref system_wallpaper_flow_box);
                this.show_all ();
            });

            preview_image.set_size_request (preview_image_width, preview_image_height);
            preview_image.get_style_context ().add_class ("shadow");
            preview_image.get_style_context ().add_class ("background-image-item");
            preview_image.halign = Gtk.Align.CENTER;
            preview_image.valign = Gtk.Align.START;
            preview_image.get_style_context ().add_class ("frame");
            int margin = 24;
            preview_image.set_margin_top (margin - 8);
            preview_image.set_margin_start (margin);
            preview_image.set_margin_bottom (margin);
            preview_image.set_margin_end (margin);
            root_box.add (preview_image);

            wallpaper_box.expand = true;
            wallpaper_box.get_style_context ().add_class ("view");
            get_wallpaper_container (ref system_wallpaper_flow_box, "System Wallpapers");
            root_box.add (Page.get_scroll_widget (wallpaper_box, false, true, int.MAX, int.MAX));

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
            File file = File.new_for_path (path);
            preview_image.set_from_file_async.begin (file,
                                                     preview_image_width,
                                                     preview_image_height,
                                                     true);
        }

        void get_wallpaper_container(ref Gtk.FlowBox flow_box, string title) {
            var header = new Gtk.Label (title);
            header.xalign = 0.0f;
            header.get_style_context ().add_class ("category-title");
            flow_box.max_children_per_line = 8;
            flow_box.min_children_per_line = 1;
            flow_box.homogeneous = true;
            flow_box.set_margin_start (4);
            flow_box.set_margin_top (4);
            flow_box.set_margin_end (4);
            flow_box.set_margin_bottom (4);

            flow_box.child_activated.connect ((widget) => {
                ThumbnailImage img = (ThumbnailImage) widget.get_child ();
                if (img.image_path != null) {
                    set_wallpaper (img.wp.path);
                    set_preivew_image ();
                }
            });

            wallpaper_box.add (header);
            wallpaper_box.add (flow_box);
        }

        void add_wallpapers (ArrayList<Wallpaper?> wallpapers,
                             ref ArrayList<Wallpaper?> compare,
                             ref Gtk.FlowBox flow_box) {
            if(wallpapers.size == 0) return;
            if(wallpapers.size == compare.size) {
                bool equals = true;
                for (int i = 0; i < wallpapers.size; i++) {
                    if (wallpapers[i] != compare[i]) {
                        equals = false;
                        break;
                    }
                }
                if (equals) return;
            }
            compare = wallpapers;
            add_images.begin (compare, flow_box);
        }

        async void add_images (ArrayList<Wallpaper ?> paths, Gtk.FlowBox flow_box) {
            bool checked_folder_exists = false;
            foreach (var path in paths) {
                var item = new List_Lazy_Image (path, list_image_height, list_image_width, ref checked_folder_exists);
                flow_box.add (item);
                Idle.add (add_images.callback);
                yield;
            }
        }
    }
}
