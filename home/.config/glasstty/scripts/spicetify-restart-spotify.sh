#!/usr/bin/env bash
# Restarts Spotify and puts it back on the workspace it was on, SILENTLY
# (without switching you there). The spicetify-pywal.sh hook calls it in the background.
#   $1 = id of the workspace Spotify was on (empty = do not move it)
set -u

WS="${1:-}"

# close Spotify (SIGTERM; if it resists, SIGKILL)
pkill -x spotify 2>/dev/null
for i in $(seq 1 12); do pgrep -x spotify >/dev/null 2>&1 || break; sleep 0.25; done
pgrep -x spotify >/dev/null 2>&1 && pkill -9 -x spotify 2>/dev/null
sleep 0.3

# relaunch WITH the debugging port, so spicetify-push-colors.py can recolour it
# live next time and there is no need to come through here again.
# (The same flag is in ~/.local/share/applications/spotify.desktop, which covers
# launches from the menu; this line covers this script's.)
FLAGS="--remote-debugging-port=9333 --remote-allow-origins=http://127.0.0.1:9333"
# Lua syntax (Hyprland 0.55+): a bare `exec` is no longer valid Lua. Here the
# failure was quiet because the `|| setsid` next to it caught exit code 7 and
# launched Spotify anyway; what WAS lost was the trip back to its workspace.
if [ -n "$NIRI_SOCKET" ]; then
  niri msg action spawn -- spotify $FLAGS >/dev/null 2>&1 || setsid spotify $FLAGS >/dev/null 2>&1
else
  hyprctl dispatch "hl.dsp.exec_cmd(\"spotify $FLAGS\")" >/dev/null 2>&1 || setsid spotify $FLAGS >/dev/null 2>&1
fi

# put it back on its workspace once the window appears (silent = focus does not move)
[ -n "$WS" ] || exit 0
if [ -n "$NIRI_SOCKET" ]; then
  # niri: wait for the window, then send it by id without moving the focus.
  for i in $(seq 1 40); do
    id="$(niri msg --json windows 2>/dev/null | jq -r 'first(.[] | select(.app_id == "spotify") | .id) // empty')"
    [ -n "$id" ] && break
    sleep 0.5
  done
  [ -n "$id" ] && niri msg action move-window-to-workspace --window-id "$id" --focus false "$WS" >/dev/null 2>&1
  exit 0
fi
for i in $(seq 1 40); do
  hyprctl clients -j 2>/dev/null | grep -q '"class": "Spotify"' && break
  sleep 0.5
done
sleep 0.6
# `follow = false` is the Lua equivalent of movetoworkspacesilent.
hyprctl dispatch "hl.dsp.window.move({ workspace = $WS, follow = false, window = \"class:^(Spotify)$\" })" >/dev/null 2>&1
