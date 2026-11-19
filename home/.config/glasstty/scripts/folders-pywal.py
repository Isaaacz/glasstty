#!/usr/bin/env python3
"""Tints the folder icons with the wallpaper's accent.

Adwaita draws all its folders with the same five blues (#438de6, #62a0ea,
#a4caee, #afd4ff, #c0d5ea: a flat fill, a four-stop gradient and a
highlight). That leaves them as the only patch of colour on the desktop that
does NOT move when the wallpaper changes — and on a system where the bar, the
notch, kitty, yazi and Spotify are all recoloured, the blue folder sticks out.

What this does: it generates its own icon theme, `pywal-folders`, which
INHERITS from Adwaita and only replaces the folder*.svg (plus user-home,
user-desktop and user-bookmarks, which are the same folder with a drawing on
top). Everything else -applications, file types, the bin- keeps coming from
Adwaita untouched. If this script disappears, the theme stays as it is; if
the theme is deleted, GTK falls back to Adwaita and nothing breaks.

The tinting keeps each tone's LIGHTNESS and changes its hue. That is the
difference between a folder you can read and a smudge: if the accent colour
were copied as it is, a dark palette would give black folders on a black
background. By keeping the L, the shading Adwaita drew -the flat fill, the
gradient, the highlight- survives intact and only changes colour.

THE NAME CARRIES THE PALETTE'S HASH (`pywal-folders-<hash>`) and it is not a
whim: GTK caches icon themes BY NAME inside each process, so rewriting the
SVGs of a theme the application has already loaded changes nothing --
measured with Thunar in front, the folder kept its old colour after
regenerating the whole theme. With a name GTK does not know, on the other
hand, it reads it from disk, and the OPEN windows pick up the new colour. The
name is printed on standard output, which is what gtk-pywal.sh consumes to
point gsettings at it.

It is called by gtk-pywal.sh, which is what orchestrates the whole GTK
recolouring.
"""

import colorsys
import hashlib
import json
import os
import re
import sys

ORIGEN = "/usr/share/icons/Adwaita/scalable/places"
HEREDA = "Adwaita,AdwaitaLegacy,hicolor"


def tema_base():
    """The icon theme the user picked, from the REAL dconf user database.

    Under niri, DCONF_PROFILE points to a profile that answers `pywal-icons`
    for this key (see dconf-niri.sh), so it is dropped for this one read.
    """
    import subprocess
    env = {k: v for k, v in os.environ.items() if k != "DCONF_PROFILE"}
    try:
        out = subprocess.run(
            ["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"],
            env=env, capture_output=True, text=True, timeout=5,
        ).stdout.strip().strip("'")
    except (OSError, subprocess.SubprocessError):
        return ""
    return out


# Tela (the theme GNOME uses here) draws every folder with one blue, #5294e2,
# plus white symbols. Its colourful variant `Tela` is the source; the black
# variants (Tela-black-dark) paint them grey, which carries no hue to keep.
# The generated theme inherits the user's own theme, so apps and file types
# stay exactly as they were and only the folders change colour.
def tema_do_rice():
    """The icon theme the current rice picked (Ajustes/Central > Rices)."""
    try:
        with open(os.path.expanduser("~/.config/quickshell-rice.json")) as fh:
            return json.load(fh).get("iconTheme", "") or ""
    except (OSError, ValueError):
        return ""


_base = os.environ.get("POCKET_ICON_BASE") or tema_do_rice() or tema_base()
_tela = os.path.expanduser("~/.local/share/icons/Tela/scalable/places")
if _base.startswith("Tela") and os.path.isdir(_tela):
    ORIGEN = _tela
    HEREDA = f"{_base},hicolor"
elif _base and _base != "Adwaita":
    # Any other theme: Adwaita's folders, tinted, over the chosen theme.
    HEREDA = f"{_base},Adwaita,AdwaitaLegacy,hicolor"
# Both paths can be overridden from the environment to try the tinting with a
# made-up palette without touching the real desktop.
BASE = os.environ.get(
    "PYWAL_FOLDERS_DIR", os.path.expanduser("~/.local/share/icons")
)
PALETA = os.environ.get(
    "PYWAL_COLORS", os.path.expanduser("~/.cache/wal/colors.json")
)

# The icons that are "the folder": the folder* ones and the three user-* that
# draw the same piece with a symbol on top. user-trash is left out on purpose
# (it is grey and green, it is not a folder) and so is network-* (they carry
# half a server drawing).
ICONOS = sorted(
    f for f in os.listdir(ORIGEN)
    if f.endswith(".svg") and (
        f.startswith("folder")
        or f in ("user-home.svg", "user-desktop.svg", "user-bookmarks.svg")
        or (ORIGEN != "/usr/share/icons/Adwaita/scalable/places"
            and f.startswith(("user-", "default-folder", "default-user")))
    )
) if os.path.isdir(ORIGEN) else []

# Saturation of Adwaita's main blue (#62a0ea). It is the reference for
# scaling: if the accent is half as saturated, the folders come out half as
# saturated, and the gradient keeps its proportions.
SAT_REFERENCIA = 0.764 if ORIGEN.startswith("/usr/share/icons/Adwaita") else 0.71  # Tela #5294e2

HEX = re.compile(r"#([0-9a-fA-F]{6})\b")


def a_hls(hexa):
    r = int(hexa[0:2], 16) / 255
    g = int(hexa[2:4], 16) / 255
    b = int(hexa[4:6], 16) / 255
    return colorsys.rgb_to_hls(r, g, b)


def a_hex(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h % 1.0, max(0.0, min(1.0, l)), max(0.0, min(1.0, s)))
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def elegir_acento(colores):
    """color4 is the system accent, but it does not always work as a tint.

    Some wallpapers -sand, fog, black and white- give a color4 that is almost
    grey. Tinting with it would give grey folders, which is exactly what we do
    not want: the folder has to be the window's patch of colour. When that
    happens, it looks for the most chromatic tone in the palette, meaning the
    one with the most colour WITHOUT going to the extremes of light or dark
    (there saturation lies: #010204 reads 0.6 and it is black).
    """
    h, l, s = a_hls(colores["color4"].lstrip("#"))
    if s >= 0.25:
        return h, s

    mejor, mejor_punto = (h, s), -1.0
    for i in range(1, 7):
        hh, ll, ss = a_hls(colores[f"color{i}"].lstrip("#"))
        punto = ss * (1 - abs(2 * ll - 1))
        if punto > mejor_punto:
            mejor, mejor_punto = (hh, ss), punto
    return mejor


def main():
    if not ICONOS:
        return 0  # Adwaita is not where it was expected: better to do nothing.
    try:
        with open(PALETA) as fh:
            colores = json.load(fh)["colors"]
    except (OSError, ValueError, KeyError):
        return 0

    h_acento, s_acento = elegir_acento(colores)
    # The hue is copied whole; the saturation is only modulated, between 0.85
    # and 1.25 of Adwaita's. Copying it as it is was the first attempt and it
    # went wrong: a medium-saturation accent (#305e91, 0.50 against the 0.76 of
    # Adwaita's blue) left the folders paler than the originals, greyish over
    # an almost black background. Adwaita's saturation is calibrated so the
    # folder reads; what makes it yours is the hue.
    escala = min(1.25, max(0.85, s_acento / SAT_REFERENCIA))

    # The theme name changes when the palette changes, and only then: if the
    # new wallpaper gives the same colours, the name repeats and there is
    # nothing to reload.
    firma = hashlib.md5(
        ("".join(colores[f"color{i}"] for i in range(16)) + ORIGEN + HEREDA).encode()
    ).hexdigest()[:8]
    nombre_tema = f"pywal-folders-{firma}"
    destino = os.path.join(BASE, nombre_tema)

    destino_svg = os.path.join(destino, "scalable", "places")
    os.makedirs(destino_svg, exist_ok=True)

    def tenir(m):
        h, l, s = a_hls(m.group(1))
        # Only Adwaita's blues (187°-227°) with some colour. That way the
        # script does not touch the shadow greys or an icon that carries
        # something else drawn on it, and it keeps working if Adwaita changes
        # the hue.
        if not (0.52 <= h <= 0.63 and s > 0.15):
            return m.group(0)
        return a_hex(h_acento, l, s * escala)

    for nombre in ICONOS:
        try:
            with open(os.path.join(ORIGEN, nombre)) as fh:
                svg = fh.read()
        except OSError:
            continue  # a dangling symlink in the source theme
        salida = os.path.join(destino_svg, nombre)
        tmp = salida + ".tmp"
        with open(tmp, "w") as fh:
            fh.write(HEX.sub(tenir, svg))
        os.replace(tmp, salida)

    # Without index.theme there is no theme: GTK ignores the whole directory.
    # Hidden=false so it shows up in theme pickers.
    indice = f"""[Icon Theme]
Name={nombre_tema}
Comment=Folders tinted by pywal (generated, do not edit)
Inherits={HEREDA}
Directories=scalable/places
Hidden=false

[scalable/places]
Size=128
MinSize=8
MaxSize=512
Context=Places
Type=Scalable
"""
    ruta_indice = os.path.join(destino, "index.theme")
    with open(ruta_indice + ".tmp", "w") as fh:
        fh.write(indice)
    os.replace(ruta_indice + ".tmp", ruta_indice)

    # icon-theme.cache is NOT generated, on purpose: without it GTK reads the
    # directory, which is thirteen files, and there is no way for a stale
    # cache to win over the freshly written SVGs.
    caduca = os.path.join(destino, "icon-theme.cache")
    if os.path.exists(caduca):
        os.remove(caduca)

    # Out with the themes of previous palettes. Otherwise every new wallpaper
    # leaves a 40 KB directory behind for ever and the icon theme picker fills
    # up with `pywal-folders-*`.
    try:
        for otro in os.listdir(BASE):
            if otro.startswith("pywal-folders-") and otro != nombre_tema:
                ruta = os.path.join(BASE, otro)
                for raiz, _, ficheros in os.walk(ruta, topdown=False):
                    for f in ficheros:
                        os.remove(os.path.join(raiz, f))
                    os.rmdir(raiz)
    except OSError:
        pass  # failing to clean up is no reason to fail

    # The name, on standard output: it is what gtk-pywal.sh puts into
    # gsettings and the settings.ini files.
    print(nombre_tema)
    return 0


if __name__ == "__main__":
    sys.exit(main())
