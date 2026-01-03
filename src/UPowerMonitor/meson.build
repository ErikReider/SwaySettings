executable(
  'swaysettings-upower-monitor',
  files(
    'UPowerMonitor.vala',
    'UPowerMonitorDevice.vala',
    join_paths(src_dir, 'Power.vala'),
  )
  + swaysettings_sources
  + shared_files,
  vala_args: ['--target-glib=2.50'],
  dependencies: [
    dep_libadwaita,
    dep_upower_glib,
    dep_libnotify,
  ]
  + shared_deps,
  install: true,
)
