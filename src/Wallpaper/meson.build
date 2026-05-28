executable(
  'sway-wallpaper',
  [
    files(
      'Wallpaper.vala',
      'WallpaperWindow.vala',
    ),
    shared_files,
    utils['wallpaper']['files'],
    utils['widgets']['files'],
  ],
  dependencies: [
    dep_gtk4,
    dep_gdk_pixbuf,
    dep_libadwaita,
    dep_gtk4_layer_shell,
    dep_glycin,
    dep_glycin_gtk4,

    shared_deps,
    utils['wallpaper']['dependencies'],
    utils['widgets']['dependencies'],
  ],
  install: true,
)
