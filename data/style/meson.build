# SCSS
dart_sass = find_program('sass')
assert(dart_sass.found())
scss_files = [
  'settings-window.scss',
  'screenshot.scss',
  'locker.scss',
]
foreach file : scss_files
  run_command(
    dart_sass,
    '--style=expanded',
    file,
    fs.name(fs.replace_suffix(file, '.css')),
    check: true,
  )
endforeach
