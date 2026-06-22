swaysettings_settings_sources = files(
  'IPC/IPC.vala',
  'InputSettings/InputSettings.vala',
  'ListItem/ListItem.vala',
  'Page/InputPage.vala',
  'Page/IpcPage.vala',
  'Page/Page.vala',
  'Rfkill/Rfkill.vala',
  'Window/SidebarListItem.vala',
  'Window/Window.vala',
  'main.vala',
)

subdir('Widgets')
subdir('Pages')

executable(
  'swaysettings',
  [
    swaysettings_sources,
    swaysettings_settings_sources,
    shared_files,
    utils['wallpaper']['files'],
    utils['widgets']['files'],
    utils['gschema']['files'],
    utils['fs']['files'],
    utils['dbus']['files'],
    utils['vala']['files'],
  ],
  # TODO: --pkg=linux needed??
  vala_args: ['--pkg=linux'],
  dependencies: [
    shared_deps,
    libraries['upower'],
    libraries['accounts_service'],
    utils['wallpaper']['dependencies'],
    utils['widgets']['dependencies'],
    utils['gschema']['dependencies'],
    utils['fs']['dependencies'],
    utils['dbus']['dependencies'],
    utils['vala']['dependencies'],

    dep_gtk4,
    dep_gdk_pixbuf,
    dep_libadwaita,
    dep_json_glib,
    dep_libxml,
    dep_udisks2,
    dep_libgtop,
    dep_libpulse,
    dep_libpulse_mainloop_glib,
    dep_glycin,
    dep_glycin_gtk4,
  ],
  install: true,
)
