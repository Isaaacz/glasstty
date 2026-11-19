#!/usr/bin/env bash
# dconf-niri.sh — give the niri session its own icon theme without touching
# GNOME's settings.
#
# The icon theme is a dconf key (org.gnome.desktop.interface icon-theme) that
# both sessions share, and GTK has no environment variable for it. dconf does
# have DCONF_PROFILE, though: niri.service points it (EnvironmentFile, see
# niri.service.d/theme-env.conf) at a profile that reads the normal user
# database first and then a small read-only database with ONE locked key,
# icon-theme='pywal-icons'. A locked key in a later database wins over the user
# value, so niri's apps see pywal-icons; every other setting is still the shared
# one, and writes still go to the user database. GNOME never sees the variable,
# so it keeps Tela-black-dark.
#
# pywal-icons is a symlink (kept by gtk-pywal.sh) to the folders tinted for the
# current wallpaper, which inherit the user's real icon theme.
#
# Run by niri.service's ExecStartPre. It writes the env file only once the
# profile checks out: a DCONF_PROFILE pointing at a broken profile would leave
# every app with empty settings.
set -u
dir="$HOME/.config/pocket-dots/dconf"
envf="$dir/env"
rm -f "$envf"
command -v dconf >/dev/null 2>&1 || exit 0
[ -e "$HOME/.local/share/icons/pywal-icons/index.theme" ] || exit 0
mkdir -p "$dir/niri.d/locks"
printf "[org/gnome/desktop/interface]\nicon-theme='pywal-icons'\n" > "$dir/niri.d/00-icons"
echo /org/gnome/desktop/interface/icon-theme > "$dir/niri.d/locks/icons"
dconf compile "$dir/niri.db.tmp" "$dir/niri.d" && mv -f "$dir/niri.db.tmp" "$dir/niri.db" || exit 0
printf 'user-db:user\nfile-db:%s\n' "$dir/niri.db" > "$dir/profile"
[ "$(DCONF_PROFILE="$dir/profile" gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null)" = "'pywal-icons'" ] || exit 0
echo "DCONF_PROFILE=$dir/profile" > "$envf"
