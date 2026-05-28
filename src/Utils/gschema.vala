namespace Utils.GSchema {
    // TODO: Function for `self_settings = new Settings ("org.erikreider.swaysettings");`

    // TODO: create functions for each setting here instead of them being separated.
    // Should be private.
    public static Variant ?get_gsetting (Settings settings,
                                         string name,
                                         VariantType type) {
        // TODO: refactor
        if (!settings.settings_schema.has_key (name)) {
            return null;
        }
        var v_type = settings.settings_schema.get_key (name).get_value_type ();
        if (!v_type.equal (type)) {
            stderr.printf (
                "Get GSettings error:" +
                " Get value type \"%s\" not equal to gsettings type \"%s\"\n",
                type, v_type);
            return null;
        }
        return settings.get_value (name);
    }

    // TODO: create functions for each setting here instead of them being separated.
    // Should be private.
    public static string ?set_gsetting (Settings settings,
                                        string name,
                                        Variant value) {
        // TODO: refactor
        if (!settings.settings_schema.has_key (name)) {
            stderr.printf ("GSchema key \"%s\" not found!\n", name);
            return null;
        }

        var v_type = settings.settings_schema.get_key (name).get_value_type ();
        if (!v_type.equal (value.get_type ())) {
            stderr.printf ("Set GSettings error: Set value type not equal to gsettings type\n");
            return null;
        }

        switch (value.get_type_string ()) {
            case "i":
                int32 val = value.get_int32 ();
                settings.set_int (name, val);
                return val.to_string ();
            case "b":
                bool val = value.get_boolean ();
                settings.set_boolean (name, val);
                return val.to_string ();
            case "s":
                string val = value.get_string ();
                settings.set_string (name, val);
                return val;
            case "as":
                string[] val = value.get_strv ();
                settings.set_strv (name, val);
                return string.joinv (", ", val);
        }
        return null;
    }

    public static GDesktop.AccentColor get_accent_color (Settings ?settings) {
        GDesktop.AccentColor color = GDesktop.AccentColor.BLUE;
        if (settings != null) {
            SettingsSchema schema = settings.settings_schema;
            if (schema != null && schema.has_key ("accent-color")
                // TODO: Check this
                && schema.get_key ("accent-color").get_value_type () == VariantType.INT32) {
                color = (GDesktop.AccentColor) settings.get_enum ("accent-color");
            }
        }
        return color;
    }
}
