public class BaseService : Object {
    unowned DBusConnection conn;

    public BaseService (DBusConnection conn) {
        this.conn = conn;

        debug ("Started Portal: %s", get_class ().get_name ());
    }
}
