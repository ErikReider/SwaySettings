swaysettings_sources += files([
  'main.vala',
  'constants.vala',
  'Widgets/ThumbnailImage/ThumbnailImage.vala',
  # 'Widgets/OrderListSelector/OrderListSelector.vala',
  # 'Widgets/KeyboardInputSelector/KeyboardInputSelector.vala',
  'IPC/IPC.vala',
  # 'Rfkill/Rfkill.vala',
  # 'Strings.vala',
  'ListItem/ListItem.vala',
  'Functions/Functions.vala',
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
  swaysettings_sources,
  vala_args: ['--target-glib=2.50', '--pkg=linux'],
  dependencies: [
    dep_glib,
    dep_gio_unix,
    dep_gio,
    dep_gtk4,
    dep_gdk_pixbuf,
    dep_cairo,
    dep_libadwaita,
    dep_json_glib,
    dep_gee,
    dep_granite7,
    dep_libxml,
    dep_accountsservice,
    dep_libpulse,
    dep_libpulse_mainloop_glib,
  ],
  install: true,
)
