#!/usr/bin/env bash
# displaymode.sh — how the laptop screen and an external one (TV, monitor)
# share the picture. The notch's display menu (DisplayPanel.qml, Mod+P) calls it.
#
#   displaymode.sh status     prints the current mode: internal | extend |
#                             mirror | external, or "none" with no external screen
#   displaymode.sh internal   only the laptop screen
#   displaymode.sh extend     both, each with its own windows
#   displaymode.sh mirror     the external screen shows the laptop's
#   displaymode.sh external   only the external screen
#
# niri cannot mirror outputs by itself: mirror runs wl-mirror fullscreen on the
# external output, copying the laptop's. The laptop screen is the first eDP /
# LVDS / DSI output; the external one is the first other output niri knows.
set -u

read -r int ext int_on ext_on < <(niri msg -j outputs | python3 -I -c '
import json, sys
d = json.load(sys.stdin)
names = sorted(d)
inner = [n for n in names if n.startswith(("eDP", "LVDS", "DSI"))]
outer = [n for n in names if n not in inner]
i = inner[0] if inner else "-"
e = outer[0] if outer else "-"
on = lambda n: "1" if n in d and d[n].get("logical") is not None else "0"
print(i, e, on(i), on(e))
')

mirroring() { pgrep -x wl-mirror >/dev/null; }
stop_mirror() { pkill -x wl-mirror 2>/dev/null; true; }

if [ "${1:-status}" = status ]; then
    if [ "$ext" = - ]; then echo none
    elif [ "$int_on" = 1 ] && [ "$ext_on" = 0 ]; then echo internal
    elif [ "$int_on" = 0 ]; then echo external
    elif mirroring; then echo mirror
    else echo extend
    fi
    exit 0
fi

if [ "$ext" = - ] || [ "$int" = - ]; then
    # nothing to share with: make sure the laptop screen is on
    stop_mirror
    [ "$int" != - ] && niri msg output "$int" on
    exit 1
fi

case "$1" in
    internal)
        stop_mirror
        niri msg output "$int" on
        niri msg output "$ext" off
        ;;
    extend)
        stop_mirror
        niri msg output "$int" on
        niri msg output "$ext" on
        ;;
    mirror)
        niri msg output "$int" on
        niri msg output "$ext" on
        if ! mirroring; then
            setsid -f wl-mirror --fullscreen-output "$ext" "$int" >/dev/null 2>&1
            sleep 0.6
        fi
        # you keep working on the laptop; the external screen only shows it
        niri msg action focus-monitor "$int"
        ;;
    external)
        stop_mirror
        niri msg output "$ext" on
        niri msg output "$int" off
        ;;
    *)
        echo "usage: $0 status|internal|extend|mirror|external" >&2
        exit 2
        ;;
esac
