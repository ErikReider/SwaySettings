// vim: ft=vala

namespace GDesktop {
    [SimpleType]
    [CCode (cheader_filename = "gdesktop-enums.h", cname = "GDesktopAccentColor", has_type_id = false, cprefix = "G_DESKTOP_ACCENT_COLOR_")]
    public enum AccentColor {
        BLUE,
        TEAL,
        GREEN,
        YELLOW,
        ORANGE,
        RED,
        PINK,
        PURPLE,
        SLATE
    }
}
