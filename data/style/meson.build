# SCSS
sassc = find_program('sassc')
assert(sassc.found())
scss_files = [
  'settings-window.scss',
  'screenshot.scss',
  'locker.scss',
]
foreach file : scss_files
  run_command(
    sassc,
    '-t', 'expanded',
    file,
    fs.name(fs.replace_suffix(file, '.css')),
    check: true,
  )
endforeach
