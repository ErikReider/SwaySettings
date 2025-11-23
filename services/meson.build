# Systemd service unit
if dep_systemd.found()
  systemd_service_install_dir = dep_systemd.get_variable(pkgconfig: 'systemduserunitdir')
else
  systemd_service_install_dir = join_paths(get_option('libdir'), 'systemd', 'user')
endif

conf_data = configuration_data()
conf_data.set('bindir', join_paths(get_option('prefix'), get_option('bindir')))
configure_file(
  configuration: conf_data,
  input: 'systemd/sway-wallpaper.service.in',
  output: '@BASENAME@',
  install_dir: systemd_service_install_dir,
)
configure_file(
  configuration: conf_data,
  input: 'systemd/swaysettings-upower-monitor.service.in',
  output: '@BASENAME@',
  install_dir: systemd_service_install_dir,
)
