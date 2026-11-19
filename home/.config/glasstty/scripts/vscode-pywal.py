#!/usr/bin/env python3
# VS Code in the wallpaper's colours (this fork).
#
# Writes two keys of ~/.config/Code/User/settings.json from the pywal palette:
#   workbench.colorCustomizations     the interface (sidebar, tabs, panels...)
#   editor.tokenColorCustomizations   the syntax colours
# VS Code applies settings changes live, so an open window changes colour with
# the wallpaper, no reload. The rest of settings.json is left as it is.
#
# Same layering as the Spotify theme (spicetify-catppuccin.py): the editor is
# the base, the sidebar and panels a step darker, the activity/title/status
# bars the darkest; selections and hovers step up; the accent and the syntax
# colours are the palette's colours lifted to soft pastels so they read on the
# dark base.
#
# Safety: settings.json may have comments (JSONC). If it does not parse as
# plain JSON this does nothing rather than risk rewriting it. And it only takes
# over the two keys if they are absent or were written here before
# (~/.cache/pocket-dots/vscode-owned), so customisations of your own are kept.
#
#   vscode-pywal.py         apply the current palette
#   vscode-pywal.py --off   remove the two keys (back to the plain theme)
import colorsys
import json
import os
import sys

HOME = os.path.expanduser("~")
SETTINGS = os.environ.get("POCKET_VSCODE_SETTINGS",
                          os.path.join(HOME, ".config/Code/User/settings.json"))
OWNED = os.path.join(HOME, ".cache/pocket-dots/vscode-owned")
KEYS = ("workbench.colorCustomizations", "editor.tokenColorCustomizations")

if not os.path.exists(SETTINGS):
    sys.exit(0)                       # VS Code never opened: nothing to theme
try:
    raw = open(SETTINGS).read()
    cfg = json.loads(raw) if raw.strip() else {}
except (OSError, ValueError):
    sys.stderr.write("vscode-pywal: settings.json is not plain JSON, left alone\n")
    sys.exit(0)

owned = os.path.exists(OWNED)
if not owned and any(k in cfg for k in KEYS):
    sys.stderr.write("vscode-pywal: colour customisations of your own found, left alone\n")
    sys.exit(0)


def write(cfg):
    # Through the link if settings.json is one (Settings Sync, dotfiles).
    real = os.path.realpath(SETTINGS)
    tmp = real + ".pocket.tmp"
    with open(tmp, "w") as fh:
        json.dump(cfg, fh, indent=4, ensure_ascii=False)
        fh.write("\n")
    os.replace(tmp, real)


# One copy of the file as it was before this script ever touched it.
BACKUP = os.path.join(HOME, ".cache/pocket-dots/vscode-settings.antes.json")
if not owned and not os.path.exists(BACKUP):
    os.makedirs(os.path.dirname(BACKUP), exist_ok=True)
    open(BACKUP, "w").write(raw)


if "--off" in sys.argv:
    for k in KEYS:
        cfg.pop(k, None)
    write(cfg)
    try:
        os.remove(OWNED)
    except OSError:
        pass
    sys.exit(0)

try:
    d = json.load(open(os.path.join(HOME, ".cache/wal/colors.json")))
except (OSError, ValueError):
    sys.exit(0)
sp, c = d["special"], d["colors"]


def hls(h):
    h = h.lstrip("#")
    return colorsys.rgb_to_hls(*(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)))


def hx(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h % 1, max(0, min(1, l)), max(0, min(1, s)))
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


bh, bl, bs = hls(sp["background"])
bs = min(bs, 0.35)
bl = min(max(bl, 0.07), 0.16)


def layer(dl, ds=0.0):
    return hx(bh, bl + dl, bs * (1 - ds))


def chroma(hexa):
    _, l, s = hls(hexa)
    return s * (1 - abs(2 * l - 1))


acc = c["color4"] if hls(c["color4"])[2] >= 0.25 else \
    max((c[f"color{i}"] for i in range(1, 7)), key=chroma)
ah = hls(acc)[0]


def pastel(hexa, l=0.78, smin=0.45, smax=0.85):
    h, _, s = hls(hexa)
    if s < 0.15:
        h, s = ah, 0.6
    return hx(h, l, min(smax, max(smin, s)))


accent = pastel(acc, 0.78)
fh, fl, fs = hls(sp["foreground"])
text = hx(fh, max(fl, 0.86), min(fs, 0.2))
sub = hx(fh, 0.68, min(fs, 0.15))
mute = layer(0.32, 0.3)
base, mantle, crust = layer(0), layer(-0.025), layer(-0.045)
s0, s1, s2 = layer(0.06), layer(0.11), layer(0.16, 0.1)
red, green, yellow = pastel(c["color1"]), pastel(c["color2"]), pastel(c["color3"])
blue, mauve, teal = pastel(c["color4"]), pastel(c["color5"]), pastel(c["color6"])
peach = pastel(c["color3"], 0.72)
ink = "#111111" if (lambda h, l, s: l)(*hls(accent)) > 0.55 else "#ffffff"

ui = {
    "focusBorder": accent + "aa",
    "foreground": sub,
    "descriptionForeground": sub,
    "icon.foreground": sub,
    "widget.shadow": crust + "aa",
    "selection.background": accent + "44",
    "textLink.foreground": accent,
    "textLink.activeForeground": accent,
    "button.background": accent,
    "button.foreground": ink,
    "button.hoverBackground": pastel(acc, 0.84),
    "button.secondaryBackground": s1,
    "button.secondaryForeground": text,
    "badge.background": accent,
    "badge.foreground": ink,
    "activityBarBadge.background": accent,
    "activityBarBadge.foreground": ink,
    "titleBar.activeBackground": crust,
    "titleBar.inactiveBackground": crust,
    "titleBar.activeForeground": text,
    "titleBar.inactiveForeground": mute,
    "titleBar.border": crust,
    "activityBar.background": crust,
    "activityBar.foreground": accent,
    "activityBar.inactiveForeground": mute,
    "activityBar.activeBorder": accent,
    "activityBar.border": crust,
    "sideBar.background": mantle,
    "sideBar.foreground": sub,
    "sideBar.border": mantle,
    "sideBarTitle.foreground": text,
    "sideBarSectionHeader.background": mantle,
    "sideBarSectionHeader.foreground": text,
    "sideBarSectionHeader.border": mantle,
    "list.hoverBackground": s0,
    "list.activeSelectionBackground": s1,
    "list.activeSelectionForeground": text,
    "list.inactiveSelectionBackground": s0,
    "list.focusOutline": accent + "88",
    "list.highlightForeground": accent,
    "tree.indentGuidesStroke": s1,
    "editorGroupHeader.tabsBackground": mantle,
    "editorGroupHeader.tabsBorder": mantle,
    "editorGroup.border": crust,
    "tab.activeBackground": base,
    "tab.activeForeground": text,
    "tab.inactiveBackground": mantle,
    "tab.inactiveForeground": mute,
    "tab.border": mantle,
    "tab.activeBorderTop": accent,
    "tab.hoverBackground": s0,
    "breadcrumb.background": base,
    "breadcrumb.foreground": mute,
    "breadcrumb.focusForeground": text,
    "editor.background": base,
    "editor.foreground": text,
    "editorLineNumber.foreground": mute,
    "editorLineNumber.activeForeground": accent,
    "editorCursor.foreground": accent,
    "editor.lineHighlightBackground": layer(0.03),
    "editor.lineHighlightBorder": "#00000000",
    "editor.selectionBackground": accent + "40",
    "editor.inactiveSelectionBackground": accent + "22",
    "editor.selectionHighlightBackground": accent + "22",
    "editor.wordHighlightBackground": accent + "22",
    "editor.findMatchBackground": yellow + "55",
    "editor.findMatchHighlightBackground": yellow + "28",
    "editorIndentGuide.background1": s0,
    "editorIndentGuide.activeBackground1": s2,
    "editorWhitespace.foreground": s1,
    "editorBracketMatch.background": accent + "22",
    "editorBracketMatch.border": accent + "88",
    "editorWidget.background": mantle,
    "editorWidget.border": s1,
    "editorSuggestWidget.background": mantle,
    "editorSuggestWidget.border": s1,
    "editorSuggestWidget.selectedBackground": s1,
    "editorSuggestWidget.highlightForeground": accent,
    "editorHoverWidget.background": mantle,
    "editorHoverWidget.border": s1,
    "editorError.foreground": red,
    "editorWarning.foreground": yellow,
    "editorInfo.foreground": blue,
    "editorGutter.addedBackground": green,
    "editorGutter.modifiedBackground": blue,
    "editorGutter.deletedBackground": red,
    "minimap.background": base,
    "scrollbarSlider.background": s1 + "88",
    "scrollbarSlider.hoverBackground": s2 + "aa",
    "scrollbarSlider.activeBackground": accent + "66",
    "input.background": s0,
    "input.foreground": text,
    "input.border": s1,
    "input.placeholderForeground": mute,
    "inputOption.activeBorder": accent,
    "dropdown.background": s0,
    "dropdown.border": s1,
    "dropdown.foreground": text,
    "checkbox.background": s0,
    "checkbox.border": s1,
    "quickInput.background": mantle,
    "quickInputList.focusBackground": s1,
    "commandCenter.background": s0,
    "commandCenter.border": s1,
    "commandCenter.foreground": sub,
    "menu.background": mantle,
    "menu.foreground": text,
    "menu.selectionBackground": s1,
    "menu.separatorBackground": s1,
    "panel.background": mantle,
    "panel.border": crust,
    "panelTitle.activeForeground": text,
    "panelTitle.inactiveForeground": mute,
    "panelTitle.activeBorder": accent,
    "statusBar.background": crust,
    "statusBar.foreground": sub,
    "statusBar.border": crust,
    "statusBar.noFolderBackground": crust,
    "statusBar.debuggingBackground": peach,
    "statusBar.debuggingForeground": "#111111",
    "statusBarItem.remoteBackground": accent,
    "statusBarItem.remoteForeground": ink,
    "statusBarItem.hoverBackground": s0,
    "statusBarItem.prominentBackground": accent,
    "statusBarItem.prominentForeground": ink,
    "banner.background": s1,
    "banner.foreground": text,
    "notifications.background": mantle,
    "notifications.border": s1,
    "notificationCenterHeader.background": crust,
    "peekView.border": accent,
    "peekViewEditor.background": mantle,
    "peekViewResult.background": crust,
    "peekViewTitle.background": crust,
    "gitDecoration.modifiedResourceForeground": blue,
    "gitDecoration.untrackedResourceForeground": green,
    "gitDecoration.deletedResourceForeground": red,
    "gitDecoration.ignoredResourceForeground": mute,
    "terminal.background": base,
    "terminal.foreground": text,
    "terminalCursor.foreground": accent,
    "terminal.selectionBackground": accent + "40",
}
# The terminal keeps pywal's 16 colours, like kitty.
for i, n in enumerate(("Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White")):
    ui["terminal.ansi" + n] = c[f"color{i}"]
    ui["terminal.ansiBright" + n] = c[f"color{i + 8}"]

tokens = {"textMateRules": [
    {"scope": ["comment", "punctuation.definition.comment"], "settings": {"foreground": mute, "fontStyle": "italic"}},
    {"scope": ["keyword", "storage.type", "storage.modifier", "keyword.control"], "settings": {"foreground": mauve}},
    {"scope": ["keyword.operator", "punctuation"], "settings": {"foreground": sub}},
    {"scope": ["string", "string.quoted", "markup.inline.raw"], "settings": {"foreground": green}},
    {"scope": ["constant.character.escape", "string.regexp"], "settings": {"foreground": teal}},
    {"scope": ["constant.numeric", "constant.language", "constant.other"], "settings": {"foreground": peach}},
    {"scope": ["entity.name.function", "support.function", "meta.function-call.generic"], "settings": {"foreground": blue}},
    {"scope": ["entity.name.type", "entity.name.class", "support.type", "support.class", "entity.other.inherited-class"], "settings": {"foreground": yellow}},
    {"scope": ["variable", "meta.definition.variable"], "settings": {"foreground": text}},
    {"scope": ["variable.parameter"], "settings": {"foreground": pastel(c["color1"], 0.84)}},
    {"scope": ["variable.language", "support.variable"], "settings": {"foreground": red}},
    {"scope": ["entity.name.tag"], "settings": {"foreground": blue}},
    {"scope": ["entity.other.attribute-name"], "settings": {"foreground": yellow}},
    {"scope": ["markup.heading", "entity.name.section"], "settings": {"foreground": accent, "fontStyle": "bold"}},
    {"scope": ["invalid"], "settings": {"foreground": red}},
]}

cfg["workbench.colorCustomizations"] = ui
cfg["editor.tokenColorCustomizations"] = tokens
write(cfg)
os.makedirs(os.path.dirname(OWNED), exist_ok=True)
open(OWNED, "w").write("written by vscode-pywal.py\n")
