desktop_file = i18n.merge_file(
  input: 'org.erikreider.swaysettings.desktop.in',
  output: 'org.erikreider.swaysettings.desktop',
  type: 'desktop',
  po_dir: '../po',
  install: true,
  install_dir: join_paths(get_option('datadir'), 'applications')
)

desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
  test('Validate desktop file', desktop_utils,
    args: [desktop_file]
  )
endif

appstream_file = i18n.merge_file(
  input: 'org.erikreider.swaysettings.appdata.xml.in',
  output: 'org.erikreider.swaysettings.appdata.xml',
  po_dir: '../po',
  install: true,
  install_dir: join_paths(get_option('datadir'), 'appdata')
)

appstream_util = find_program('appstream-util', required: false)
if appstream_util.found()
  test('Validate appstream file', appstream_util,
    args: ['validate', appstream_file]
  )
endif

install_data('org.erikreider.swaysettings.gschema.xml',
  install_dir: join_paths(get_option('datadir'), 'glib-2.0/schemas')
)

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test('Validate schema file', compile_schemas,
    args: ['--strict', '--dry-run', meson.current_source_dir()]
  )

  if get_option('use-global-gschema') == false
    run_command(compile_schemas, ['--strict', meson.current_source_dir()])
  else
    add_project_arguments('-D', 'USE_GLOBAL_GSCHEMA', language: 'vala')
  endif
endif

subdir('icons')

gnome = import('gnome')

# GResources
blueprints = custom_target('blueprints',
  input: files(run_command('find', '.', '-name', '*.blp').stdout().strip().split('\n')),
  output: '.',
  command: [
    find_program('blueprint-compiler', required: true),
    'batch-compile',
    '@OUTPUT@', '@CURRENT_SOURCE_DIR@', '@INPUT@'
  ],
  build_always_stale: true,
  build_by_default: true,
)

swaysettings_sources += gnome.compile_resources(
  'swaysettings-resources',
  'swaysettings.gresource.xml',
  dependencies: [ blueprints ],
  c_name: 'sway_settings',
)
