#!/usr/bin/env python3
"""palette-override.py — manual colours on top of the wallpaper's palette.

Runs right after pywal in set-wallpaper.sh. When Settings > Aparência > Cores
is on "Manual" (colorMode in ~/.config/quickshell-rice.json), it replaces the
accent (and optionally the background) in pywal's palette and hands the result
back to pywal with `wal -f`. pywal then rewrites colors.json and EVERY template
(shell, niri borders, login/lock thyx colours, GTK, kitty...), so the whole
desktop follows the chosen colours exactly as it follows a wallpaper.

"Do wallpaper" mode: does nothing (the palette stays pywal's).
"""

import colorsys
import json
import os
import subprocess
import sys

HOME = os.path.expanduser("~")
RICE = os.path.join(HOME, ".config", "quickshell-rice.json")
WAL = os.path.join(HOME, ".cache", "wal", "colors.json")
OUT_DIR = os.path.join(HOME, ".cache", "pocket-dots")
OUT = os.path.join(OUT_DIR, "palette.json")


def hex_to_rgb(h):
    h = h.strip().lstrip("#")
    if len(h) == 8:          # #AARRGGBB from Qt: drop alpha
        h = h[2:]
    if len(h) != 6:
        raise ValueError(h)
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def rgb_to_hex(rgb):
    return "#" + "".join(f"{max(0, min(255, round(c * 255))):02x}" for c in rgb)


def shift(h, dl=0.0, ds=0.0):
    """Lighter/darker (dl) and more/less saturated (ds), in HLS."""
    r, g, b = hex_to_rgb(h)
    hh, ll, ss = colorsys.rgb_to_hls(r, g, b)
    return rgb_to_hex(colorsys.hls_to_rgb(hh, max(0, min(1, ll + dl)), max(0, min(1, ss + ds))))


def lum(h):
    r, g, b = hex_to_rgb(h)
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def main():
    try:
        with open(RICE, encoding="utf-8") as f:
            rice = json.load(f)
    except (OSError, ValueError):
        return 0
    if rice.get("colorMode") != "manual":
        return 0

    with open(WAL, encoding="utf-8") as f:
        pal = json.load(f)
    c, s = pal["colors"], pal["special"]

    accent = str(rice.get("manualAccent") or "").strip()
    if accent:
        try:
            hex_to_rgb(accent)
        except ValueError:
            accent = ""
    if accent:
        accent = rgb_to_hex(hex_to_rgb(accent))
        c["color4"] = accent
        c["color12"] = shift(accent, 0.10)
        c["color6"] = shift(accent, 0.12, 0.05)   # hover / second accent
        c["color14"] = shift(accent, 0.20)

    bg = str(rice.get("manualBg") or "").strip()
    if bg:
        try:
            bg = rgb_to_hex(hex_to_rgb(bg))
        except ValueError:
            bg = ""
    if bg:
        dark = lum(bg) < 0.18
        s["background"] = bg
        c["color0"] = bg
        c["color8"] = shift(bg, 0.22 if dark else -0.22)
        # Keep the text readable on the chosen background.
        if dark and lum(s["foreground"]) < 0.45:
            s["foreground"] = c["color7"] = c["color15"] = "#e6e6e6"
        if not dark and lum(s["foreground"]) > 0.35:
            s["foreground"] = c["color7"] = c["color15"] = "#1b1b1b"
        s["cursor"] = s["foreground"]

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(pal, f, indent=4)

    # -n: do not set the wallpaper; -s/-t: no terminal sequences; -q: quiet.
    r = subprocess.run(["wal", "-f", OUT, "-n", "-q", "-s", "-t"])
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())
