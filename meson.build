project(
  'SwaySettings',
  ['c', 'vala'],
  version: '0.1.0',
  meson_version: '>= 0.50.0',
  default_options: [ 'warning_level=2',],
)

i18n = import('i18n')

add_project_arguments(
    ['--vapidir', join_paths(meson.current_source_dir(), 'vapi')],
    language: 'vala'
)

subdir('data')
subdir('src')

meson.add_install_script('build-aux/meson/postinstall.py')
