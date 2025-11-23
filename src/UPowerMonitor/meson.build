executable(
  'swaysettings-upower-monitor',
  files(
    'UPowerMonitor.vala',
    'UPowerMonitorDevice.vala',
    join_paths(meson.current_source_dir(), '..', 'PowerBatteryState.vala'),
    join_paths(meson.current_source_dir(), '..', 'PPD.vala'),
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
