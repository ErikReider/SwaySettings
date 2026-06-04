#include <gdk/gdk.h>
#include <glib.h>
#include <gtk-4.0/gtk/gtk.h>

void utils_widgets_add_style_provider_for_display(GdkDisplay *display,
												  GtkStyleProvider *provider,
												  guint priority) {
	gtk_style_context_add_provider_for_display(display, provider, priority);
}
