namespace Utils.Fs {
    public delegate void Delegate_walk_func (FileInfo file_info, File file);

    public static int walk_through_dir (string path, Delegate_walk_func func) {
        try {
            var directory = File.new_for_path (path);
            if (!directory.query_exists ()) {
                return 1;
            }

            string[] attributes = {
                FileAttribute.STANDARD_NAME,
                FileAttribute.STANDARD_TYPE,
                FileAttribute.STANDARD_IS_BACKUP,
                FileAttribute.STANDARD_IS_SYMLINK,
                FileAttribute.STANDARD_IS_HIDDEN,
            };
            var enumerator = directory.enumerate_children (
                string.joinv (",", attributes), 0);
            FileInfo file_prop;
            while ((file_prop = enumerator.next_file ()) != null) {
                func (file_prop, directory);
            }
        } catch (Error e) {
            print ("Error: %s\n", e.message);
            return 1;
        }
        return 0;
    }

    public static bool extract_symlink (ref string path) {
        bool is_symlink = false;
        // TODO: Max depth
        while (FileUtils.test (path, FileTest.IS_SYMLINK)) {
            try {
                path = FileUtils.read_link (path);
                is_symlink = true;
            } catch (Error e) {
                warning ("Could not read link for path: %s", path);
                break;
            }
        }
        return is_symlink;
    }
}
