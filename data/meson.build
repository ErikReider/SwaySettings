datadir = get_option('datadir')
gnome = import('gnome')

desktop_file = i18n.merge_file(
  input: 'org.erikreider.swaysettings.desktop.in',
  output: 'org.erikreider.swaysettings.desktop',
  type: 'desktop',
  po_dir: '../po',
  install: true,
  install_dir: join_paths(datadir, 'applications'),
)

desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
  test('Validate desktop file', desktop_utils, args: [desktop_file])
endif

appstream_file = i18n.merge_file(
  input: 'org.erikreider.swaysettings.appdata.xml.in',
  output: 'org.erikreider.swaysettings.appdata.xml',
  po_dir: '../po',
  install: true,
  install_dir: join_paths(datadir, 'appdata'),
)

appstream_util = find_program('appstream-util', required: false)
if appstream_util.found()
  test(
    'Validate appstream file',
    appstream_util,
    args: ['validate', appstream_file],
  )
endif

style_files = []
subdir('style')

# GSchema
compile_schemas = find_program('glib-compile-schemas', required: true)
install_data(
  'org.erikreider.swaysettings.gschema.xml',
  install_dir: join_paths(datadir, 'glib-2.0/schemas'),
)

test(
  'Validate schema file',
  compile_schemas,
  args: ['--strict', '--dry-run', meson.current_source_dir()],
)
if get_option('buildtype') != 'release'
  swaysettings_sources += custom_target(
    'gschemas',
    input: 'org.erikreider.swaysettings.gschema.xml',
    output: 'gschemas.compiled',
    command: [
      compile_schemas,
      '--strict', meson.current_source_dir(),
    ],
  )
  dev_env.set('GSETTINGS_SCHEMA_DIR', meson.current_source_dir())
endif

# Icons
subdir('icons')

# GResources
blueprints = custom_target(
  'blueprints',
  input: files(run_command('find', '.', '-name', '*.blp').stdout().strip().split('\n')),
  output: '.',
  command: [
    find_program('blueprint-compiler', required: true),
    'batch-compile',
    '@OUTPUT@',
    '@CURRENT_SOURCE_DIR@',
    '@INPUT@',
  ],
  build_always_stale: true,
  build_by_default: true,
)

swaysettings_sources += gnome.compile_resources(
  'swaysettings-resources',
  'swaysettings.gresource.xml',
  dependencies: [style_files, blueprints],
  c_name: 'sway_settings',
)

# Portal
prefix = get_option('prefix')
conf_data = configuration_data()
conf_data.set('LIBEXECDIR', prefix / get_option('libexecdir'))

install_data(
  'swaysettings.portal',
  install_dir: datadir / 'xdg-desktop-portal' / 'portals',
)

configure_file(
  input: 'org.freedesktop.impl.portal.desktop.swaysettings.service.in',
  output: '@BASENAME@',
  configuration: conf_data,
  install: true,
  install_dir: datadir / 'dbus-1' / 'services',
)

systemduserunitdir = get_option('systemduserunitdir')
if systemduserunitdir == ''
  systemduserunitdir = dep_systemd.get_variable(
    'systemduserunitdir',
    pkgconfig_define: ['prefix', prefix],
  )
endif

configure_file(
  input: 'xdg-desktop-portal-swaysettings.service.in',
  output: '@BASENAME@',
  configuration: conf_data,
  install: true,
  install_dir: systemduserunitdir,
)
