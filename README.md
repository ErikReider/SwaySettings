# Sway-Settings

A GUI for configuring your sway desktop

- Auto start apps
- Default apps
- GTK theme (GTK 3 and potentially GTK 2)
- Pointer settings
- Wallpaper (selected wallpaper will be located at .cache/wallpaper)

## Install

##### At the time of writing, the program assumes that the sway config is in `~/.config/sway`

``` zsh
meson build
ninja -C build
./build/src/sway-settings
```

Add these lines to the end of your main sway config file

```ini
# Applies all generated settings
include ~/.config/sway/.generated_settings/*.conf

# To apply the latest wallpaper
exec_always swaymsg "output * bg ~/.cache/wallpaper fill"
```
