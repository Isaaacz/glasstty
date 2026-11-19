#!/usr/bin/env bash
# uninstall-niri.sh — undo install-niri.sh.
#
#   ./uninstall-niri.sh            remove glasstty from ~/.config and friends
#   ./uninstall-niri.sh --dry-run  print what would be done, change nothing
#
# Removes only what points into THIS repo or is an unchanged copy of a file
# from it: links, systemd drop-ins, launchers, wal templates, commands. When the
# installer had moved your own file aside (*.bak-<date>), the newest backup is
# put back. Packages, pywal's cache, your wallpapers and the repo itself stay.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
cfg="$HOME/.config"
dry=0
[ "${1:-}" = --dry-run ] && dry=1

say() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
run() { if [ "$dry" = 1 ]; then printf '    %s\n' "$*"; else "$@"; fi; }

# A link into the repo: remove it and bring back the newest backup, if any.
unlink_repo() {
    local p="$1"
    if [ -L "$p" ] && [[ "$(readlink -f "$p")" == "$repo"/* ]]; then
        run rm "$p"
        say "removed link: $p"
        local bak
        bak="$(ls -d "$p".bak-* 2>/dev/null | sort | tail -n1 || true)"
        if [ -n "$bak" ]; then
            run mv "$bak" "$p"
            say "restored: $p (from $(basename "$bak"))"
        fi
    fi
}
# A copy of a repo file: remove it only if it is still identical.
remove_copy() {   # remove_copy <installed file> <repo file>
    if [ -f "$1" ] && [ -f "$2" ] && cmp -s "$1" "$2"; then
        run rm "$1"
        say "removed: $1"
    elif [ -f "$1" ]; then
        say "kept (you changed it): $1"
    fi
}

for p in quickshell niri/config.kdl quickshell-rice.json glasstty kitty fastfetch \
         spicetify/Themes spicetify/Extensions; do
    unlink_repo "$cfg/$p"
done
for b in "$HOME"/.local/bin/*; do unlink_repo "$b"; done

sd="$cfg/systemd/user"
remove_copy "$sd/niri.service.d/oo7.conf"       "$repo/home/.config/systemd/user/niri.service.d/oo7.conf"
remove_copy "$sd/niri.service.d/theme-env.conf" "$repo/home/.config/systemd/user/niri.service.d/theme-env.conf"
for s in xdg-desktop-portal-gnome xdg-desktop-portal-gtk; do
    remove_copy "$sd/$s.service.d/pocket-niri.conf" "$repo/home/.config/systemd/user/$s.service.d/pocket-niri.conf"
done
[ "$dry" = 1 ] || systemctl --user daemon-reload 2>/dev/null || true

for d in org.gnome.Settings.desktop pocket-dots-ajustes.desktop com.spotify.Client.desktop; do
    remove_copy "$HOME/.local/share/applications/$d" "$repo/home/.local/share/applications/$d"
done
remove_copy "$cfg/niri-mimeapps.list" "$repo/home/.config/niri-mimeapps.list"
for t in "$repo"/home/.config/wal/templates/*; do
    remove_copy "$cfg/wal/templates/$(basename "$t")" "$t"
done

# Generated at run time by the rice (niri-only icon theme and its dconf profile).
for g in "$cfg/pocket-dots/dconf" "$HOME/.local/share/icons/pywal-icons"; do
    if [ -e "$g" ] || [ -L "$g" ]; then run rm -rf "$g"; say "removed: $g"; fi
done

# Folders the installer created and that are now empty.
for d in "$sd"/niri.service.d "$sd"/xdg-desktop-portal-gnome.service.d \
         "$sd"/xdg-desktop-portal-gtk.service.d "$cfg/spicetify" "$cfg/wal/templates"; do
    [ -d "$d" ] && [ -z "$(ls -A "$d")" ] && run rmdir "$d"
done

if [ "$dry" = 1 ]; then
    say "Dry run: nothing was changed."
else
    say "Done. Packages, wallpapers and this repo were left in place."
    say "~/.config/niri/ keeps niri's own files; with config.kdl gone, niri uses its defaults."
fi
