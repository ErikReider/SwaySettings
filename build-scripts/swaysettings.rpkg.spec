# vim: syntax=spec
Name:       {{{ git_dir_name }}}
Version:    0.5.0
Release:    1%{?dist}
Summary:    A gui for setting sway wallpaper, default apps, GTK themes, etc...
License:    GPLv3
URL:        https://github.com/ErikReider/SwaySettings
VCS:        {{{ git_dir_vcs }}}
Source:     {{{ git_dir_pack }}}

BuildRequires:    meson >= 0.60.0
BuildRequires:    vala
BuildRequires:    git

BuildRequires: gtk4-devel >= 4.16
BuildRequires: gtk4-layer-shell-devel
BuildRequires: libadwaita-devel >= 1.6
BuildRequires: granite-7-devel >= 7.5
BuildRequires: pulseaudio-libs-devel
BuildRequires: accountsservice-devel
BuildRequires: bluez
BuildRequires: glib2-devel >= 2.50
BuildRequires: gobject-introspection-devel >= 1.68
BuildRequires: libgee-devel >= 0.20
BuildRequires: json-glib-devel >= 1.0
BuildRequires: systemd-devel
BuildRequires: systemd
BuildRequires: scdoc
Requires: dbus
Requires: libgtop2
Requires: udisks2
Requires: glib2
Requires: accountsservice
Requires: gtk4-layer-shell

%{?systemd_requires}

%description
A gui for setting sway wallpaper, default apps, GTK themes, etc...

%prep
{{{ git_dir_setup_macro }}}

%build
%meson
%meson_build

%install
%meson_install

%files
%doc README.md
%{_bindir}/swaysettings
%{_bindir}/sway-wallpaper
%{_bindir}/sway-autostart
%license COPYING
%{_datadir}/glib-2.0/schemas/org.erikreider.swaysettings.gschema.xml
%{_datadir}/appdata/org.erikreider.swaysettings.appdata.xml
%{_datadir}/applications/org.erikreider.swaysettings.desktop
%{_datadir}/icons/hicolor/scalable/apps/org.erikreider.swaysettings.svg
%{_datadir}/icons/hicolor/symbolic/apps/org.erikreider.swaysettings-symbolic.svg

# Changelog will be empty until you make first annotated Git tag.
%changelog
{{{ git_dir_changelog }}}
