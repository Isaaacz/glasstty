#!/bin/sh
# wm.sh — the few compositor questions the scripts ask, for Hyprland AND niri.
# Source it:  . "$HOME/.config/glasstty/scripts/wm.sh"
#
# Under niri every `hyprctl` call is either translated here or skipped by the
# caller (`wm_is_niri && exit 0` for Hyprland-only toys: shaders, plugins,
# animation curves).

wm_is_niri() { [ -n "$NIRI_SOCKET" ]; }

# Name of the output with the focus ("eDP-1"), empty if unknown.
wm_focused_output() {
    if wm_is_niri; then
        niri msg --json focused-output 2>/dev/null | jq -r '.name // empty' 2>/dev/null
    else
        hyprctl monitors -j 2>/dev/null | jq -r 'first(.[] | select(.focused) | .name) // empty' 2>/dev/null
    fi
}

# "NAME WIDTH HEIGHT" per lit output, logical pixels.
wm_outputs() {
    if wm_is_niri; then
        niri msg --json outputs 2>/dev/null \
            | jq -r '.[] | select(.logical) | "\(.name) \(.logical.width) \(.logical.height)"'
    else
        hyprctl monitors -j 2>/dev/null \
            | jq -r '.[] | "\(.name) \((.width / .scale) | floor) \((.height / .scale) | floor)"'
    fi
}

# Re-read the compositor config. niri watches its files and reloads by itself;
# the explicit call is harmless and makes colour changes immediate.
wm_reload() {
    if wm_is_niri; then
        niri msg action load-config-file >/dev/null 2>&1 || true
    else
        hyprctl reload >/dev/null 2>&1 || true
    fi
}

wm_dpms_on() {
    if wm_is_niri; then niri msg action power-on-monitors >/dev/null 2>&1
    else hyprctl dispatch 'hl.dsp.dpms("on")' >/dev/null 2>&1; fi
}

# Workspace (number) holding the first window whose class/app-id matches $1.
wm_workspace_of_class() {
    if wm_is_niri; then
        niri msg --json windows 2>/dev/null | jq -r --arg c "$1" '
            first(.[] | select(.app_id == $c) | .workspace_id) // empty' \
        | { read -r wid || exit 0
            niri msg --json workspaces | jq -r --argjson w "$wid" 'first(.[] | select(.id == $w) | .idx) // empty'; }
    else
        hyprctl clients -j 2>/dev/null | jq -r --arg c "$1" 'first(.[] | select(.class == $c) | .workspace.id) // empty'
    fi
}
