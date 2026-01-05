# vim: syntax=spec
Name:       swaysettings-git
Version:    {{{ git_repo_release lead="$(git describe --tags --abbrev=0)" }}}
Release:    {{{ echo -n "$(git rev-list --all --count)" }}}%{?dist}
Summary:    A gui for setting sway wallpaper, default apps, GTK themes, etc...
License:    GPLv3
URL:        https://github.com/ErikReider/SwaySettings
VCS:        {{{ git_repo_vcs }}}
Source:     {{{ git_repo_pack }}}

BuildRequires:    meson >= 0.60.0
BuildRequires:    vala
BuildRequires:    git

BuildRequires: gtk4-devel >= 4.16
BuildRequires: pkgconfig(gtk4-layer-shell-0) >= 1.1.1
BuildRequires: libadwaita-devel >= 1.6
BuildRequires: pkgconfig(gsettings-desktop-schemas)
BuildRequires: granite-7-devel >= 7.5
BuildRequires: pulseaudio-libs-devel
BuildRequires: accountsservice-devel
BuildRequires: bluez-libs-devel
BuildRequires: blueprint-compiler
BuildRequires: glib2-devel >= 2.50
BuildRequires: gobject-introspection-devel >= 1.68
BuildRequires: libgee-devel >= 0.20
BuildRequires: json-glib-devel >= 1.0
BuildRequires: libudisks2-devel
BuildRequires: libgtop2-devel
BuildRequires: systemd-devel
BuildRequires: pkgconfig(systemd)
BuildRequires: systemd
BuildRequires: scdoc
BuildRequires: pkgconfig(pam)
BuildRequires: sassc
BuildRequires: pkgconfig(upower-glib)
BuildRequires: pkgconfig(libnotify)
BuildRequires: pkgconfig(glycin-2)
BuildRequires: pkgconfig(glycin-gtk4-2)
Requires: dbus
Requires: grim
Requires: bluez
Requires: libgtop2
Requires: udisks2
Requires: glib2
Requires: accountsservice
Requires: gtk4-layer-shell
Requires: pam

%{?systemd_requires}

%description
A gui for setting sway wallpaper, default apps, GTK themes, etc...

%prep
{{{ git_repo_setup_macro }}}

%build
%meson
%meson_build

%install
%meson_install

%post
%systemd_user_post sway-wallpaper.service

%preun
%systemd_user_preun sway-wallpaper.service

%files
%doc README.md
%{_bindir}/swaysettings
%{_bindir}/sway-wallpaper
%{_bindir}/sway-autostart
%{_bindir}/swaysettings-screenshot
%{_bindir}/swaysettings-locker
%{_bindir}/swaysettings-upower-monitor
%license COPYING
%{_userunitdir}/sway-wallpaper.service
%{_userunitdir}/swaysettings-upower-monitor.service
%{_datadir}/glib-2.0/schemas/org.erikreider.swaysettings.gschema.xml
%{_datadir}/appdata/org.erikreider.swaysettings.appdata.xml
%{_datadir}/applications/org.erikreider.swaysettings.desktop
%{_datadir}/icons/hicolor/scalable/apps/org.erikreider.swaysettings.svg
%{_datadir}/icons/hicolor/symbolic/apps/org.erikreider.swaysettings-symbolic.svg
%config(noreplace) %{_sysconfdir}/pam.d/swaysettings-locker
# Portal
%{_libexecdir}/xdg-desktop-portal-swaysettings
%{_datadir}/dbus-1/services/org.freedesktop.impl.portal.desktop.swaysettings.service
%{_datadir}/xdg-desktop-portal/portals/swaysettings.portal
%{_userunitdir}/xdg-desktop-portal-swaysettings.service

# Changelog will be empty until you make first annotated Git tag.
%changelog
{{{ git_repo_changelog }}}
