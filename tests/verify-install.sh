#!/usr/bin/env bash
# tests/verify-install.sh — check a real glasstty install, changing nothing.
#
#   tests/verify-install.sh
#
# Run it after ./install-niri.sh (from GNOME or from niri). Each line is
# ✓ fine, ! worth a look, ✗ broken; the exit code is the number of ✗.
# Inside the niri session it also checks that the shell is up.
set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
cfg="$HOME/.config"
bad=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
no()   { printf '  \033[31m✗\033[0m %s\n' "$1"; bad=$((bad + 1)); }

echo "links into this repo"
for p in quickshell niri/config.kdl quickshell-rice.json glasstty kitty fastfetch; do
    t="$cfg/$p"
    if [ -L "$t" ] && [ "$(readlink -f "$t")" = "$(readlink -f "$repo/home/.config/$p")" ]; then ok "$t"
    elif [ -e "$t" ]; then no "$t exists but is not linked to this repo"
    else no "$t is missing"; fi
done

echo "copies"
for f in niri.service.d/oo7.conf niri.service.d/theme-env.conf \
         xdg-desktop-portal-gnome.service.d/pocket-niri.conf xdg-desktop-portal-gtk.service.d/pocket-niri.conf; do
    t="$cfg/systemd/user/$f"
    if [ ! -f "$t" ]; then no "$t is missing"
    elif cmp -s "$t" "$repo/home/.config/systemd/user/$f"; then ok "$t"
    else warn "$t differs from the repo's (run ./install-niri.sh to update it)"; fi
done
[ -f /usr/share/wayland-sessions/niri.desktop ] && ok "niri appears on the login screen" || no "no niri session file (is niri installed?)"

echo "programs"
for c in niri qs wal grim slurp magick jq wl-copy swayidle kitty nautilus brightnessctl; do
    command -v "$c" >/dev/null 2>&1 && ok "$c" || no "$c not found"
done
fc-list : family 2>/dev/null | grep -i "Nerd Font" >/dev/null && ok "a Nerd Font (icons)" || no "no Nerd Font (the icons will be boxes)"

echo "configuration"
if command -v niri >/dev/null 2>&1; then
    niri validate -c "$cfg/niri/config.kdl" >/dev/null 2>&1 && ok "niri config is valid" || no "niri validate fails: run  niri validate"
fi
[ -f "$HOME/.cache/wal/colors.json" ] && ok "a pywal palette exists" || warn "no pywal palette yet (pick a wallpaper with Super+W)"

# Inside niri, or with a niri session of yours running (e.g. checked over SSH).
if [ "${XDG_CURRENT_DESKTOP:-}" = niri ] || [ -n "${NIRI_SOCKET:-}" ] || pgrep -u "$(id -u)" -x niri >/dev/null; then
    [ -n "${WAYLAND_DISPLAY:-}" ] || export WAYLAND_DISPLAY="$(cd "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" 2>/dev/null && ls -1 wayland-[0-9] 2>/dev/null | tail -n1)"
    echo "running session (niri)"
    pgrep -x qs >/dev/null && ok "the shell (quickshell) is running" || no "quickshell is not running"
    [ "$(qs ipc call lock status 2>/dev/null)" = unlocked ] && ok "the lock screen answers" || no "the lock screen does not answer (qs ipc call lock status)"
    pgrep -x swayidle >/dev/null && ok "idle lock (swayidle) is running" || warn "swayidle is not running"
else
    echo "GNOME is untouched"
    it="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null)"
    [ "$it" != "'pywal-icons'" ] && ok "GNOME's icon theme is its own ($it)" || no "GNOME is using glasstty's icon theme"
    pgrep -x qs >/dev/null && no "quickshell is running inside GNOME" || ok "no glasstty bar inside GNOME"
fi

echo
[ "$bad" -eq 0 ] && echo "all good" || echo "$bad problem(s)"
exit "$bad"
