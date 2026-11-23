#!/usr/bin/env bash
# Recolours GTK with the new palette, including the windows ALREADY OPEN.
#
# THE PROBLEM, AND WHY THIS SCRIPT IS THE WAY IT IS
#
# pywal writes ~/.cache/wal/colors-gtk.css and that is where its job ends. The
# GTK applications that are already open do not notice: they resolved their CSS
# once, at startup. So far, nothing new.
#
# What does NOT work, all measured with colour probes and grim captures of a
# Thunar window in front:
#
#   * Touching the gtk.css files, or rewriting them IN PLACE keeping the inode
#     (the trick that DOES work with qt5ct/qt6ct in qt-pywal.py): GTK3 does not
#     watch its gtk.css. The statusbar stayed magenta after changing it to green.
#   * The appearance-portal nudge -- setting color-scheme to prefer-light and
#     back --, which is what this script used to do: no luck either. It was
#     written in the belief that it rebuilt the whole cascade, and in this GTK3
#     version it does not read anything from disk again.
#   * Nudging gtk-theme-name to the same old theme: nothing. GTK caches themes
#     BY NAME inside the process and hands back the cached one.
#
# What DOES work, and what this script lives on: giving it a name that process
# has never seen. Then there is no cache entry, GTK reads it from disk and
# repaints the open window. Hence `pywal-gtk-<hash>`: the hash comes from the
# palette (and from the rules), so every wallpaper with new colours gets a
# fresh name, and a wallpaper that gives the same colours does not get one --
# nor does it need to. The same goes for the icon theme, which folders-pywal.py
# generates.
#
# The theme is assembled from three pieces: it imports adw-gtk3-dark, embeds
# the palette's colours, and appends ~/.config/gtk-3.0/rice-gtk3.css, which is
# where the shapes and timings live and the only thing edited by hand.
#
# And MIND ~/.config/gtk-3.0/gtk.css: it has to stay EMPTY. The user CSS
# overrides the theme (USER priority) and is never reloaded, so with the pywal
# colours in there the open window keeps the previous wallpaper's colours for
# ever, even when the new theme went in fine. That was exactly the second bug
# of this round: the theme said #0B1018 and the view was still on #191612.
set -uo pipefail

CACHE="$HOME/.cache/wal/colors.json"
[ -r "$CACHE" ] || exit 0
command -v gsettings >/dev/null 2>&1 || exit 0

TEMAS="$HOME/.local/share/themes"
BASE_GTK3=/usr/share/themes/adw-gtk3-dark/gtk-3.0/gtk.css
BASE_GTK4=/usr/share/themes/adw-gtk3-dark/gtk-4.0/gtk.css
REGLAS="$HOME/.config/gtk-3.0/rice-gtk3.css"
COLORES="$HOME/.cache/wal/colors-gtk.css"
ACENTO4="$HOME/.cache/wal/colors-gtk4-accent.css"

# --- 1) the folder icons; the script returns its theme's name ---
# The rice decides (quickshell-rice.json): tintFolders=false leaves the chosen
# icon theme as it is, so pywal-icons points straight at it.
TINT=$(python3 -c 'import json,os
try: d=json.load(open(os.path.expanduser("~/.config/quickshell-rice.json")))
except Exception: d={}
print("on" if d.get("tintFolders", True) else "off", d.get("iconTheme","") or "-")' 2>/dev/null || echo "on -")
BASE_ICONES="${TINT#* }"; TINT="${TINT%% *}"
ICONOS=""
if [ "$TINT" = on ] && [ -x "$HOME/.config/glasstty/scripts/folders-pywal.py" ]; then
	ICONOS=$("$HOME/.config/glasstty/scripts/folders-pywal.py" 2>/dev/null | tail -1)
fi
# Fixed name for niri's session (dconf-niri.sh): new windows get the new icons.
#
# Open windows too, through a nudge. GTK re-stats its icon theme folders on
# the next icon lookup (at most every 5 s) and, seeing pywal-icons point at a
# new folder, reloads the theme and tells every widget (Nautilus redraws all its
# folders). An idle app makes no lookups, so something must ask for one:
# rewriting the GTK bookmarks file with its own bytes makes every open file
# sidebar (Nautilus, file choosers) rebuild, which looks icons up. The content
# does not change. Done twice, the second time past GTK's 5 s throttle.
cutucar_icones() {
	local b="$HOME/.config/gtk-3.0/bookmarks" t
	[ -f "$b" ] || return 0
	t=$(mktemp) || return 0
	cat "$b" > "$t" && [ -s "$t" ] && cat "$t" > "$b"
	rm -f "$t"
}
if [ -n "$ICONOS" ] && [ -d "$HOME/.local/share/icons/$ICONOS" ]; then
	antes=$(readlink "$HOME/.local/share/icons/pywal-icons" 2>/dev/null)
	ln -sfn "$ICONOS" "$HOME/.local/share/icons/pywal-icons"
	if [ "$antes" != "$ICONOS" ]; then
		cutucar_icones
		( sleep 6; cutucar_icones ) >/dev/null 2>&1 &
	fi
elif [ "$TINT" = off ]; then
	[ "$BASE_ICONES" = - ] && BASE_ICONES=$(env -u DCONF_PROFILE gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
	for d in "$HOME/.local/share/icons" "$HOME/.icons" /usr/share/icons; do
		if [ -f "$d/$BASE_ICONES/index.theme" ]; then ln -sfn "$d/$BASE_ICONES" "$HOME/.local/share/icons/pywal-icons"; break; fi
	done
fi

# --- 2) the GTK theme, with the palette's hash in the name ---
# The hash covers the colours AND the rules: that way, editing rice-gtk3.css by
# hand also gets a fresh name and the change shows without restarting anything.
FIRMA=$( { jq -r '[.colors[]] | join("")' "$CACHE" 2>/dev/null; cat "$REGLAS" 2>/dev/null; } \
	| md5sum | cut -c1-8)
[ -n "$FIRMA" ] || exit 0
TEMA="pywal-gtk-$FIRMA"
DIR="$TEMAS/$TEMA"

# It is always regenerated, not only when missing: it costs nothing, and that way
# a theme left half-written by an interruption fixes itself.
mkdir -p "$DIR/gtk-3.0" "$DIR/gtk-4.0" || exit 0

# The colours are EMBEDDED and not pulled in by @import: the theme has to be
# self-contained, because its name promises specific colours. If it imported
# ~/.cache/wal/colors-gtk.css, the theme of an old palette would show the new
# palette's colours and the hash would stop meaning anything.
#
# The rules are APPENDED and not imported either: in CSS an @import only counts
# at the start of the file, and after the @define-color lines above GTK throws
# it away without applying a single rule.
# ── glasstty: translucent apps (niri session only) ──────────────────
# Only the BACKGROUNDS get alpha (window, file views, sidebar, header bar);
# text and icons stay fully opaque, and niri blurs what is behind each window
# (window-rule in config.kdl), like the terminal. Menus and dialogs stay
# almost opaque so they read over anything. This theme is used only through
# GTK_THEME in the niri session, so GNOME is not affected.
# Turn off with: touch ~/.config/pocket-dots/gtk-opaque
vidro() {   # vidro gtk3|gtk4
	[ -f "$HOME/.config/pocket-dots/gtk-opaque" ] && return 0
	local bg r g b
	bg=$(jq -r '.special.background' "$CACHE" 2>/dev/null) || return 0
	[ -n "$bg" ] || return 0
	r=$((16#${bg:1:2})); g=$((16#${bg:3:2})); b=$((16#${bg:5:2}))
	a() { printf 'rgba(%d, %d, %d, %s)' "$r" "$g" "$b" "$1"; }
	printf '\n/* translucent backgrounds (gtk-pywal.sh, glasstty) */\n'
	printf '@define-color window_bg_color %s;\n'    "$(a 0.80)"
	printf '@define-color view_bg_color %s;\n'      "$(a 0.66)"
	printf '@define-color headerbar_bg_color %s;\n' "$(a 0.74)"
	# Sidebar: transparent. Its colour is painted OVER the window's (which is
	# already translucent), so any alpha here stacks up and the sidebar came out
	# darker and more opaque than the file view next to it (0.86 vs 0.66).
	printf '@define-color sidebar_bg_color %s;\n'   "transparent"
	printf '@define-color card_bg_color %s;\n'      "$(a 0.50)"
	printf '@define-color popover_bg_color %s;\n'   "$(a 0.94)"
	printf '@define-color dialog_bg_color %s;\n'    "$(a 0.92)"
	if [ "$1" = gtk4 ]; then
		# libadwaita >= 1.6 reads these as CSS variables.
		printf ':root {\n'
		printf '  --window-bg-color: %s;\n'    "$(a 0.80)"
		printf '  --view-bg-color: %s;\n'      "$(a 0.66)"
		printf '  --headerbar-bg-color: %s;\n' "$(a 0.74)"
		printf '  --sidebar-bg-color: %s;\n'   "transparent"
		printf '  --secondary-sidebar-bg-color: %s;\n' "transparent"
		# Unfocused windows use the *backdrop* colours: without these the
		# sidebar and header fell back to libadwaita's opaque grey.
		printf '  --sidebar-backdrop-color: %s;\n' "transparent"
		printf '  --secondary-sidebar-backdrop-color: %s;\n' "transparent"
		printf '  --headerbar-backdrop-color: %s;\n' "$(a 0.74)"
		printf '  --card-bg-color: %s;\n'      "$(a 0.50)"
		printf '  --popover-bg-color: %s;\n'   "$(a 0.94)"
		printf '  --dialog-bg-color: %s;\n'    "$(a 0.92)"
		printf '}\n'
	else
		# GTK3 (Thunar...): the window and the file area paint their own
		# backgrounds from these classes.
		printf 'window, .background { background-color: @window_bg_color; }\n'
		printf '.view, iconview, treeview.view { background-color: @view_bg_color; }\n'
		printf '.sidebar, placessidebar, .sidebar .view { background-color: @sidebar_bg_color; }\n'
		printf 'window:backdrop, .background:backdrop { background-color: @window_bg_color; }\n'
		printf '.sidebar:backdrop, placessidebar:backdrop, .sidebar .view:backdrop { background-color: @sidebar_bg_color; }\n'
	fi
}

{
	printf '/* Generated by gtk-pywal.sh on each wallpaper change. Do not edit:\n'
	printf '   edit the rules in ~/.config/gtk-3.0/rice-gtk3.css. */\n'
	printf '@import url("file://%s");\n' "$BASE_GTK3"
	[ -r "$COLORES" ] && cat "$COLORES"
	[ -r "$REGLAS" ] && cat "$REGLAS"
	vidro gtk3
} > "$DIR/gtk-3.0/gtk.css"

# GTK4 goes separately because libadwaita needs its accent via :root. It
# replicates what ~/.config/gtk-4.0/gtk.css already did, so that changing the
# theme name takes nothing away from GTK4 applications.
{
	printf '/* Generated by gtk-pywal.sh. */\n'
	printf '@import url("file://%s");\n' "$BASE_GTK4"
	[ -r "$COLORES" ] && cat "$COLORES"
	[ -r "$ACENTO4" ] && cat "$ACENTO4"
	vidro gtk4
} > "$DIR/gtk-4.0/gtk.css"

printf '[Desktop Entry]\nType=X-GNOME-Metatheme\nName=%s\nComment=adw-gtk3-dark with the pywal palette (generated)\nComment[es]=adw-gtk3-dark con la paleta de pywal (generado)\n' \
	"$TEMA" > "$DIR/index.theme"

# --- 3) apply it ---
# gsettings is what reaches the OPEN windows, through the settings portal.
# The settings.ini files are for the ones opened later.
# ── niri fork: do NOT touch what GNOME reads ──────────────────────────────
# gsettings (dconf) and ~/.config/gtk-*/settings.ini are shared with the GNOME
# session on this machine: writing them here would re-theme GNOME on every
# wallpaper change. So by default only a stable link is updated:
#   ~/.local/share/themes/pywal-gtk -> pywal-gtk-<hash>
# and niri's config.kdl sets GTK_THEME=pywal-gtk for its session only.
# POCKET_GTK_GLOBAL=1 restores the original global behaviour below.
TEMA_ANTES=$(readlink "$TEMAS/pywal-gtk" 2>/dev/null)
ln -sfn "$TEMA" "$TEMAS/pywal-gtk"
# Open GTK windows in the niri session restyle LIVE: GTK reloads its theme
# from disk when the gtk-theme setting changes, and the portal relays that
# change to every app. The niri session pins the theme with GTK_THEME, so the
# value itself is ignored there: it is flipped to another theme name for a
# moment and put back EXACTLY as it was, only as the signal to reload. GNOME's
# value ends up untouched, and this only runs inside niri (GNOME is not running
# then).
# The flip goes to Adwaita-dark when the value IS Adwaita (Fedora's default):
# flipping Adwaita to Adwaita changes nothing and no window repainted. Runs
# take turns through a lock, so one never reads another's temporary value.
if [ "$TEMA_ANTES" != "$TEMA" ] && [ -n "${NIRI_SOCKET:-}" ]; then
	(
		exec 9>"${XDG_RUNTIME_DIR:-/tmp}/gtk-pywal-flip.lock"
		flock -w 5 9 || exit 0
		t=$(env -u DCONF_PROFILE gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null) || exit 0
		[ -n "$t" ] || exit 0
		if [ "$t" = "'Adwaita'" ]; then other="'Adwaita-dark'"; else other="'Adwaita'"; fi
		env -u DCONF_PROFILE gsettings set org.gnome.desktop.interface gtk-theme "$other" 2>/dev/null
		sleep 0.3
		env -u DCONF_PROFILE gsettings set org.gnome.desktop.interface gtk-theme "$t" 2>/dev/null
	) >/dev/null 2>&1 &
fi
if [ "${POCKET_GTK_GLOBAL:-0}" = 1 ]; then
	gsettings set org.gnome.desktop.interface gtk-theme "$TEMA" 2>/dev/null || true
	[ -n "$ICONOS" ] && { gsettings set org.gnome.desktop.interface icon-theme "$ICONOS" 2>/dev/null || true; }

	fijar() { # fijar <file> <key> <value>
		local f="$1" k="$2" v="$3"
		[ -f "$f" ] || return 0
		if grep -q "^${k}=" "$f"; then
			sed -i "s|^${k}=.*|${k}=${v}|" "$f"
		else
			printf '%s=%s\n' "$k" "$v" >> "$f"
		fi
	}

	fijar "$HOME/.config/gtk-3.0/settings.ini" gtk-theme-name "$TEMA"
	fijar "$HOME/.config/gtk-4.0/settings.ini" gtk-theme-name "$TEMA"
	if [ -n "$ICONOS" ]; then
		fijar "$HOME/.config/gtk-3.0/settings.ini" gtk-icon-theme-name "$ICONOS"
		fijar "$HOME/.config/gtk-4.0/settings.ini" gtk-icon-theme-name "$ICONOS"
		# GTK2 uses another format (values in quotes) and on top of that nwg-look
		# rewrites it, so only the icons are changed there: the generated theme has
		# no gtk-2.0 and pointing it there would leave it without a theme.
		if [ -f "$HOME/.gtkrc-2.0" ]; then
			sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=\"${ICONOS}\"|" "$HOME/.gtkrc-2.0"
		fi
	fi

	# --- 4) out with the themes of previous palettes ---
	# The current one is NEVER deleted: it is the one the settings.ini files point
	# to, and if it disappears, applications opened later fall back to stock Adwaita.
fi

for otro in "$TEMAS"/pywal-gtk-*; do
	[ -d "$otro" ] || continue
	[ "$(basename "$otro")" = "$TEMA" ] && continue
	rm -rf -- "$otro"
done

exit 0
