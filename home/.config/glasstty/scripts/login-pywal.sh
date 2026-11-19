#!/usr/bin/env bash
# login-pywal.sh — the login screen (SDDM + thyx) and the lock screen follow
# the wallpaper: same image, much more blurred, and the pywal colours.
#
# Runs from set-wallpaper.sh after pywal. Active only after
# `sddm-thyx.sh sincronizar` (flag file below); `sddm-thyx.sh tema NOME`
# turns it off and goes back to a fixed thyx preset.
#
# No sudo: the installed theme folder belongs to the user (the thyx installer
# copies it with the user's ownership). The chosen preset stays in the clone
# (~/Projetos/thyx/theme.conf) and is the base the colours are merged over.
set -uo pipefail

flag="$HOME/.config/pocket-dots/login-sync"
[ -f "$flag" ] || exit 0

theme="${THYX_THEME:-/usr/share/sddm/themes/thyx}"
base="${THYX_DIR:-$HOME/Projetos/thyx}/theme.conf"
colors="$HOME/.cache/wal/thyx-colors.conf"
img="${1:-$(cat "$HOME/.cache/wal/wal" 2>/dev/null)}"

[ -w "$theme/theme.conf" ] && [ -w "$theme/backgrounds" ] || { echo "login-pywal: $theme não é gravável" >&2; exit 1; }
[ -f "$base" ] && [ -f "$colors" ] && [ -f "$img" ] || exit 0

# The wallpaper, cropped to the screen and blurred hard: the login form sits on
# top of it, and a heavy blur is what makes the text readable on any image.
size="$(niri msg --json focused-output 2>/dev/null | jq -r 'if .current_mode != null then .modes[.current_mode] | "\(.width)x\(.height)" else empty end' 2>/dev/null)"
[ -n "$size" ] || size=1920x1080
out="$theme/backgrounds/pocket-wallpaper.jpg"
magick "$img" -resize "${size}^" -gravity center -extent "$size" \
    -blur 0x28 -modulate 92,110 -quality 90 "$out.tmp.jpg" && mv -f "$out.tmp.jpg" "$out"

# Base preset + pywal colours + our background. Later keys win.
tmp="$theme/theme.conf.tmp"
{
    cat "$base"
    echo
    echo "# --- pocket-dots: login-pywal.sh (wallpaper $(basename "$img")) ---"
    grep -E '^[A-Za-z]+=' "$colors"
    echo 'Background="backgrounds/pocket-wallpaper.jpg"'
    echo 'Blur="0.15"'
    echo 'AutoFingerprintOnLoad=false'
} | awk -F= '
    /^\[/ { if (!sec) { print; sec=1 } ; next }
    /^[A-Za-z]+=/ { k=$1; if (!(k in v)) order[++n]=k; v[k]=$0; next }
    END { for (i=1; i<=n; i++) print v[order[i]] }
' > "$tmp" && mv -f "$tmp" "$theme/theme.conf"
