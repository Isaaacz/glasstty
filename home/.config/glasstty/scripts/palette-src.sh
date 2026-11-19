#!/bin/sh
# palette-src.sh IMG [tela]
#   (default) a small copy of IMG (long edge 800 px) to compute the pywal
#             palette and the bar strip from.
#   tela      a copy at the screen's size, for the transition (WallpaperFx) and
#             swaybg: an 8K JPEG took ~1.4 s just to decode before the
#             animation could start, and swaybg decodes it again.
# Cached by path + mtime (+ size); images already small enough are returned as
# they are. See set-wallpaper.sh.
#
# The cache is checked BEFORE looking at the image: `identify` decodes a whole
# PNG to report its size (0.9 s on a 40 MB wallpaper), which is exactly the
# wait this exists to remove.
img="$1"
mode="${2:-paleta}"
[ -f "$img" ] || exit 1
if [ "$mode" = tela ]; then
    geo="$(niri msg --json focused-output 2>/dev/null | jq -r 'if .current_mode != null then .modes[.current_mode] | "\(.width)x\(.height)" else empty end' 2>/dev/null)"
    [ -n "$geo" ] || geo=1920x1080
    W="${geo%x*}"; H="${geo#*x}"; resize="${geo}^"
else
    W=800; H=800; resize="800x800>"
fi
dir="${XDG_CACHE_HOME:-$HOME/.cache}/pocket-dots/$mode"
key="$(printf '%s|%s|%s' "$img" "$(stat -c %Y "$img")" "$W$H" | md5sum | cut -c1-16)"
out="$dir/$key.jpg"
[ -f "$out" ] && { printf '%s\n' "$out"; exit 0; }
[ -f "$dir/$key.small" ] && { printf '%s\n' "$img"; exit 0; }
mkdir -p "$dir"
size="$(identify -format '%w %h' "${img}[0]" 2>/dev/null)" || { printf '%s\n' "$img"; exit 0; }
set -- $size
if [ "${1:-0}" -le "$W" ] && [ "${2:-0}" -le "$H" ]; then
    : > "$dir/$key.small"          # remember: already small, use as is
    printf '%s\n' "$img"; exit 0
fi
magick "${img}[0]" -auto-orient -resize "$resize" -quality 92 "$out.tmp.jpg" 2>/dev/null && mv -f "$out.tmp.jpg" "$out"
[ -f "$out" ] && printf '%s\n' "$out" || printf '%s\n' "$img"
