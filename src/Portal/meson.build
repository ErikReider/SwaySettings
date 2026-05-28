services = []

subdir('Services')

executable(
  'xdg-desktop-portal-swaysettings',
  [
    files(
      'BaseService.vala',
      'Portal.vala',
    ),
    services,

    shared_files,
    utils['wallpaper']['files'],
    utils['widgets']['files'],
  ],
  dependencies: [
    shared_deps,
    utils['wallpaper']['dependencies'],
    utils['widgets']['dependencies'],

    dep_gtk4,
    dep_gdk_pixbuf,
    dep_libadwaita,
    dep_gtk4_layer_shell,
  ],
  install: true,
  install_dir: get_option('libexecdir'),
)
