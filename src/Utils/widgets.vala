using Gee;

namespace Utils.Widgets {
    public delegate bool BoolFunc<G> (G data);

    public static void iter_listbox_children<G> (Gtk.ListBox listbox, BoolFunc<G> func) {
        unowned Gtk.Widget ?widget = listbox.get_first_child ();
        if (widget == null) {
            return;
        }
        do {
            if (func (widget)) {
                return;
            }
            widget = widget.get_next_sibling ();
        } while (widget != null && widget != listbox.get_first_child ());
    }

    public static Gdk.Paintable ? gdk_texture_scale (Gdk.Texture texture,
                                                     uint32 ref_width,
                                                     uint32 ref_height,
                                                     int target_width,
                                                     int target_height,
                                                     Gsk.ScalingFilter filter,
                                                     out float new_width,
                                                     out float new_height) {
        calc_scaled_size (ref_width, ref_height,
                          target_width, target_height,
                          out new_width, out new_height);
        Gtk.Snapshot snapshot = new Gtk.Snapshot ();
        Graphene.Rect bounds = Graphene.Rect ().init (0, 0, new_width, new_height);
        snapshot.append_scaled_texture (texture, filter, bounds);
        return snapshot.free_to_paintable (bounds.size);
    }

    public static void calc_scaled_size (float ref_width, float ref_height,
                                         float target_width, float target_height,
                                         out float new_width, out float new_height) {
        new_width = target_width;
        new_height = target_height;
        // At least one dimension matches the target, doesn't need scaling,
        // only translation.
        if (ref_width == target_width || ref_height == target_height) {
            return;
        }

        // Calculate the new scaled size -> the target size
        // Might not need scaling as a 5120x1440 on 2560*1440 doesn't need scaling
        if (target_width > 0 || target_height > 0) {
            if (target_width < 0) {
                new_width = (uint32) (ref_width * target_height / ref_height);
                new_height = target_height;
            } else if (target_height < 0) {
                new_width = target_width;
                new_height = (uint32) (ref_height * target_width / ref_width);
            } else if (ref_height * target_width >
                       ref_width * target_height) {
                new_width = (uint32) (0.5 + ref_width * target_height / ref_height);
                new_height = target_height;
            } else {
                new_width = target_width;
                new_height = (uint32) (0.5 + ref_height * target_width / ref_width);
            }
        } else {
            if (target_width > 0) {
                new_width = target_width;
            }
            if (target_height > 0) {
                new_height = target_height;
            }
        }
        new_width = Math.floorf (float.max (new_width, 1));
        new_height = Math.floorf (float.max (new_height, 1));
    }

    public static Adw.AccentColor accent_color_to_adw (GDesktop.AccentColor color) {
        switch (color) {
            default :
            case GDesktop.AccentColor.BLUE:
                return Adw.AccentColor.BLUE;
            case GDesktop.AccentColor.TEAL:
                return Adw.AccentColor.TEAL;
            case GDesktop.AccentColor.GREEN:
                return Adw.AccentColor.GREEN;
            case GDesktop.AccentColor.YELLOW:
                return Adw.AccentColor.YELLOW;
            case GDesktop.AccentColor.ORANGE:
                return Adw.AccentColor.ORANGE;
            case GDesktop.AccentColor.RED:
                return Adw.AccentColor.RED;
            case GDesktop.AccentColor.PINK:
                return Adw.AccentColor.PINK;
            case GDesktop.AccentColor.PURPLE:
                return Adw.AccentColor.PURPLE;
            case GDesktop.AccentColor.SLATE:
                return Adw.AccentColor.SLATE;
        }
    }

    public static inline Adw.AccentColor get_adw_accent_color (Settings ?settings) {
        GDesktop.AccentColor color_enum = GSchema.get_accent_color (settings);
        return accent_color_to_adw (color_enum);
    }
}
