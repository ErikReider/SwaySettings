using Gee;

namespace SwaySettings {
    public abstract class StringType {
        public abstract string to_string ();
    }

    [GtkTemplate (ui = "/org/erikreider/swaysettings/Widgets/OrderListSelector/OrderListSelector.ui")]
    public class OrderListSelector : Gtk.Box {
        [GtkChild]
        unowned Gtk.ListBox list_box;

        [GtkChild]
        unowned Gtk.Button button_add;
        [GtkChild]
        unowned Gtk.Button button_remove;
        [GtkChild]
        unowned Gtk.Button button_up;
        [GtkChild]
        unowned Gtk.Button button_down;

        public ArrayList<StringType> list;
        public int selected_index = 0;

        public delegate void update_cb (ArrayList<StringType> list);

        public OrderListSelector (ArrayList<StringType> list,
                                  update_cb callback) {
            this.list = list;

            list_box.row_activated.connect ((_, row) => {
                selected_index = row.get_index ();
                button_down.sensitive = selected_index + 1 < list.size;
                button_up.sensitive = selected_index > 0;
                button_remove.sensitive = list.size > 1;
            });

            button_remove.clicked.connect (() => {
                list.remove_at (selected_index);
                if (selected_index == list.size) selected_index -= 1;
                if (selected_index < 0) selected_index = 0;
                update_list ();
                callback (list);
            });

            button_up.clicked.connect (() => {
                var item = list.get (selected_index);
                list.remove_at (selected_index);
                list.insert (--selected_index, item);
                update_list ();
                callback (list);
            });

            button_down.clicked.connect (() => {
                var item = list.get (selected_index);
                list.remove_at (selected_index);
                list.insert (++selected_index, item);
                update_list ();
                callback (list);
            });

            update_list ();
        }

        void update_list () {
            foreach (var w in list_box.get_children ()) {
                list_box.remove (w);
            }
            for (int i = 0; i < list.size; i++) {
                var item = list[i];
                var row = new OrderListSelectorRow (item);
                list_box.add (row);
                if (selected_index == i) row.activate ();
            }
            this.show_all ();
        }
    }

    private class OrderListSelectorRow : Gtk.ListBoxRow {

        public StringType child_value;

        public OrderListSelectorRow (StringType child_value) {
            this.child_value = child_value;
            this.add (new Gtk.Label (child_value.to_string ()));
        }
    }
}