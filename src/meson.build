swaysettings_sources = [
  'main.vala',
  'constants.vala',
  'Widgets/ThumbnailImage/ThumbnailImage.vala',
  'Widgets/OrderListSelector/OrderListSelector.vala',
  'Widgets/KeyboardInputSelector/KeyboardInputSelector.vala',
  'IPC/IPC.vala',
  'Rfkill/Rfkill.vala',
  'Strings.vala',
  'ListItem/ListItem.vala',
  'Functions/Functions.vala',
  'Window/Window.vala',
  'Page/Page.vala',
  'Page/InputPage.vala',
  'Item/Item.vala',
  'InputSettings/InputSettings.vala',
  'Pages/Background/BackgroundPage.vala',
  'Pages/Bluetooth/BluetoothPage.vala',
  'Pages/Bluetooth/BluetoothDeviceRow.vala',
  'Pages/Bluetooth/Bluez/BluezPairDialog.vala',
  'Pages/Bluetooth/Bluez/BluezDaemon.vala',
  'Pages/Bluetooth/Bluez/BluezAdapter.vala',
  'Pages/Bluetooth/Bluez/BluezDevice.vala',
  'Pages/Bluetooth/Bluez/BluezAgent.vala',
  'Pages/Themes/ThemesPage.vala',
  'Pages/Themes/ThemePreviewItem.vala',
  'Pages/KeyboardPage/KeyboardPage.vala',
  'Pages/MousePage/MousePage.vala',
  'Pages/TrackpadPage/TrackpadPage.vala',
  'Pages/DefaultApps/DefaultApps.vala',
  'Pages/StartupApps/StartupApps.vala',
  'Pages/Swaync/Swaync.vala',
  'Pages/Users/Users.vala',
  'Pages/Pulse/PulsePage.vala',
  'Pages/Pulse/PulseDaemon.vala',
  'Pages/Pulse/PulseDevice.vala',
  'Pages/Pulse/PulseSinkInput.vala',
]

swaysettings_deps = [
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('gdk-3.0'),
  dependency('gdk-pixbuf-2.0'),
  dependency('cairo'),
  dependency('libhandy-1', version: '>= 1.0.0'),
  dependency('json-glib-1.0'),
  dependency('gee-0.8'),
  dependency('granite'),
  dependency('libxml-2.0'),
  dependency('accountsservice'),
  meson.get_compiler('c').find_library('gtk-layer-shell'),
  dependency('libpulse'),
  dependency('libpulse-mainloop-glib'),
]

sysconfdir = get_option('sysconfdir')
gnome = import('gnome')

swaysettings_sources += gnome.compile_resources('swaysettings-resources',
  'swaysettings.gresource.xml',
  c_name: 'sway_settings'
)

executable(
  'swaysettings',
  swaysettings_sources,
  vala_args: [
    '--target-glib=2.50',
    '--pkg=linux'
  ],
  dependencies: swaysettings_deps,
  install: true,
)

executable(
  'sway-wallpaper',
  [
    'Wallpaper/Wallpaper.vala',
    'Wallpaper/Window.vala',
  ],
  vala_args: [
    '--target-glib=2.50',
    '--pkg=GtkLayerShell-0.1',
  ],
  dependencies: swaysettings_deps,
  install: true,
)

executable(
  'sway-autostart',
  ['AutoStart/AutoStart.vala'],
  vala_args: '--target-glib=2.50',
  dependencies: swaysettings_deps,
  install: true,
)
