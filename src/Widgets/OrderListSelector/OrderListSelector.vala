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

        private unowned Update_cb update_callback;

        public delegate void Add_cb (OrderListSelector ols);

        public delegate void Update_cb (ArrayList<StringType> list);

        public OrderListSelector (ArrayList<StringType> list,
                                  Update_cb update_callback,
                                  Add_cb add_callback) {
            this.update_callback = update_callback;
            this.list = list;

            // Activates row on keyboard navigation
            list_box.row_selected.connect ((_, r) => {
                int index = r.get_index ();
                if (r != null && index >= 0) r.activate ();
            });

            list_box.row_activated.connect ((_, row) => {
                selected_index = row.get_index ();
                button_down.sensitive = selected_index + 1 < list.size;
                button_up.sensitive = selected_index > 0;
                button_remove.sensitive = list.size > 1;
            });

            button_add.clicked.connect (() => {
                add_callback (this);
            });

            button_remove.clicked.connect (() => {
                list.remove_at (selected_index);
                if (selected_index == list.size) selected_index -= 1;
                if (selected_index < 0) selected_index = 0;
                update_list ();
                update_callback (list);
            });

            button_up.clicked.connect (() => {
                var item = list.get (selected_index);
                list.remove_at (selected_index);
                list.insert (--selected_index, item);
                update_list ();
                update_callback (list);
            });

            button_down.clicked.connect (() => {
                var item = list.get (selected_index);
                list.remove_at (selected_index);
                list.insert (++selected_index, item);
                update_list ();
                update_callback (list);
            });

            update_list ();
        }

        public void add_row (StringType item) {
            list.add (item);
            selected_index = list.size - 1;
            update_list ();
            update_callback (list);
        }

        void update_list () {
            foreach (var w in list_box.get_children ()) {
                list_box.remove (w);
            }
            for (int i = 0; i < list.size; i++) {
                var item = list[i];
                var row = new Gtk.ListBoxRow ();
                row.add(new Gtk.Label (item.to_string ()));
                list_box.add (row);
                if (selected_index == i) row.activate ();
            }
            this.show_all ();
        }
    }
}
