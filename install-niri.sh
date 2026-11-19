#!/usr/bin/env bash
# install-niri.sh — glasstty on Fedora + niri, next to an untouched GNOME.
#
#   ./install-niri.sh                 install everything
#   ./install-niri.sh --no-packages   skip dnf/pipx (configs only)
#   ./install-niri.sh --dry-run       print what would be done, change nothing
#
# What it does:
#   1. enables the quickshell COPR and installs packages/fedora-niri.txt
#      (asks for sudo once), then pywal16 with pipx
#   2. links the shell, niri, kitty, fastfetch and the scripts into ~/.config
#      FROM THIS REPO, so a `git pull` here is an update; copies the few files
#      that must live outside it (wal templates, systemd drop-ins, launchers)
#   3. copies the wallpapers to ~/Pictures/wallpapers and makes a first palette
#
# What it does NOT do (on purpose):
#   * no systemd --user unit is enabled: GNOME reaches graphical-session.target
#     too, and a WantedBy there would start the bar inside GNOME. Everything is
#     spawned from ~/.config/niri/config.kdl, which only niri reads.
#   * no GDM/GNOME setting is touched. niri appears as one more session on the
#     login screen (it ships /usr/share/wayland-sessions/niri.desktop).
#
# Re-runnable: existing files that are not links are moved to *.bak-<date>.
# Undo with ./uninstall-niri.sh.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
stamp="$(date +%Y%m%d-%H%M%S)"
cfg="$HOME/.config"
packages=1
dry=0
for a in "$@"; do
    case "$a" in
        --no-packages) packages=0 ;;
        --dry-run) dry=1 ;;
        *) echo "usage: $0 [--no-packages] [--dry-run]" >&2; exit 1 ;;
    esac
done

say() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
# Every change goes through run: in --dry-run it is only printed.
run() { if [ "$dry" = 1 ]; then printf '    %s\n' "$*"; else "$@"; fi; }

# 1 ── packages ─────────────────────────────────────────────────────────────
if [ "$packages" = 1 ]; then
    say "Fedora packages (sudo dnf)"
    mapfile -t pkgs < <(grep -v '^\s*#' "$repo/packages/fedora-niri.txt" | grep -v '^\s*$')
    run sudo dnf copr enable -y errornointernet/quickshell
    run sudo dnf install -y --skip-unavailable "${pkgs[@]}"

    say "pywal (pipx)"
    command -v wal >/dev/null 2>&1 || run pipx install pywal16
fi

# Nerd Font v3 symbols: the shell's icons live in the Material Design range
# (U+F0001+). Not packaged in Fedora. Only the TTFs: the bundled fontconfig
# .conf would also change fallbacks for the GNOME session.
if ! fc-list | grep -q "Symbols Nerd Font"; then
    say "Symbols Nerd Font v3.4.0 (github.com/ryanoasis/nerd-fonts)"
    if [ "$dry" = 1 ]; then
        printf '    download NerdFontsSymbolsOnly.tar.xz into ~/.local/share/fonts/NerdFontsSymbols\n'
    else
        tmp="$(mktemp -d)"
        curl -fsSL -o "$tmp/s.tar.xz" \
            https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/NerdFontsSymbolsOnly.tar.xz
        mkdir -p "$HOME/.local/share/fonts/NerdFontsSymbols"
        tar -xJf "$tmp/s.tar.xz" -C "$HOME/.local/share/fonts/NerdFontsSymbols" \
            SymbolsNerdFont-Regular.ttf SymbolsNerdFontMono-Regular.ttf LICENSE
        rm -rf "$tmp"
        fc-cache -f "$HOME/.local/share/fonts/NerdFontsSymbols"
    fi
fi

# 2 ── links / copies ───────────────────────────────────────────────────────
backup() {
    if [ -e "$1" ] && [ ! -L "$1" ]; then
        run mv "$1" "$1.bak-$stamp"
        say "backup: $1.bak-$stamp"
    fi
}
link() {
    run mkdir -p "$(dirname "$2")"
    backup "$2"
    run ln -sfn "$1" "$2"
    say "link: $2 -> $1"
}
copy() {   # copy <src> <dest dir>; never overwrites
    run mkdir -p "$2"
    run cp -n "$1" "$2/"
}

link "$repo/home/.config/quickshell"            "$cfg/quickshell"
link "$repo/home/.config/niri/config.kdl"       "$cfg/niri/config.kdl"
link "$repo/home/.config/quickshell-rice.json"  "$cfg/quickshell-rice.json"
link "$repo/home/.config/glasstty"              "$cfg/glasstty"
link "$repo/home/.config/kitty"                 "$cfg/kitty"
link "$repo/home/.config/fastfetch"             "$cfg/fastfetch"

say "wal templates -> $cfg/wal/templates"
for t in "$repo"/home/.config/wal/templates/*; do copy "$t" "$cfg/wal/templates"; done

# niri.service: start the oo7 secret service with niri, and give niri's apps
# the icon theme in the wallpaper's colours (dconf profile, see dconf-niri.sh).
say "systemd --user drop-ins"
sd="$cfg/systemd/user"
run mkdir -p "$sd/niri.service.d"
run cp "$repo/home/.config/systemd/user/niri.service.d/oo7.conf" "$sd/niri.service.d/"
run cp "$repo/home/.config/systemd/user/niri.service.d/theme-env.conf" "$sd/niri.service.d/"
for s in xdg-desktop-portal-gnome xdg-desktop-portal-gtk; do
    run mkdir -p "$sd/$s.service.d"
    run cp "$repo/home/.config/systemd/user/$s.service.d/pocket-niri.conf" "$sd/$s.service.d/"
done
[ "$dry" = 1 ] || systemctl --user daemon-reload 2>/dev/null || true

# Launchers: GNOME Settings that opens under niri, the shell's own Settings,
# and Spotify (user Flatpak) with the DevTools port for live recolouring.
say "launchers -> ~/.local/share/applications"
for d in org.gnome.Settings.desktop pocket-dots-ajustes.desktop com.spotify.Client.desktop; do
    copy "$repo/home/.local/share/applications/$d" "$HOME/.local/share/applications"
done
# Default apps for the niri session only (folders open in Files).
copy "$repo/home/.config/niri-mimeapps.list" "$cfg"

# spicetify theme folders (Spotify theming is optional, see docs/DETALHES.md).
run mkdir -p "$cfg/spicetify"
for d in Themes Extensions; do
    [ -e "$cfg/spicetify/$d" ] || run ln -s "$repo/home/.config/spicetify/$d" "$cfg/spicetify/$d"
done

say "commands -> ~/.local/bin"
run mkdir -p "$HOME/.local/bin"
for b in "$repo"/home/.local/bin/*; do
    [ -e "$HOME/.local/bin/$(basename "$b")" ] || run ln -s "$b" "$HOME/.local/bin/$(basename "$b")"
done

# 3 ── wallpapers and the first palette ─────────────────────────────────────
# xdg-user-dir answers $HOME itself when no pictures folder is configured.
pics="$(xdg-user-dir PICTURES 2>/dev/null || true)"
{ [ -z "$pics" ] || [ "$pics" = "$HOME" ]; } && pics="$HOME/Pictures"
pics="$pics/wallpapers"
say "wallpapers -> $pics"
for w in "$repo"/home/Pictures/wallpapers/*.jpg; do copy "$w" "$pics"; done

# So colors-niri.kdl exists on the first niri start.
if command -v wal >/dev/null 2>&1 && [ ! -f "$HOME/.cache/wal/colors.json" ]; then
    first="$(ls "$repo"/home/Pictures/wallpapers/*.jpg 2>/dev/null | head -n1)"
    [ -n "$first" ] && run wal -i "$first" -n -q && say "first palette: $first"
fi

if [ "$dry" = 0 ]; then
    niri validate -c "$cfg/niri/config.kdl" >/dev/null 2>&1 && say "config.kdl is valid" \
        || say "WARNING: niri validate failed, run: niri validate"
    say "Done. Log out and pick niri on the login screen. GNOME is still there, untouched."
else
    say "Dry run: nothing was changed."
fi
