# SwaySettings

A GUI for configuring your sway desktop

## Features

- Set and remove auto start apps
- Change default apps
- Change GTK theme settings (GTK theme is set per GTK4 color-scheme, ie dark and light mode)
- Mouse and trackpad settings
- Keyboard layout settings
- Switch Wallpaper (selected wallpaper will be located at .cache/wallpaper)
- Configure 
[Sway Notification Center](https://github.com/ErikReider/SwayNotificationCenter)
- sway-wallpaper (a swaybg replacement) which includes a slick fade transition 😎

## Install

Add these lines to the end of your main sway config file

``` ini
# Applies all generated settings
include ~/.config/sway/.generated_settings/*.conf

# To apply the selected wallpaper
exec sway-wallpaper

# Start all of the non-hidden applications in ~/.config/autostart
# This executable is included in the swaysettings package
exec sway-autostart
```

### SwaySettings XDG Portal Usage

Please follow the [xdg-desktop-portal-wlr](https://github.com/emersion/xdg-desktop-portal-wlr/#running)
instructions.

More info can be found [here](https://flatpak.github.io/xdg-desktop-portal/docs/portals.conf.html)
and [here](https://flatpak.github.io/xdg-desktop-portal/docs/configuration-file.html).

#### Example for Sway

```conf
# ~/.config/xdg-desktop-portal/sway-portals.conf

[preferred]
# Use swaysettings and gtk for every portal interface...
default=swaysettings;gtk;
# ... except for the ScreenCast and Screenshot
org.freedesktop.impl.portal.ScreenCast=wlr
org.freedesktop.impl.portal.Screenshot=wlr
org.freedesktop.impl.portal.Secret=gnome-keyring;
```

### Arch

The package is available on the 
[AUR](https://aur.archlinux.org/packages/swaysettings-git/) \
Or:

``` zsh
makepkg -si
```

### Other Distros

#### Needed Dependencies (Package names on Arch)

- vala
- meson
- git
- grim (for screenshotting)
- gtk4
- gtk4-layer-shell
- libadwaita
- blueprint-compiler
- granite7
- libgtop
- glib2
- gobject-introspection
- libgee
- json-glib
- libxml2
- xkeyboard-config
- accountsservice
- libpulse
- bluez

#### Build

``` zsh
# Setup
meson setup build
# Build
meson compile -C build
# Install (optional)
meson install -C build
```
