namespace Utils.DBusHelper {
    private delegate Type TypeFunc ();

    /** https://gitlab.gnome.org/GNOME/vala/-/issues/412 */
    public static Type get_proxy_gtype<T> () {
        Quark proxy_quark = Quark.from_string ("vala-dbus-proxy-type");
        return ((TypeFunc) (typeof (T).get_qdata (proxy_quark)))();
    }
}
