swaysettings_sources = [
  'main.vala',
  'Strings.vala',
  'List_Item/List_Item.vala',
  'Functions/Functions.vala',
  'Window/Window.vala',
  'Page/Page.vala',
  'Item/Item.vala',
  'Pages/Appearance/Appearance.vala',
  'Pages/Appearance/BackgroundWidget.vala',
  'Pages/Appearance/ThemesWidget.vala',
  'Pages/Mouse/Mouse.vala',
  'Pages/Mouse/Input_Settings.vala',
  'Pages/Mouse/Mouse_Page.vala',
  'Pages/Mouse/Trackpad_Page.vala',
  'Pages/Apps/Apps.vala',
  'Pages/Apps/Default_Apps.vala',
  'Pages/Apps/Startup_Apps.vala',
  'Pages/Keybindings/Keybindings_Page.vala',
  'Pages/Keybindings/Keybind_Action.vala',
  'Pages/Keybindings/Keybind_Variable.vala',
]

swaysettings_deps = [
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('libhandy-1', version: '>= 1.0.0'),
  dependency('json-glib-1.0'),
  dependency('gee-0.8'),
  dependency('granite'),
  meson.get_compiler('vala').find_library('posix'),
]

gnome = import('gnome')

swaysettings_sources += gnome.compile_resources('swaysettings-resources',
  'swaysettings.gresource.xml',
  c_name: 'sway_settings'
)

executable(
  'swaysettings',
  swaysettings_sources,
  vala_args: '--target-glib=2.50',
  dependencies: swaysettings_deps,
  install: true,
)
