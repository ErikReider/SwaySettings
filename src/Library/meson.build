library_info = [
  {
    'name': 'upower',
    'sources': files(
      './Power/PowerProfiles.vala',
      './Power/UPower.vala',
    ),
    'dependencies': [
      dep_gtk4,
      dep_upower_glib,
    ]
    + shared_deps,
  },
  {
    'name': 'accounts_service',
    'sources': files(
      './AccountsService/AccountsService.vala',
    ),
    'dependencies': [
      dep_accountsservice,
    ]
    + shared_deps,
  },
]

# Ex: 'upower': [deps]
libraries = {}

foreach lib : library_info
  _lib_name = lib['name']
  _lib_dependencies = lib['dependencies']
  _lib_sources = lib['sources']

  _lib = library(
    'libswaysettings-@0@'.format(_lib_name),
    _lib_sources,
    dependencies: _lib_dependencies,
    install: false,
  )

  _dep = declare_dependency(
    link_with: _lib,
    include_directories: include_directories('.'),
  )
  libraries += {_lib_name: [_dep, _lib_dependencies]}
endforeach
