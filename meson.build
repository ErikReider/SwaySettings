project(
  'SwaySettings',
  ['c', 'vala'],
  version: '0.5.0',
  meson_version: '>= 0.60.0',
  default_options: [ 'warning_level=2',],
)

fs = import('fs')

dev_env = environment()

add_project_arguments(['-w'], language: 'c')
add_project_arguments(
    ['--vapidir', join_paths(meson.current_source_dir(), 'vapi')],
    language: 'vala'
)
if get_option('buildtype') != 'release'
  add_project_arguments('-D', 'DEBUG', language: 'vala')
endif

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')

i18n = import('i18n')

swaysettings_sources = []

dep_systemd = dependency('systemd')

subdir('services')

subdir('data')
subdir('src')
subdir('po')

meson.add_devenv(dev_env)

install_data(
  'pam/swaysettings-locker',
  install_dir : get_option('sysconfdir') / 'pam.d',
)

meson.add_install_script('build-aux/meson/postinstall.py')
