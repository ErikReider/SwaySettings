vala = meson.get_compiler('vala')
cc = meson.get_compiler('c')

# Deps
dep_glib = dependency('glib-2.0', version: '>= 2.50')
dep_gio_unix = dependency('gio-unix-2.0', version: '>= 2.50')
dep_gio = dependency('gio-2.0', version: '>= 2.50')
dep_gtk4 = dependency('gtk4', version: '>= 4.14.0')
dep_gdk_pixbuf = dependency('gdk-pixbuf-2.0')
dep_libadwaita = dependency('libadwaita-1', version: '>= 1.6')
dep_json_glib = dependency('json-glib-1.0')
dep_granite7 = dependency('granite-7')
dep_libxml = dependency('libxml-2.0')
dep_udisks2 = dependency('udisks2')
dep_libgtop = dependency('libgtop-2.0')
dep_gtk4_layer_shell = dependency('gtk4-layer-shell-0', version: '>= 1.2.0')
dep_libpulse = dependency('libpulse')
dep_libpulse_mainloop_glib = dependency('libpulse-mainloop-glib')
dep_upower_glib = dependency('upower-glib', version: '>= 1.90.0')
dep_libnotify = dependency('libnotify', version: '>= 0.8.0')

shared_deps = [
  vala.find_library('posix'),
  dependency('accountsservice'),
  dependency('gee-0.8'),
  dependency('gsettings-desktop-schemas'),
  cc.find_library('m', required: true),
]

shared_files = files(
  './Constants.vala',
  './Functions.vala',
  './Strings.vala',
  './UserMgr.vala',
  './Utils.vala',
)

subdir('Settings')
subdir('Wallpaper')
subdir('AutoStart')
subdir('Portal')
subdir('Screenshot')
subdir('Locker')
subdir('UPowerMonitor')
