public const string GRIM_FILE_FORMAT = "png";

public static Gdk.Texture ? grim_screenshot_rect (Graphene.Rect rect) {
    try {
        // Create a subprocess to run `grim -` (output PNG to stdout)
        string[] cmd = {
            "grim",
            "-t", GRIM_FILE_FORMAT,
            "-g", "%i,%i %ix%i".printf (
                (int) rect.get_x (),
                (int) rect.get_y (),
                (int) rect.get_width (),
                (int) rect.get_height ()),
            "-",
        };
        Subprocess subprocess = new Subprocess.newv (
            cmd,
            SubprocessFlags.STDOUT_PIPE);

        // Read the standard output (image data)
        DataInputStream input_stream = new DataInputStream (subprocess.get_stdout_pipe ());
        Gly.Image image = new Gly.Loader.for_stream (input_stream).load ();
        return GlyGtk4.frame_get_texture (image.next_frame ());
    } catch (Error e) {
        stderr.printf ("Error: %s\n", e.message);
        return null;
    }
}
