#!/usr/bin/env bash
# palette-variants.sh — several palettes from the same wallpaper, and which one
# each wallpaper uses.
#
#   palette-variants.sh gen [IMG]        all variants of IMG, as one JSON line:
#                                        {"img":…,"choice":…,"variants":[{"id","colors":[…]}]}
#   palette-variants.sh choice [IMG]     the variant saved for IMG ("" = the default)
#   palette-variants.sh file IMG ID      a pywal theme file for that variant
#   palette-variants.sh set ID [IMG]     save ID for IMG and re-theme the desktop
#   palette-variants.sh edit SLOT HEX [IMG]   change one colour of IMG's palette
#                                        (SLOT: background, foreground, color0…color8;
#                                        HEX "" removes the edit) and re-theme
#   palette-variants.sh edits [IMG]      IMG's edits as JSON ({slot: hex})
#   palette-variants.sh apply-edits [IMG]  put IMG's edits on top of the palette
#                                        pywal just wrote (set-wallpaper.sh)
#
# IMG defaults to the wallpaper on screen. The Control Centre's Colours page
# shows the variants; set-wallpaper.sh asks `file` for the saved one, so every
# wallpaper comes back with the palette you picked for it.
#
# Only pywal's own backend is installed, so the variety comes from how it is
# fed and what is done after: saturation, contrast, a light scheme, the colours
# of one part of the picture, and the palette turned round the colour wheel.
# Each run takes a fraction of a second on the small copy (palette-src.sh);
# results are cached per image (path + mtime).
set -uo pipefail

state="${XDG_STATE_HOME:-$HOME/.local/state}/glasstty/palette-choice.json"
edits="${XDG_STATE_HOME:-$HOME/.local/state}/glasstty/palette-edits.json"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/glasstty/palettes"
src="$HOME/.config/glasstty/scripts/palette-src.sh"

# id | pywal arguments (the image placeholder @ is replaced per variant)
VARIANTS='padrao|@full --saturate 0.5
vibrante|@full --saturate 0.85
suave|@full --saturate 0.15
contraste|@full --saturate 0.5 --contrast 7
centro|@center --saturate 0.5
cima|@top --saturate 0.5
baixo|@bottom --saturate 0.5
complementar|@full --saturate 0.5 #hue180
claro|@full --saturate 0.5 -l'

current_img() { cat "$HOME/.cache/pocket-dots/wallpaper" 2>/dev/null || cat "$HOME/.cache/wal/wal" 2>/dev/null; }

key_of() { printf '%s|%s' "$1" "$(stat -c %Y "$1" 2>/dev/null)" | md5sum | cut -c1-16; }

choice_of() {
    [ -f "$state" ] || { echo ""; return; }
    python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get(sys.argv[2], ""))
except Exception: print("")' "$state" "$1"
}

# Makes every variant of $1 under $cache/<key>/<id>.json (only the missing ones).
generate() {
    local img="$1" dir small id args
    dir="$cache/$(key_of "$img")"
    mkdir -p "$dir"
    small="$("$src" "$img" 2>/dev/null)"; [ -f "$small" ] || small="$img"
    # the parts of the picture
    [ -f "$dir/center.jpg" ] || magick "$small" -gravity center -crop 50%x50%+0+0 +repage "$dir/center.jpg" 2>/dev/null
    [ -f "$dir/top.jpg" ]    || magick "$small" -gravity north  -crop 100%x45%+0+0 +repage "$dir/top.jpg" 2>/dev/null
    [ -f "$dir/bottom.jpg" ] || magick "$small" -gravity south  -crop 100%x45%+0+0 +repage "$dir/bottom.jpg" 2>/dev/null
    while IFS='|' read -r id args; do
        [ -s "$dir/$id.json" ] && continue
        (
            set -f
            local hue=0 a=() w
            for w in $args; do
                case "$w" in
                    @full)   a+=(-i "$small") ;;
                    @center) a+=(-i "$dir/center.jpg") ;;
                    @top)    a+=(-i "$dir/top.jpg") ;;
                    @bottom) a+=(-i "$dir/bottom.jpg") ;;
                    '#hue180') hue=180 ;;
                    *) a+=("$w") ;;
                esac
            done
            out="$dir/.run-$id"
            wal "${a[@]}" -n -q -s -t -e --out-dir "$out" >/dev/null 2>&1 || exit 0
            python3 - "$out/colors.json" "$dir/$id.json" "$hue" "$img" <<'PY'
import json, sys, colorsys
src, dst, hue, img = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
d = json.load(open(src))
def turn(h):
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))
    hh, l, s = colorsys.rgb_to_hls(r, g, b)
    r, g, b = colorsys.hls_to_rgb((hh + hue / 360) % 1, l, s)
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))
if hue:
    for k in list(d["colors"]):
        n = int(k[5:])
        if n not in (0, 7, 8, 15):        # the greys and the background keep their tone
            d["colors"][k] = turn(d["colors"][k])
d["wallpaper"] = img
json.dump(d, open(dst + ".tmp", "w"), indent=2)
import os; os.replace(dst + ".tmp", dst)
PY
            rm -rf "$out"
        ) &
    done <<< "$VARIANTS"
    wait
    echo "$dir"
}

cmd="${1:-gen}"; shift || true
case "$cmd" in
    gen)
        img="${1:-$(current_img)}"; [ -f "$img" ] || exit 1
        dir="$(generate "$img")"
        python3 - "$dir" "$img" "$(choice_of "$img")" <<'PY'
import json, os, sys
d, img, choice = sys.argv[1], sys.argv[2], sys.argv[3]
order = ["padrao", "vibrante", "suave", "contraste", "centro", "cima", "baixo", "complementar", "claro"]
out, seen = [], set()
for i in order:
    p = os.path.join(d, i + ".json")
    if not os.path.exists(p): continue
    j = json.load(open(p)); c = j["colors"]
    cols = [j["special"]["background"]] + [c["color%d" % n] for n in range(1, 7)] + [j["special"]["foreground"]]
    # A variant that came out the same as an earlier one (an already vivid
    # picture does not get more vivid) is not offered twice — unless it is
    # the one saved for this wallpaper.
    if tuple(cols) in seen and i != choice: continue
    seen.add(tuple(cols))
    out.append({"id": i, "colors": cols})
print(json.dumps({"img": img, "choice": choice or "padrao", "variants": out}))
PY
        ;;
    choice)
        img="${1:-$(current_img)}"; choice_of "$img" ;;
    file)
        img="$1"; id="$2"
        dir="$cache/$(key_of "$img")"
        [ -s "$dir/$id.json" ] || generate "$img" >/dev/null
        [ -s "$dir/$id.json" ] && echo "$dir/$id.json" ;;
    edits)
        img="${1:-$(current_img)}"
        python3 -c 'import json,sys
try: print(json.dumps(json.load(open(sys.argv[1])).get(sys.argv[2], {})))
except Exception: print("{}")' "$edits" "$img" ;;
    edit)
        slot="$1"; hex="${2:-}"; img="${3:-$(current_img)}"; [ -f "$img" ] || exit 1
        [[ "$slot" =~ ^(background|foreground|color[0-8])$ ]] || exit 1
        [ -z "$hex" ] || [[ "$hex" =~ ^#[0-9a-fA-F]{6}$ ]] || exit 1
        mkdir -p "$(dirname "$edits")"
        python3 - "$edits" "$img" "$slot" "$hex" <<'PY'
import json, os, sys
p, img, slot, hexv = sys.argv[1:]
try: d = json.load(open(p))
except Exception: d = {}
e = d.get(img, {})
if hexv: e[slot] = hexv.lower()
else: e.pop(slot, None)
if e: d[img] = e
else: d.pop(img, None)
json.dump(d, open(p + ".tmp", "w"), indent=1); os.replace(p + ".tmp", p)
PY
        exec "$HOME/.config/glasstty/set-wallpaper.sh" --so-cores ;;
    apply-edits)
        img="${1:-$(current_img)}"
        theme="$(python3 - "$edits" "$img" "$HOME/.cache/wal/colors.json" <<'PY'
import json, os, sys, tempfile
p, img, cur = sys.argv[1:]
try: e = json.load(open(p)).get(img, {})
except Exception: e = {}
if not e: sys.exit(0)
d = json.load(open(cur))
for slot, v in e.items():
    if slot == "background":
        d["special"]["background"] = v
    elif slot == "foreground":
        d["special"]["foreground"] = v; d["special"]["cursor"] = v
        d["colors"]["color7"] = v; d["colors"]["color15"] = v
    else:
        n = int(slot[5:]); d["colors"][slot] = v
        if 1 <= n <= 6: d["colors"]["color%d" % (n + 8)] = v   # its bright twin
fd, out = tempfile.mkstemp(suffix=".json", prefix="wal-edit-")
json.dump(d, os.fdopen(fd, "w"), indent=2)
print(out)
PY
)"
        [ -n "$theme" ] || exit 0
        wal --theme "$theme" -n -q -s -t; rc=$?
        rm -f "$theme"; exit $rc ;;
    set)
        id="$1"; img="${2:-$(current_img)}"; [ -f "$img" ] || exit 1
        # A new variant starts clean: edits made on the previous one go.
        python3 -c 'import json,os,sys
p,img=sys.argv[1:]
try: d=json.load(open(p))
except Exception: sys.exit(0)
if img in d:
    d.pop(img); json.dump(d,open(p+".tmp","w"),indent=1); os.replace(p+".tmp",p)' "$edits" "$img"
        mkdir -p "$(dirname "$state")"
        python3 - "$state" "$img" "$id" <<'PY'
import json, os, sys
p, img, i = sys.argv[1:]
try: d = json.load(open(p))
except Exception: d = {}
if i == "padrao": d.pop(img, None)
else: d[img] = i
json.dump(d, open(p + ".tmp", "w"), indent=1); os.replace(p + ".tmp", p)
PY
        exec "$HOME/.config/glasstty/set-wallpaper.sh" --so-cores ;;
    *) echo "usage: $0 gen|choice|file|set|edit|edits|apply-edits" >&2; exit 1 ;;
esac
