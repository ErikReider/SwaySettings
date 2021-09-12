# SwaySettings

A GUI for configuring your sway desktop

## Features

- Set and remove auto start apps
- Change default apps
- Change GTK theme (GTK 3 and potentially GTK 2)
- Mouse and trackpad settings
- Keyboard layout settings
- Switch Wallpaper (selected wallpaper will be located at .cache/wallpaper)
- Configure 
[Sway Notification Center](https://github.com/ErikReider/SwayNotificationCenter)

## Install

### Arch

The package is available on the 
[AUR](https://aur.archlinux.org/packages/swaysettings-git/) \
Or:

``` zsh
makepkg -si
```

### Other Distros

``` zsh
meson build
ninja -C build
meson install -C build
```

Add these lines to the end of your main sway config file

``` ini
# Applies all generated settings
include ~/.config/sway/.generated_settings/*.conf

# To apply the selected wallpaper
exec_always swaymsg "output * bg ~/.cache/wallpaper fill"
```
