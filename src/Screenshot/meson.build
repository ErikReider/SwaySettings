executable(
  'swaysettings-screenshot',
  [
    files(
      'Grim.vala',
      'Screenshot.vala',
      'ScreenshotGrid.vala',
      'ScreenshotList.vala',
      'ScreenshotPreview.vala',
      'ScreenshotWindow.vala',
    ),
    swaysettings_sources,
    shared_files,
    utils['gschema']['files'],
    utils['widgets']['files'],
  ],
  dependencies: [
    shared_deps,
    utils['gschema']['dependencies'],
    utils['widgets']['dependencies'],

    dep_gtk4,
    dep_gdk_pixbuf,
    dep_libadwaita,
    dep_gtk4_layer_shell,
    dep_glycin,
    dep_glycin_gtk4,
  ],
  install: true,
)
