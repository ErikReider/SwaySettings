namespace SwaySettings {
    private class PowerModeRow : Adw.ActionRow {
        public Power.PowerProfiles profile { get; private set; }

        private Gtk.CheckButton check_button;

        public PowerModeRow (string power_profile, Power.PowerProfiles active_profile) {
            this.profile = Power.PowerProfiles.parse (power_profile);

            this.activatable = false;
            this.selectable = false;


            title = profile.get_title ();
            subtitle = profile.get_subtitle ();

            check_button = new Gtk.CheckButton ();
            check_button.active = active_profile == profile;
            add_prefix (check_button);
            activatable_widget = check_button;
        }

        public void set_check_button_group (PowerModeRow ?row) {
            this.check_button.set_group (row?.check_button);
        }
    }
}
