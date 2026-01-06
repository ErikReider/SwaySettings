executable(
  'swaysettings-upower-monitor',
  files(
    'UPowerMonitor.vala',
    'UPowerMonitorDevice.vala',
  )
  + swaysettings_sources
  + shared_files,
  vala_args: ['--target-glib=2.50'],
  dependencies: [
    libraries['upower'],
    dep_libadwaita,
    dep_libnotify,
  ]
  + shared_deps,
  install: true,
)
