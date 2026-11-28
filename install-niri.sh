#!/usr/bin/env bash
# install-niri.sh — glasstty on Fedora + niri, next to an untouched GNOME.
#
#   ./install-niri.sh                    install (asks which optional parts, in a terminal)
#   ./install-niri.sh --yes              no questions: the defaults below
#   ./install-niri.sh --with spotify,sddm --without wallpapers
#   ./install-niri.sh --minimal          the core only, no optional parts
#   ./install-niri.sh --no-packages      skip dnf/pipx (configs only)
#   ./install-niri.sh --dry-run          print what would be done, change nothing
#
# Optional parts (the core — shell, niri, kitty, fastfetch, scripts — always goes in):
#   fonts       the Symbols Nerd Font, if no Nerd Font is installed  (default: on)
#   wallpapers  the five wallpapers into ~/Pictures/wallpapers        (default: on)
#   spotify     Spotify in the palette (spicetify theme, launcher)    (default: on if Spotify is installed)
#   vscode      VS Code on Wayland and in the palette                 (default: on if VS Code is installed)
#   sddm        login screen with the thyx theme; asks for sudo, and only
#               installs it: switching GDM -> SDDM stays your step      (default: off)
# (--no-fonts is the same as --without fonts.)
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
# Your files are never deleted or overwritten:
#   * anything in the way of a link — a file, a folder, or a symlink of your
#     own (pointing to your dotfiles, say) — is moved to <name>.bak-<date>;
#   * a copied file that already exists and differs is moved aside the same way
#     (systemd drop-ins) or simply left alone (templates, launchers, commands);
#   * what already points into this repo is left as it is.
# Re-runnable: a second run finds everything in place and changes nothing.
# Undo with ./uninstall-niri.sh (it puts the .bak-<date> files back).
set -Eeuo pipefail   # -E: the error trap also fires inside functions

repo="$(cd "$(dirname "$0")" && pwd)"
stamp="$(date +%Y%m%d-%H%M%S)"
cfg="$HOME/.config"
packages=1
dry=0
ask=1                       # ask about the optional parts (only in a terminal)
components="fonts wallpapers spotify vscode sddm"
declare -A want=()          # component -> 1 / 0, "" = default
usage() { sed -n '4,24p' "$0" | sed 's/^# \{0,1\}//'; }
setlist() {   # setlist <0|1> <a,b,c>
    local v="$1" c
    for c in ${2//,/ }; do
        [[ " $components " == *" $c "* ]] || { echo "unknown part: $c (one of: $components)" >&2; exit 1; }
        want[$c]="$v"
    done
    ask=0
}
while [ $# -gt 0 ]; do
    case "$1" in
        --no-packages) packages=0 ;;
        --no-fonts) setlist 0 fonts ;;
        --with) [ -n "${2:-}" ] || { usage >&2; exit 1; }; setlist 1 "$2"; shift ;;
        --with=*) setlist 1 "${1#*=}" ;;
        --without) [ -n "${2:-}" ] || { usage >&2; exit 1; }; setlist 0 "$2"; shift ;;
        --without=*) setlist 0 "${1#*=}" ;;
        --minimal) for c in $components; do want[$c]=0; done; ask=0 ;;
        --yes|-y) ask=0 ;;
        --dry-run) dry=1 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 1 ;;
    esac
    shift
done

say()  { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> warning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==> error:\033[0m %s\n' "$*" >&2; exit 1; }
# Every change goes through run: in --dry-run it is only printed.
last=""
run() { last="$*"; if [ "$dry" = 1 ]; then printf '    %s\n' "$*"; else "$@"; fi; }

# What happened, for the summary at the end.
done_=() ; moved=() ; kept=() ; skipped=()
step="starting"
log=""

summary() {
    echo
    say "Summary${1:+ ($1)}"
    printf '    installed or updated: %d\n' "${#done_[@]}"
    if [ "${#moved[@]}" -gt 0 ]; then
        printf '    moved aside (restore with ./uninstall-niri.sh):\n'
        printf '      %s\n' "${moved[@]}"
    fi
    if [ "${#kept[@]}" -gt 0 ]; then
        printf '    left as they were (yours, or already in place):\n'
        printf '      %s\n' "${kept[@]}"
    fi
    if [ "${#skipped[@]}" -gt 0 ]; then
        printf '    not installed (optional parts left out):\n'
        printf '      %s\n' "${skipped[@]}"
    fi
    [ -z "$log" ] || printf '    full log: %s\n' "$log"
}
# A failure says where it happened and what was already done. Nothing is left
# half-written: every change is one mv / ln / cp, and a re-run picks up from
# wherever this one stopped.
on_error() {
    local rc=$? line=$1 cmd=$2
    [ "$cmd" = '"$@"' ] && [ -n "$last" ] && cmd="$last"     # a change made through run()
    printf '\n\033[1;31m==> error\033[0m during "%s" (line %s): %s (exit %s)\n' "$step" "$line" "$cmd" "$rc" >&2
    summary "stopped early"
    printf '\nFix the cause and run ./install-niri.sh again: it is safe to repeat.\n' >&2
    exit "$rc"
}
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

# 0 ── checks before touching anything ─────────────────────────────────────
step="checks"
[ "$(id -u)" -ne 0 ] || die "run this as your user, not with sudo (it asks for sudo itself when needed)"
[ -d "$repo/home/.config/quickshell" ] && [ -f "$repo/home/.config/niri/config.kdl" ] \
    || die "this does not look like the glasstty repo: $repo"
for c in ln cp mv cmp mkdir readlink date; do
    command -v "$c" >/dev/null 2>&1 || die "missing command: $c"
done
if [ "$packages" = 1 ]; then
    command -v dnf >/dev/null 2>&1 || die "dnf not found: this installs packages for Fedora; use --no-packages elsewhere"
    grep -qi fedora /etc/os-release 2>/dev/null || warn "not Fedora: package names may differ"
fi

# What the desktop needs at run time (from packages/fedora-niri.txt and pipx).
runtime="niri qs wal grim slurp magick jq wl-copy swayidle kitty nautilus brightnessctl"
missing_runtime() { local c m=(); for c in $runtime; do command -v "$c" >/dev/null 2>&1 || m+=("$c"); done; echo "${m[*]:-}"; }
if [ "$packages" = 0 ]; then
    m="$(missing_runtime)"
    [ -z "$m" ] || warn "not installed (needed at run time): $m — run without --no-packages, or install them"
fi

# ── the optional parts: defaults, then the questions (or the flags) ──
has_nerd_font() { fc-list : family 2>/dev/null | grep -i "Nerd Font" >/dev/null; }
# Looked up by folder, not with `flatpak info`: that creates an empty user
# Flatpak repo in a HOME that has none (even in --dry-run).
has_flatpak() { [ -d "$HOME/.local/share/flatpak/app/$1" ] || [ -d "/var/lib/flatpak/app/$1" ]; }
has_spotify() { has_flatpak com.spotify.Client || [ -x /usr/bin/spotify ]; }
has_vscode() { [ -x /usr/bin/code ] || has_flatpak com.visualstudio.code; }
default_of() {
    case "$1" in
        fonts) has_nerd_font && echo 0 || echo 1 ;;
        wallpapers) echo 1 ;;
        spotify) has_spotify && echo 1 || echo 0 ;;
        vscode) has_vscode && echo 1 || echo 0 ;;
        sddm) echo 0 ;;
    esac
}
describe() {
    case "$1" in
        fonts) echo "Symbols Nerd Font (the shell's icons)" ;;
        wallpapers) echo "the five wallpapers, into ~/Pictures/wallpapers" ;;
        spotify) echo "Spotify in the wallpaper's colours (spicetify)" ;;
        vscode) echo "VS Code on Wayland, in the wallpaper's colours" ;;
        sddm) echo "login screen with the thyx theme (sudo; GDM stays the login until you switch)" ;;
    esac
}
if [ "$ask" = 1 ] && [ "$dry" = 0 ] && [ -t 0 ] && [ -t 1 ]; then
    say "Optional parts (Enter keeps the suggestion in capitals)"
    for c in $components; do
        [ -n "${want[$c]:-}" ] && continue
        d="$(default_of "$c")"
        if [ "$d" = 1 ]; then hint="Y/n"; else hint="y/N"; fi
        read -r -p "    $(describe "$c")? [$hint] " reply || reply=""
        case "${reply,,}" in y|yes|s|sim) want[$c]=1 ;; n|no|nao|não) want[$c]=0 ;; *) want[$c]="$d" ;; esac
    done
fi
for c in $components; do
    [ -n "${want[$c]:-}" ] || want[$c]="$(default_of "$c")"
    [ "${want[$c]}" = 1 ] || skipped+=("$c: $(describe "$c")")
done
say "parts: core$(for c in $components; do [ "${want[$c]}" = 1 ] && printf ' + %s' "$c"; done)"

# Everything that follows also goes to a log file, for when something fails.
if [ "$dry" = 0 ]; then
    mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/glasstty"
    log="${XDG_CACHE_HOME:-$HOME/.cache}/glasstty/install-$stamp.log"
    exec > >(tee -a "$log") 2>&1
fi

# 1 ── packages ─────────────────────────────────────────────────────────────
if [ "$packages" = 1 ]; then
    step="packages"
    say "Fedora packages (sudo dnf)"
    mapfile -t pkgs < <(grep -v '^\s*#' "$repo/packages/fedora-niri.txt" | grep -v '^\s*$')
    run sudo dnf copr enable -y errornointernet/quickshell
    run sudo dnf install -y --skip-unavailable "${pkgs[@]}"

    say "pywal (pipx)"
    command -v wal >/dev/null 2>&1 || run pipx install pywal16
    # pipx puts wal in ~/.local/bin, which a fresh account may not have on PATH yet.
    case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

    if [ "$dry" = 0 ]; then
        step="checking the packages"
        m="$(missing_runtime)"
        [ -z "$m" ] || die "these did not install: $m. Look at the dnf output above (or the log: $log); a mirror hiccup is the usual cause — run ./install-niri.sh again."
    fi
fi

# Nerd Font v3 symbols: the shell's icons live in the Material Design range
# (U+F0001+). Not packaged in Fedora. Only the TTFs: the bundled fontconfig
# .conf would also change fallbacks for the GNOME session.
# Any Nerd Font carries the symbols (JetBrainsMono Nerd Font does too).
# (grep without -q: with pipefail an early exit would fail fc-list with SIGPIPE.)
if [ "${want[fonts]}" = 1 ] && ! has_nerd_font; then
    step="Nerd Font"
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
        done_+=("Symbols Nerd Font")
    fi
fi

# 2 ── links / copies ───────────────────────────────────────────────────────
ours() { [ -L "$1" ] && [[ "$(readlink -f "$1")" == "$repo"/* ]]; }

# Moves whatever is at $1 out of the way: a file, a folder, or a symlink that
# is not ours (its target is kept in the summary).
move_aside() {
    local p="$1" what
    if [ -L "$p" ]; then what="$p (link to $(readlink "$p"))"
    else what="$p"; fi
    run mv -- "$p" "$p.bak-$stamp"
    moved+=("$what -> $(basename "$p").bak-$stamp")
}

# link <repo path> <where>: the repo is linked there; anything else in the way
# is moved aside first.
link() {
    local src="$1" dst="$2"
    if ours "$dst" && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
        kept+=("$dst (already linked)"); return
    fi
    run mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] || [ -L "$dst" ]; then move_aside "$dst"; fi
    run ln -sn -- "$src" "$dst"
    done_+=("$dst")
}

# copy_keep <src> <dir>: copied unless something is already there (never replaced).
copy_keep() {
    local src="$1" dst="$2/$(basename "$1")"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        if cmp -s "$src" "$dst"; then kept+=("$dst (already in place)"); else kept+=("$dst (yours, not replaced)"); fi
        return
    fi
    run mkdir -p "$2"
    run cp -- "$src" "$dst"
    done_+=("$dst")
}

# copy_update <src> <dir>: the repo's version goes in; a different existing
# file is moved aside first (systemd drop-ins: an old one would break the
# session's theme).
copy_update() {
    local src="$1" dst="$2/$(basename "$1")"
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then kept+=("$dst (already in place)"); return; fi
    run mkdir -p "$2"
    if [ -e "$dst" ] || [ -L "$dst" ]; then move_aside "$dst"; fi
    run cp -- "$src" "$dst"
    done_+=("$dst")
}

# link_keep <src> <dst>: linked unless the name is already taken (commands in
# ~/.local/bin: yours win).
link_keep() {
    local src="$1" dst="$2"
    if ours "$dst"; then kept+=("$dst (already linked)"); return; fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then kept+=("$dst (yours, not replaced)"); return; fi
    run mkdir -p "$(dirname "$dst")"
    run ln -sn -- "$src" "$dst"
    done_+=("$dst")
}

step="links"
say "links into $cfg"
link "$repo/home/.config/quickshell"            "$cfg/quickshell"
link "$repo/home/.config/niri/config.kdl"       "$cfg/niri/config.kdl"
# quickshell-rice.json is NOT linked: it is the Settings app's state, yours.
# The shell creates it with Config.qml's defaults on first start.
link "$repo/home/.config/glasstty"              "$cfg/glasstty"
link "$repo/home/.config/kitty"                 "$cfg/kitty"
link "$repo/home/.config/fastfetch"             "$cfg/fastfetch"
# The shell side (prompt, eza/bat/zoxide/fzf, greeting): Fedora's ~/.bashrc
# sources every file in ~/.bashrc.d. A file of yours with that name wins.
link_keep "$repo/home/.config/glasstty/shell/glasstty.bash" "$HOME/.bashrc.d/glasstty.bash"

step="wal templates"
say "wal templates -> $cfg/wal/templates"
for t in "$repo"/home/.config/wal/templates/*; do copy_keep "$t" "$cfg/wal/templates"; done

# niri.service: start the oo7 secret service with niri, and give niri's apps
# the icon theme in the wallpaper's colours (dconf profile, see dconf-niri.sh).
step="systemd drop-ins"
say "systemd --user drop-ins"
sd="$cfg/systemd/user"
copy_update "$repo/home/.config/systemd/user/niri.service.d/oo7.conf"       "$sd/niri.service.d"
copy_update "$repo/home/.config/systemd/user/niri.service.d/theme-env.conf" "$sd/niri.service.d"
for s in xdg-desktop-portal-gnome xdg-desktop-portal-gtk; do
    copy_update "$repo/home/.config/systemd/user/$s.service.d/pocket-niri.conf" "$sd/$s.service.d"
done
[ "$dry" = 1 ] || systemctl --user daemon-reload 2>/dev/null || true

# Launchers: GNOME Settings that opens under niri, the shell's own Settings,
# and Spotify (user Flatpak) with the DevTools port for live recolouring.
step="launchers"
say "launchers -> ~/.local/share/applications"
for d in org.gnome.Settings.desktop pocket-dots-ajustes.desktop; do
    copy_keep "$repo/home/.local/share/applications/$d" "$HOME/.local/share/applications"
done
# Default apps for the niri session only (folders open in Files).
copy_keep "$repo/home/.config/niri-mimeapps.list" "$cfg"

# Optional: Spotify (user Flatpak) with the DevTools port for live recolouring,
# and the spicetify theme folders (see docs/DETALHES.md).
if [ "${want[spotify]}" = 1 ]; then
    step="spotify"
    say "Spotify theming"
    copy_keep "$repo/home/.local/share/applications/com.spotify.Client.desktop" "$HOME/.local/share/applications"
    for d in Themes Extensions; do
        link_keep "$repo/home/.config/spicetify/$d" "$cfg/spicetify/$d"
    done
    command -v spicetify >/dev/null 2>&1 || warn "spicetify is not installed: see docs/DETALHES.md (Spotify) to finish"
fi

step="commands"
say "commands -> ~/.local/bin"
for b in "$repo"/home/.local/bin/*; do
    case "$(basename "$b")" in
        spotify) [ "${want[spotify]}" = 1 ] || continue ;;   # the Flatpak wrapper
        code)    [ "${want[vscode]}" = 1 ]  || continue ;;   # VS Code on Wayland
    esac
    link_keep "$b" "$HOME/.local/bin/$(basename "$b")"
done

# 3 ── wallpapers and the first palette ─────────────────────────────────────
if [ "${want[wallpapers]}" = 1 ]; then
    step="wallpapers"
    # xdg-user-dir answers $HOME itself when no pictures folder is configured.
    pics="$(xdg-user-dir PICTURES 2>/dev/null || true)"
    { [ -z "$pics" ] || [ "$pics" = "$HOME" ]; } && pics="$HOME/Pictures"
    pics="$pics/wallpapers"
    say "wallpapers -> $pics"
    for w in "$repo"/home/Pictures/wallpapers/*.jpg; do copy_keep "$w" "$pics"; done
fi

# So colors-niri.kdl exists on the first niri start.
step="first palette"
if command -v wal >/dev/null 2>&1 && [ ! -f "$HOME/.cache/wal/colors.json" ]; then
    first="$(ls "$repo"/home/Pictures/wallpapers/*.jpg 2>/dev/null | head -n1)"
    if [ -n "$first" ]; then
        run wal -i "$first" -n -q
        say "first palette: $first"
    fi
fi

# Optional: the SDDM login with the thyx theme (github.com/rccyx/thyx). It is
# installed and set to follow the wallpaper; the switch from GDM is left to
# you (./sddm-thyx.sh ativar), since it changes how the machine boots.
if [ "${want[sddm]}" = 1 ]; then
    step="sddm"
    say "login screen: SDDM + thyx (sudo)"
    thyx="${THYX_DIR:-$HOME/Projetos/thyx}"
    if [ ! -f "$thyx/metadata.desktop" ]; then
        run git clone --depth 1 https://github.com/rccyx/thyx.git "$thyx"
    fi
    run "$repo/sddm-thyx.sh" instalar
    run "$repo/sddm-thyx.sh" layout pocket
    run "$repo/sddm-thyx.sh" sincronizar
    done_+=("SDDM + thyx (not active yet: run ./sddm-thyx.sh ativar to make it the login)")
fi

trap - ERR
step="done"
summary
if [ "$dry" = 0 ]; then
    if command -v niri >/dev/null 2>&1; then
        if niri validate -c "$cfg/niri/config.kdl" >/dev/null 2>&1; then say "config.kdl is valid"
        else warn "niri validate failed, run: niri validate"; fi
    fi
    say "Done. Log out and pick niri on the login screen. GNOME is still there, untouched."
else
    say "Dry run: nothing was changed."
fi
