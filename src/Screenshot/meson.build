executable(
  'swaysettings-screenshot',
  files(
    'Grim.vala',
    'Screenshot.vala',
    'ScreenshotWindow.vala',
    'ScreenshotGrid.vala',
    'ScreenshotPreview.vala',
  )
  + swaysettings_sources
  + shared_files,
  vala_args: ['--target-glib=2.50'],
  dependencies: [
    dep_gtk4,
    dep_gdk_pixbuf,
    dep_libadwaita,
    dep_gtk4_layer_shell,
    dep_gee,
    dep_gsettings_schemas,
    dep_math,
  ],
  install: true,
  install_dir: get_option('libexecdir'),
)
