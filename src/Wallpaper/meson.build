executable(
  'sway-wallpaper',
  [
    'Wallpaper.vala',
    'Window.vala',
  ],
  vala_args: [
    '--target-glib=2.50',
    '--pkg=GtkLayerShell-0.1',
  ],
  dependencies: [
    dep_gtk3,
    dep_gdk_pixbuf,
    dep_cairo,
    dep_gtk_layer_shell,
  ],
  install: true,
)
