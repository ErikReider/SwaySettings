project(
  'SwaySettings',
  ['c', 'vala'],
  version: '0.5.0',
  meson_version: '>= 1.4',
  default_options: [
    'warning_level=2',
  ],
)

fs = import('fs')
gnome = import('gnome')

dev_env = environment()

add_project_arguments(['-w'], language: 'c')
add_project_arguments(
  ['--vapidir', meson.current_source_dir() / 'vapi'],
  language: 'vala',
)
if get_option('buildtype') != 'release'
  add_project_arguments('-D', 'DEBUG', language: 'vala')
endif

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()), language: 'c')

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
  install_dir: get_option('sysconfdir') / 'pam.d',
)

gnome.post_install(
  gtk_update_icon_cache: true,
  update_desktop_database: true,
  glib_compile_schemas: true,
)
