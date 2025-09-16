# SCSS
sassc = find_program('sassc')
assert(sassc.found())
scss_files = [
  'settings-window.scss',
  'screenshot.scss',
  'locker.scss',
]
foreach file : scss_files
  custom_target(
    'SCSS Compilation @0@'.format(file),
    build_by_default: true,
    build_always_stale: true,
    input : file,
    output : fs.name(fs.replace_suffix(file, '.css')),
    install: false,
    install_dir: config_path,
    command : [
      sassc,
      '-t',
      'expanded',
      '@INPUT@',
      '@OUTPUT@'
    ],
  )
endforeach
