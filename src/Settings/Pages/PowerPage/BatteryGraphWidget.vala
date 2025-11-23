namespace SwaySettings {
    private class GraphBar : Gtk.Widget {
        public uint n_items { get; private set; default = 0; }

        private List<Up.HistoryItem> items = new List<Up.HistoryItem> ();
        private double average = 0.0;
        private double sum = 0;
        private double max = double.MIN;
        private double min = double.MAX;

        private int states[Up.DeviceState.LAST] = {};

        static construct {
            set_css_name ("graphbar");
        }

        construct {
            for (uint i = 0; i < states.length; i++) {
                states[i] = 0;
            }

            set_has_tooltip (true);
            query_tooltip.connect (get_tooltip);
        }

        private bool get_tooltip (int x, int y, bool keyboard_tooltip, Gtk.Tooltip tooltip) {
            if (n_items == 0) {
                return false;
            }

            Up.DeviceState state;
            double value = get_value (out state);
            string text = "%s: %0.0lf%%".printf (
                Power.PowerBatteryState.get_battery_state (state),
                value);
            tooltip.set_text (text);
            return true;
        }

        public double get_value (out Up.DeviceState state) {
            if (n_items == 0) {
                state = Up.DeviceState.UNKNOWN;
                return -1;
            }

            state = (Up.DeviceState) items.first ().data.state;
            if (state == Up.DeviceState.PENDING_CHARGE) {
                // Currently Pending charge
                return max;
            }
            uint state_count = 1;
            for (uint i = 0; i < states.length; i++) {
                int value = states[i];
                if (value > state_count) {
                    state_count = value;
                    state = (Up.DeviceState) i;
                } else if (value == state_count && i > state) {
                    // If there are multiple items with the state, prioritize
                    // through the enum integer value (larger = higher priority)
                    state_count = value;
                    state = (Up.DeviceState) i;
                }
            }

            double value = average;
            switch (state) {
                case Up.DeviceState.FULLY_CHARGED:
                case Up.DeviceState.PENDING_CHARGE:
                    value = max;
                    break;
                case Up.DeviceState.EMPTY:
                    value = min;
                    break;
                case Up.DeviceState.UNKNOWN:
                case Up.DeviceState.CHARGING:
                case Up.DeviceState.DISCHARGING:
                case Up.DeviceState.PENDING_DISCHARGE:
                    break;
                case Up.DeviceState.LAST:
                    return -1;
            }

            return value;
        }

        public void append (Up.HistoryItem item) {
            if (item.state == Up.DeviceState.LAST) {
                warning ("Tried adding HistoryItem with state LAST");
                return;
            }

            items.append (item);
            n_items++;

            double value = item.value;
            sum += value;
            average = sum / n_items;

            max = double.max (max, value);
            min = double.min (min, value);

            states[item.state]++;

            // TODO: Parse these values from the UPower configuration file?
            if (average <= 10) {
                css_classes = { "critical" };
            } else if (average <= 25) {
                css_classes = { "low" };
            } else {
                css_classes = { "normal" };
            }
        }

        public void clear () {
            while (!items.is_empty ()) {
                items.delete_link (items.nth (0));
            }
            warn_if_fail (items.is_empty ());
            n_items = 0;

            css_classes = {};

            for (uint i = 0; i < states.length; i++) {
                states[i] = 0;
            }

            average = 0;
            max = double.MIN;
            min = double.MAX;
            sum = 0;
        }

        protected override Gtk.SizeRequestMode get_request_mode () {
            return Gtk.SizeRequestMode.CONSTANT_SIZE;
        }
    }

    private class BatteryGraphWidget : Gtk.Widget {
        const uint NUM_COLS = 5;
        const uint NUM_ROWS = 4;
        const uint DATA_POINT_PER_HOUR = 4;
        // One bar per hour
        const uint NUM_BARS = 24;
        const uint BARS_PER_COL = NUM_BARS / (NUM_COLS - 1);

        const int BORDER_WIDTH = 2;
        const int BORDER_HEIGHT = 10;

        private string ?device_obj_path = null;
        private Cancellable history_cancellable = new Cancellable ();

        private Gtk.Label time_labels[NUM_COLS] = {};
        private Gtk.Label percent_labels[NUM_ROWS] = {};
        private GraphBar bars[NUM_BARS] = {};
        private List<unowned Gtk.Widget> widgets = new List<unowned Gtk.Widget> ();

        private double bar_values[NUM_BARS] = {};

        private Graphene.Rect bars_bounds = Graphene.Rect.zero ();
        private Graphene.Rect lines_bounds = Graphene.Rect.zero ();
        private float[] h_lines_points = {};
        private float[] v_lines_points = {};

        static construct {
            set_css_name ("batterygraphwidget");
        }

        construct {
            height_request = 250;

            for (uint i = 0; i < bars.length; i++) {
                bars[i] = new GraphBar ();
                bars[i].set_parent (this);
                widgets.append (bars[i]);
            }

            for (uint i = 0; i < time_labels.length; i++) {
                string text = (i * (24 / (NUM_COLS - 1)) % 24).to_string ("%02u:00");
                Gtk.Label label = new Gtk.Label (text) {
                    width_chars = 6,
                };
                label.set_parent (this);
                time_labels[i] = label;
                widgets.append (label);
            }

            for (uint i = 0; i < percent_labels.length; i++) {
                string text = (100 - (100 / NUM_ROWS * i)).to_string ("%i%%");
                Gtk.Label label = new Gtk.Label (text) {
                    sensitive = false,
                    width_chars = 4,
                    xalign = 0,
                };
                label.set_parent (this);
                percent_labels[i] = label;
                widgets.append (label);
            }
        }

        public async void init (Up.Device device) {
            if (device_obj_path != null
                && device_obj_path == device.get_object_path ()) {
                return;
            }
            device_obj_path = device.get_object_path ();

            load_history (device);
            queue_allocate ();
        }

        private void load_history (Up.Device device) {
            for (size_t i = 0; i < bars.length; i++) {
                bars[i].clear ();
            }

            if (device == null || !device.has_history) {
                return;
            }

            history_cancellable.cancel ();
            history_cancellable.reset ();

            // Get data since 00:00 this morning
            DateTime now = new DateTime.now_local ();
            DateTime start_of_day = new DateTime.local (now.get_year (),
                                                        now.get_month (),
                                                        now.get_day_of_month (),
                                                        0, 0, 0);
            int64 diff_seconds = now.to_unix () - start_of_day.to_unix ();
            if (diff_seconds <= 0) {
                return;
            }

            // Number of data points
            // uint resolution = (now.get_hour () + 1) * DATA_POINT_PER_HOUR;
            uint resolution = 24 * DATA_POINT_PER_HOUR;

            GenericArray<Up.HistoryItem> device_history;
            try {
                device_history = device.get_history_sync (
                    "charge", (uint) diff_seconds, resolution, history_cancellable);
            } catch (Error e) {
                critical (e.message);
                return;
            }

            if (history_cancellable.is_cancelled ()) {
                return;
            }

            for (size_t i = 0; i < bars.length; i++) {
                bars[i].clear ();
            }
            foreach (var h in device_history) {
                DateTime date = new DateTime.from_unix_local (h.time);
                if (date.get_day_of_month () != now.get_day_of_month ()) {
                    continue;
                }
                size_t index = date.get_hour () % NUM_BARS;
                bars[index].append (h);
            }

            // Estimate the value of unknown values with a simple linear equation
            bar_values = {};
            int head = -1;
            int tail = -1;
            for (int i = 0; i < bars.length; i++) {
                double value = bars[i].get_value (null);
                if (value >= 0) {
                    bar_values[i] = value;
                    head = i;
                    continue;
                }

                if (tail < 0) {
                    // Find the next valid data point
                    for (int j = i + 1; j < bars.length; j++) {
                        double v = bars[j].get_value (null);
                        if (v >= 0) {
                            bar_values[j] = value;
                            tail = j;
                            break;
                        }
                    }
                }

                if (head >= 0 && tail >= 0) {
                    double end_value = bars[tail].get_value (null);
                    double start_value = bars[head].get_value (null);
                    double m = (end_value - start_value) / (tail - head);
                    double b = start_value - m * head;

                    for (int j = i; j < tail; j++) {
                        bar_values[j] = m * j + b;
                    }
                    i = tail - 1;
                } else if (tail >= 0) {
                    // Start of loop, no valid previous values
                    double end_value = bars[tail].get_value (null);
                    for (int j = 0; j <= tail; j++) {
                        bar_values[j] = end_value;
                    }
                    i = tail;
                } else {
                    // No future values
                    for (int j = i; j < bars.length; j++) {
                        bar_values[j] = -1;
                    }
                    break;
                }
                head = -1;
                tail = -1;
            }
        }

        private void measure_widget (Gtk.Widget widget, out int width, out int height) {
            widget.measure (Gtk.Orientation.HORIZONTAL, -1,
                            null, out width, null, null);
            widget.measure (Gtk.Orientation.VERTICAL, -1,
                            null, out height, null, null);
        }

        protected override Gtk.SizeRequestMode get_request_mode () {
            return Gtk.SizeRequestMode.CONSTANT_SIZE;
        }

        protected override void size_allocate (int width, int height, int baseline) {
            base.size_allocate (width, height, baseline);

            // Calculate labels sizes
            // (assume all labels of the same type are the same size)

            // Max height for X time labels
            int time_width, time_height;
            measure_widget (time_labels[0], out time_width, out time_height);
            // Max width for Y percent labels
            int percent_width, percent_height;
            measure_widget (percent_labels[0], out percent_width, out percent_height);

            bars_bounds = Graphene.Rect ().init (
                time_width / 2,
                percent_height / 2,
                width - percent_width - time_width / 2 - BORDER_HEIGHT,
                height - percent_height / 2 - time_height - BORDER_WIDTH
            );
            // Same as bars bounds, but extends down to the time labels
            lines_bounds = bars_bounds;
            // lines_bounds.size.height += BORDER_HEIGHT + BORDER_WIDTH;
            lines_bounds.size.width += BORDER_HEIGHT;

            v_lines_points = {};
            h_lines_points = {};

            // Allocate

            // Percentage
            float row_height = bars_bounds.get_height () / NUM_ROWS;
            for (uint i = 0; i < percent_labels.length; i++) {
                unowned Gtk.Label child = percent_labels[i];
                if (!child.should_layout ()) {
                    continue;
                }
                float y_offset = row_height * i;

                h_lines_points += y_offset + percent_height / 2;

                Gsk.Transform transform = new Gsk.Transform ().translate (
                    Graphene.Point ().init (
                        width - percent_width,
                        y_offset
                    )
                );
                child.allocate (percent_width, percent_height, baseline, transform);
            }

            // Time
            float column_width = bars_bounds.get_width () / (NUM_COLS - 1);
            for (uint i = 0; i < time_labels.length; i++) {
                unowned Gtk.Label child = time_labels[i];
                if (!child.should_layout ()) {
                    continue;
                }
                float x_offset = column_width * i;

                v_lines_points += x_offset + time_width / 2;

                Gsk.Transform transform = new Gsk.Transform ().translate (
                    Graphene.Point ().init (
                        x_offset,
                        height - time_height
                    )
                );
                child.allocate (time_width, time_height, baseline, transform);
            }

            // Bars
            float bar_x_spacing = bars_bounds.get_width () / NUM_BARS;
            int bar_width = (int) ((column_width - BORDER_WIDTH) / BARS_PER_COL);
            for (uint i = 0; i < bars.length; i++) {
                unowned GraphBar bar = bars[i];
                unowned double bar_value = bar_values[i];

                bar.set_visible (bar_value >= 0);
                if (bar_value < 0) {
                    continue;
                }
                float x_offset = bar_x_spacing * i;

                int bar_height;
                measure_widget (bar, null, out bar_height);
                if (bar_value > 0) {
                    bar_height = (int) (bars_bounds.get_height () * (bar_value / 100));
                }

                Gsk.Transform transform = new Gsk.Transform ().translate (
                    Graphene.Point ().init (
                        x_offset + time_width / 2 + BORDER_WIDTH / 2,
                        bars_bounds.get_y () + bars_bounds.get_height () - bar_height
                    )
                );
                bar.allocate (bar_width, bar_height, baseline, transform);
            }
        }

        protected override void snapshot (Gtk.Snapshot snapshot) {
            Gdk.RGBA color = get_color ();

            // Horizontal lines
            foreach (float point in h_lines_points) {
                snapshot.append_color (
                    color,
                    Graphene.Rect ().init (
                        lines_bounds.get_x (),
                        point,
                        lines_bounds.get_width (),
                        BORDER_WIDTH
                    )
                );
            }
            // Vertical lines
            foreach (float point in v_lines_points) {
                snapshot.append_color (
                    color,
                    Graphene.Rect ().init (
                        point,
                        lines_bounds.get_y () + lines_bounds.get_height () - BORDER_HEIGHT,
                        BORDER_WIDTH,
                        BORDER_HEIGHT
                    )
                );
            }

            foreach (unowned Gtk.Widget child in widgets) {
                if (!child.should_layout ()) {
                    continue;
                }
                snapshot_child (child, snapshot);
            }
        }
    }
}
