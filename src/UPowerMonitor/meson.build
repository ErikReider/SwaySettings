executable(
  'swaysettings-upower-monitor',
  files(
    'UPowerMonitor.vala',
    'UPowerMonitorDevice.vala',
  )
  + swaysettings_sources
  + shared_files,
  dependencies: [
    libraries['upower'],
    dep_libadwaita,
    dep_libnotify,
  ]
  + shared_deps,
  install: true,
)
