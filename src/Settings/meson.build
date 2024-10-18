swaysettings_sources += files([
  'main.vala',
  'Widgets/StorageRow/StorageRow.vala',
  'Widgets/ThumbnailImage/ThumbnailImage.vala',
  # 'Widgets/OrderListSelector/OrderListSelector.vala',
  # 'Widgets/KeyboardInputSelector/KeyboardInputSelector.vala',
  'IPC/IPC.vala',
  'Rfkill/Rfkill.vala',
  'ListItem/ListItem.vala',
  'Window/Window.vala',
  'Window/SidebarListItem.vala',
  'Page/Page.vala',
  # 'Page/InputPage.vala',
  'UserMgr/UserMgr.vala',
  # 'InputSettings/InputSettings.vala',
])

subdir('Pages')

executable(
  'swaysettings',
  swaysettings_sources + shared_files,
  vala_args: ['--target-glib=2.50', '--pkg=linux'],
  dependencies: [
    dep_glib,
    dep_gio_unix,
    dep_gio,
    dep_gtk4,
    dep_gdk_pixbuf,
    dep_libadwaita,
    dep_json_glib,
    dep_gee,
    dep_granite7,
    dep_libxml,
    dep_accountsservice,
    dep_udisks2,
    dep_libgtop,
    dep_libpulse,
    dep_libpulse_mainloop_glib,
    dep_math,
  ],
  install: true,
)
