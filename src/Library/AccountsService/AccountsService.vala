namespace SwaySettings.AccountsService {
    public class Manager : Object {
        public unowned Act.UserManager user_manager {
            construct;
            get;
        }
        public unowned Act.User current_user {
            construct;
            get;
        }

        private ulong is_loaded_id = 0;
        private ulong changed_id = 0;

        construct {
            user_manager = Act.UserManager.get_default ();
            current_user = user_manager.get_user (Environment.get_user_name ());
        }

        public Manager() {
            is_loaded_id =
                current_user.notify["is-loaded"].connect (() => changed ());
            changed_id = current_user.changed.connect (() => changed ());
        }

        public signal void changed();
    }
}
