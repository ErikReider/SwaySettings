# SCSS
sassc = find_program('sassc')
assert(sassc.found())
scss_files = [
  'settings-window.scss',
  'screenshot.scss',
  'locker.scss',
]
foreach file : scss_files
  style_files += custom_target(
    'Compiling SCSS: "@0@"'.format(file),
    input: file,
    depend_files: './base.scss',
    output: fs.name(fs.replace_suffix(file, '.css')),
    command: [
      sassc,
      '-t', 'expanded',
      '@INPUT@',
      '@OUTPUT@',
    ],
  )
endforeach
