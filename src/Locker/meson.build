executable(
  'swaysettings-locker',
  [
    files(
      './Locker.vala',
      './LockerWindow.vala',
      './pam_helper.c',
      './pam_helper.vala',
    ),
    swaysettings_sources,
    shared_files,
    utils['wallpaper']['files'],
    utils['widgets']['files'],
  ],
  dependencies: [
    shared_deps,
    libraries['accounts_service'],
    utils['wallpaper']['dependencies'],
    utils['widgets']['dependencies'],

    dep_gtk4,
    dep_libadwaita,
    dep_gtk4_layer_shell,
    dep_glycin,
    dep_glycin_gtk4,
    cc.find_library('pam'),
  ],
  install: true,
)
