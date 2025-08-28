services = []

subdir('Services')

executable(
  'xdg-desktop-portal-swaysettings',
  files(
    'BaseService.vala',
    'Portal.vala',
  )
  + services
  + shared_files,
  vala_args: ['--target-glib=2.50'],
  dependencies: [
    dep_gtk4,
    dep_gdk_pixbuf,
    dep_libadwaita,
    dep_gtk4_layer_shell,
  ]
  + shared_deps,
  install: true,
  install_dir: get_option('libexecdir'),
)
