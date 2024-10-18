[CCode (cprefix = "glibtop_", lower_case_cprefix = "glibtop_")]
namespace GLibTop {
    [CCode (cheader_filename = "glibtop.h", cname = "glibtop_get_mem")]
    public static void get_mem (out mem buf);

    [CCode (cheader_filename = "glibtop.h", cname = "glibtop_get_sysinfo")]
    public static unowned sysinfo? get_sysinfo ();

    [CCode (cheader_filename = "glibtop/mem.h", destroy_function = "")]
    public struct mem {
        public uint64 flags;
        public uint64 total;
        public uint64 used;
        public uint64 free;
        public uint64 shared;
        public uint64 buffer;
        public uint64 cached;
        public uint64 user;
        public uint64 locked;
    }

    [CCode (cheader_filename = "glibtop/sysinfo.h", destroy_function = "")]
    public struct entry {
        public GLib.GenericArray labels;
        public GLib.HashTable values;
        public GLib.HashTable descriptions;
    }

    [CCode (cheader_filename = "glibtop/sysinfo.h", destroy_function = "")]
    public struct sysinfo {
        public uint64 flags;
        public uint64 ncpu;
        [CCode (array_length = false)]
        public unowned entry[] cpuinfo;
    }
}
