swaysettings_sources = [
  'main.vala',
  'Widgets/ThumbnailImage/ThumbnailImage.vala',
  'Widgets/OrderListSelector/OrderListSelector.vala',
  'Widgets/KeyboardInputSelector/KeyboardInputSelector.vala',
  'IPC/IPC.vala',
  'Rfkill/Rfkill.vala',
  'Strings.vala',
  'List_Item/List_Item.vala',
  'Functions/Functions.vala',
  'Window/Window.vala',
  'Page/Page.vala',
  'Page/Input_Page.vala',
  'Item/Item.vala',
  'InputSettings/Input_Settings.vala',
  'Pages/Background/Background_Page.vala',
  'Pages/Bluetooth/Bluetooth_Page.vala',
  'Pages/Bluetooth/Bluetooth_Device_Row.vala',
  'Pages/Bluetooth/Bluez/Bluez_Pair_Dialog.vala',
  'Pages/Bluetooth/Bluez/Bluez_Daemon.vala',
  'Pages/Bluetooth/Bluez/Bluez_Adapter.vala',
  'Pages/Bluetooth/Bluez/Bluez_Device.vala',
  'Pages/Bluetooth/Bluez/Bluez_Agent.vala',
  'Pages/Themes/ThemesPage.vala',
  'Pages/Themes/ThemePreviewItem.vala',
  'Pages/KeyboardPage/Keyboard_Page.vala',
  'Pages/MousePage/Mouse_Page.vala',
  'Pages/TrackpadPage/Trackpad_Page.vala',
  'Pages/DefaultApps/Default_Apps.vala',
  'Pages/StartupApps/Startup_Apps.vala',
  'Pages/Swaync/Swaync.vala',
  'Pages/Users/Users.vala',
]

swaysettings_deps = [
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('libhandy-1', version: '>= 1.0.0'),
  dependency('json-glib-1.0'),
  dependency('gee-0.8'),
  dependency('granite'),
  dependency('libxml-2.0'),
  dependency('accountsservice'),
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
  'sway-autostart',
  ['auto_start.vala'],
  vala_args: '--target-glib=2.50',
  dependencies: swaysettings_deps,
  install: true,
)
