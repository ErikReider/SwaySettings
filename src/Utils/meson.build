_sources = {
  'dbus': {
    'files': files('./dbus.vala'),
    'dependencies': [],
    'requires': [],
  },
  'fs': {
    'files': files('./fs.vala'),
    'dependencies': [],
    'requires': [],
  },
  'gschema': {
    'files': [files('./gschema.vala'), swaysettings_sources],
    'dependencies': [],
    'requires': [],
  },
  'vala': {
    'files': files('./vala.vala'),
    'dependencies': [],
    'requires': [],
  },
  'wallpaper': {
    'files': files('./wallpaper.vala'),
    'dependencies': [dep_gtk4, dep_glycin, dep_glycin_gtk4],
    'requires': ['gschema'],
  },
  'widgets': {
    'files': files('./widgets.vala'),
    'dependencies': [dep_gtk4, dep_libadwaita],
    'requires': [],
  },
}

utils = {}
foreach name, source : _sources
  _files = [source['files']]
  _dependencies = [source['dependencies']]

  foreach req_name : source['requires']
    requires = _sources[req_name]
    _files += requires['files']
    _dependencies += requires['dependencies']
  endforeach

  utils += {
    name: {
      'files': _files,
      'dependencies': _dependencies,
    },
  }
endforeach
