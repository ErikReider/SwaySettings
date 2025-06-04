# Deps
dep_glib = dependency('glib-2.0', version: '>= 2.50')
dep_gio_unix = dependency('gio-unix-2.0', version: '>= 2.50')
dep_gio = dependency('gio-2.0', version: '>= 2.50')
dep_gtk4 = dependency('gtk4', version: '>= 4.14.0')
dep_gdk_pixbuf = dependency('gdk-pixbuf-2.0')
dep_libadwaita = dependency('libadwaita-1', version: '>= 1.6')
dep_json_glib = dependency('json-glib-1.0')
dep_gee = dependency('gee-0.8')
dep_granite7 = dependency('granite-7')
dep_libxml = dependency('libxml-2.0')
dep_accountsservice = dependency('accountsservice')
dep_udisks2 = dependency('udisks2')
dep_libgtop = dependency('libgtop-2.0')
dep_gtk4_layer_shell = dependency('gtk4-layer-shell-0', version: '>= 1.0.2')
dep_libpulse = dependency('libpulse')
dep_libpulse_mainloop_glib = dependency('libpulse-mainloop-glib')
dep_math = meson.get_compiler('c').find_library('m', required : true)
dep_gsettings_schemas = dependency('gsettings-desktop-schemas')

shared_files = files([
  'Constants.vala',
  'Functions.vala',
  'Strings.vala',
  'Utils.vala',
])

subdir('Settings')
subdir('Wallpaper')
subdir('AutoStart')
subdir('Portal')
subdir('Screenshot')
