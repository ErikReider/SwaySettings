sway_settings_sources = [
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
  'Pages/Mouse/Mouse_Page.vala',
  'Pages/Mouse/Trackad_Page.vala',
  'Pages/Apps/Apps.vala',
  'Pages/Apps/Default_Apps.vala',
  'Pages/Apps/Startup_Apps.vala',
]

sway_settings_deps = [
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('libhandy-1', version: '>= 1.0.0'),
  dependency('json-glib-1.0'),
  dependency('gee-0.8'),
  dependency('granite'),
  meson.get_compiler('vala').find_library('posix'),
]

add_project_arguments (
  '-DHANDY_USE_UNSTABLE_API',
  language: 'c'
)

# FIXME Disable --disable-since-check after libhandy 1.0 is released
add_project_arguments (
  # '--disable-since-check',
  language: 'vala'
)

gnome = import('gnome')

sway_settings_sources += gnome.compile_resources('sway_settings-resources',
  'sway_settings.gresource.xml',
  c_name: 'sway_settings'
)

executable('sway-settings', sway_settings_sources,
  vala_args: '--target-glib=2.50',  dependencies: sway_settings_deps,
  install: true,
)
