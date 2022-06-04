public int main () {
    try {
        string autostart_path = Path.build_path (
            Path.DIR_SEPARATOR_S,
            Environment.get_user_config_dir (),
            "autostart");
        var directory = File.new_for_path (autostart_path);
        if (!directory.query_exists ()) {
            stderr.printf ("ERROR: Couldn't find path %s\n",
                           autostart_path);
            return 1;
        }
        var enume = directory.enumerate_children (
            FileAttribute.STANDARD_NAME, 0);
        FileInfo file_prop = null;
        while ((file_prop = enume.next_file ()) != null) {
            string file_path = Path.build_path (Path.DIR_SEPARATOR_S,
                                                autostart_path,
                                                file_prop.get_name ());
            DesktopAppInfo app = new DesktopAppInfo.from_filename (file_path);
            if (app == null || app.get_is_hidden ()) continue;
            app.launch (null, new AppLaunchContext ());
        }
    } catch (Error e) {
        stderr.printf ("ERROR: %s\n", e.message);
        return 1;
    }
    return 0;
}
