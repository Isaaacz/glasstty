#!/bin/sh
# wallpaper-set.sh IMG [none|fade] — put IMG on screen with whatever backend
# exists. Exits 0 once the new wallpaper is ACTUALLY showing.
#
#   awww  (Arch, the original): `awww img`, with or without awww's own fade.
#   swaybg (Fedora: awww is not packaged): a second swaybg is started with the
#          new image and the old one is killed only after the new surface has
#          had time to map, so there is never a frame of bare background. No
#          fade of its own: the animation is WallpaperFx's, which covers the
#          screen while this runs underneath it.
#
# ~/.cache/wal/current-wallpaper always points at what is showing; it is the
# "old image" the next WallpaperFx transition starts from.
img="$1"; mode="${2:-none}"
[ -f "$img" ] || exit 1

if command -v awww >/dev/null 2>&1 && awww query >/dev/null 2>&1; then
    if [ "$mode" = fade ]; then
        awww img "$img" --transition-type fade --transition-duration 0.5 || exit 1
    else
        awww img "$img" --transition-type none || exit 1
    fi
else
    command -v swaybg >/dev/null 2>&1 || exit 1
    uid="$(id -u)"
    old="$(pgrep -u "$uid" -x swaybg)"
    setsid -f swaybg -m fill -i "$img" >/dev/null 2>&1 9>&- 8>&- 7>&-
    # Decoding a 4K JPEG and mapping the layer takes ~0.2-0.3 s.
    sleep 0.35
    [ -n "$old" ] && kill $old 2>/dev/null
fi
mkdir -p "$HOME/.cache/wal"
ln -sfn "$img" "$HOME/.cache/wal/current-wallpaper"
exit 0
