executable(
  'sway-wallpaper',
  files([
    'Wallpaper.vala',
    'WallpaperWindow.vala',
  ]) + shared_files,
  vala_args: [
    '--target-glib=2.50'
  ],
  dependencies: [
    dep_gtk4,
    dep_gdk_pixbuf,
    dep_libadwaita,
    dep_gtk4_layer_shell,
  ]
  + shared_deps,
  install: true,
)
