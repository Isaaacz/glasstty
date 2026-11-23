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
# Blur and darken from Settings > Appearance > Lock, so the login and the lock
# screen look the same. Untouched (lockBlur -1) it is the original sigma 28
# plus thyx's own light Blur on top; a chosen % uses the same curve as
# LockTheme.qml (80 % = sigma 28, 0 = the picture as it is) and no thyx blur.
cfg="${RICE_JSON:-$HOME/.config/quickshell-rice.json}"
pct=$(jq -r '.lockBlur // -1' "$cfg" 2>/dev/null); [[ "$pct" =~ ^-?[0-9]+$ ]] || pct=-1
dim=$(jq -r '.lockDim // 0' "$cfg" 2>/dev/null); [[ "$dim" =~ ^[0-9]+$ ]] || dim=0
# The password side and the 12-hour clock too (PocketLogin.qml reads both).
side=$(jq -r '.lockSide // ""' "$cfg" 2>/dev/null); [[ "$side" =~ ^(left|right|center)$ ]] || side=""
h12=$(jq -r '.lock12h // false' "$cfg" 2>/dev/null)
cy=$(jq -r '.lockClockY // -1' "$cfg" 2>/dev/null); [[ "$cy" =~ ^[0-9]+$ ]] || cy=""
fy=$(jq -r '.lockFormY // -1' "$cfg" 2>/dev/null); [[ "$fy" =~ ^[0-9]+$ ]] || fy=""
thyx_blur=0
if [ "$pct" -lt 0 ]; then pct=80; thyx_blur=0.15; fi
blur=()
if [ "$pct" -gt 0 ]; then
    # Big blurs on a smaller copy: same look, much faster.
    read -r f sg < <(awk -v p="$pct" 'BEGIN { s = 28 * (p / 80) ^ 1.3; f = 6 / s; if (f > 1) f = 1; printf "%.1f %.2f\n", f * 100, s * f }')
    blur=(-resize "$f%" -blur "0x$sg" -resize "${size}!")
fi
bright=$(awk -v d="$dim" 'BEGIN { printf "%d", 92 * (1 - d / 100) }')
magick "$img" -resize "${size}^" -gravity center -extent "$size" \
    "${blur[@]}" -modulate "$bright,110" -quality 90 "$out.tmp.jpg" && mv -f "$out.tmp.jpg" "$out"

# Base preset + pywal colours + our background. Later keys win.
tmp="$theme/theme.conf.tmp"
{
    cat "$base"
    echo
    echo "# --- pocket-dots: login-pywal.sh (wallpaper $(basename "$img")) ---"
    grep -E '^[A-Za-z]+=' "$colors"
    echo 'Background="backgrounds/pocket-wallpaper.jpg"'
    echo "Blur=\"$thyx_blur\""
    [ -n "$side" ] && echo "FormPosition=\"$side\""
    [ "$h12" = true ] && echo 'HourFormat="h:mm"'
    [ -n "$cy" ] && echo "PocketClockY=\"$cy\""
    [ -n "$fy" ] && echo "PocketFormY=\"$fy\""
    echo 'AutoFingerprintOnLoad=false'
} | awk -F= '
    /^\[/ { if (!sec) { print; sec=1 } ; next }
    /^[A-Za-z]+=/ { k=$1; if (!(k in v)) order[++n]=k; v[k]=$0; next }
    END { for (i=1; i<=n; i++) print v[order[i]] }
' > "$tmp" && mv -f "$tmp" "$theme/theme.conf"
