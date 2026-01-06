executable(
  'swaysettings-locker',
  files(
    './pam_helper.c',
    './pam_helper.vala',
    './Locker.vala',
    './LockerWindow.vala',
  )
  + swaysettings_sources
  + shared_files,
  vala_args: ['--target-glib=2.50'],
  dependencies: [
    libraries['accounts_service'],
    dep_gtk4,
    dep_gdk_pixbuf,
    dep_libadwaita,
    dep_gtk4_layer_shell,
    dep_glycin,
    dep_glycin_gtk4,
    cc.find_library('pam'),
  ]
  + shared_deps,
  install: true,
)
