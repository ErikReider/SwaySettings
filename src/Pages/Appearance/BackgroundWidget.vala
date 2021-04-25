/* window.vala
 *
 * Copyright 2021 Erik Reider
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gee;

namespace SwaySettings {
    public class Background_Widget : Page_Tab {

        private Gtk.Image preview_image = new Gtk.Image ();
        private int preview_image_height = 150;
        private int preview_image_width = 200;
        // Parent for all wallpaper categories
        private Gtk.Box wallpaper_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        private int list_image_height = 100;
        private int list_image_width = 150;

        public delegate Gtk.Widget DelegateWidget (Gtk.Widget widget);

        public Background_Widget (string tab_name, DelegateWidget widget) {
            base (tab_name, widget);
        }

        public override Gtk.Widget init () {
            var widget = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            // preview_image
            set_preivew_image ();
            preview_image.halign = Gtk.Align.CENTER;
            preview_image.valign = Gtk.Align.START;
            preview_image.get_style_context ().add_class ("frame");
            preview_image.set_margin_start (8);
            preview_image.set_margin_bottom (8);
            preview_image.set_margin_end (8);

            wallpaper_box.expand = true;
            wallpaper_box.get_style_context ().add_class ("view");

            add_standard_wallpapers ();

            this.add (preview_image);
            widget.add (wallpaper_box);
            widget.show_all ();
            return widget;
        }

        void set_preivew_image () {
            string path = @"$(GLib.Environment.get_home_dir())/.cache/wallpaper";
            Functions.scale_image_widget (ref preview_image, path, preview_image_width, preview_image_height);
        }

        void add_standard_wallpapers () {
            var wallpaper_header = new Gtk.Label ("Standard Wallpapers");
            var wallpaper_flow_box = new Gtk.FlowBox ();
            wallpaper_flow_box.max_children_per_line = 8;
            wallpaper_flow_box.min_children_per_line = 1;
            wallpaper_flow_box.homogeneous = true;
            wallpaper_flow_box.child_activated.connect ((widget) => {
                Gtk.Image img = ((Gtk.Image)(widget.get_child ()));
                if (img.name != null) {
                    Functions.set_wallpaper (img.name);
                    set_preivew_image ();
                }
            });
            ArrayList<string> wallpaper_paths = Functions.get_wallpapers ();
            async_image_load (wallpaper_paths, ref wallpaper_flow_box);

            wallpaper_box.add (wallpaper_header);
            wallpaper_box.add (wallpaper_flow_box);
        }

        void async_image_load (ArrayList<string> paths, ref Gtk.FlowBox flow_box) {
            Array<Gtk.Image ? > images = new Array<Gtk.Image>();
            images.set_size (paths.size);

            if (!Thread.supported ()) {
                stderr.printf ("Cannot run without thread support.\n");
                for (int i = 0; i < paths.size; i++) {
                    var img = new Gtk.Image ();
                    Functions.scale_image_widget (ref img, paths[i], list_image_width, list_image_height);
                    images.insert_val (i, img);
                }
            } else {
                try {
                    var thread_pool = new ThreadPool<Image_Load_Thread>.with_owned_data ((load_thread) => {
                        load_thread.thread_func ();
                    }, paths.size, false);

                    for (int i = 0; i < paths.size; i++) {
                        thread_pool.add (new Image_Load_Thread (paths[i], ref images, i, list_image_width, list_image_height));
                    }
                } catch (Error e) {
                    print ("ThreadError: %s\n", e.message);
                }
            }

            foreach (Gtk.Image image in images.data) {
                if (image is Gtk.Image && image.get_parent () == null) {
                    flow_box.add (image);
                }
            }
        }
    }

    class Image_Load_Thread {

        private string path;
        private int index;
        private int img_w;
        private int img_h;
        private Array<Gtk.Image> images;

        public Image_Load_Thread (string path, ref Array<Gtk.Image> images, int index, int img_w, int img_h) {
            this.path = path;
            this.images = images;
            this.index = index;
            this.img_w = img_w;
            this.img_h = img_h;
        }

        public void thread_func () {
            var img = new Gtk.Image ();
            img.name = path;
            Functions.scale_image_widget (ref img, path, img_w, img_h);
            images.insert_val (index, img);
        }
    }
}
