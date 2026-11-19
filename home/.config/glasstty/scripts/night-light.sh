#!/usr/bin/env bash
# Toggle night light. Off = normal temperature.
# Hyprland: hyprsunset. niri (or anywhere without hyprsunset): wlsunset, held at
# 4000K all day — the "sunrise" a minute before midnight and "sunset" at
# midnight leave it in night mode practically always.
#
# Notifications go through tr_() so they follow the rice's language, as lang.sh
# requires (its header used this very script as the example, and yet it was
# one of the nine that did not use it). If lang.sh were not there, the `||`
# leaves a tr_ that returns the Spanish: never extra text, and never, ever
# blank text.
. "$HOME/.config/glasstty/scripts/lang.sh" 2>/dev/null || tr_() { printf '%s' "$1"; }
if pgrep -x 'hyprsunset|wlsunset' >/dev/null; then
    pkill -x hyprsunset; pkill -x wlsunset
    notify-send -t 1500 "󰌵 $(tr_ 'Luz nocturna' 'Night light')" "$(tr_ 'Desactivada' 'Off')"
else
    if [ -z "$NIRI_SOCKET" ] && command -v hyprsunset >/dev/null; then
        hyprsunset -t 4000 >/dev/null 2>&1 &
    else
        setsid wlsunset -t 4000 -T 4001 -S 23:59 -s 00:00 -d 60 >/dev/null 2>&1 &
    fi
    notify-send -t 1500 "󰃝 $(tr_ 'Luz nocturna' 'Night light')" "$(tr_ 'Activada · 4000K' 'On · 4000K')"
fi
