project(
  'SwaySettings',
  ['c', 'vala'],
  version: '0.5.0',
  meson_version: '>= 0.60.0',
  default_options: [ 'warning_level=2',],
)

add_project_arguments(
    ['--vapidir', join_paths(meson.current_source_dir(), 'vapi')],
    language: 'vala'
)

i18n = import('i18n')

swaysettings_sources = []

dep_systemd = dependency('systemd')

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
  input: 'services/systemd/sway-wallpaper.service.in',
  output: '@BASENAME@',
  install_dir: systemd_service_install_dir,
)

subdir('data')
subdir('src')
subdir('po')

install_data(
  'pam/swaysettings-locker',
  install_dir : get_option('sysconfdir') / 'pam.d',
)

meson.add_install_script('build-aux/meson/postinstall.py')
