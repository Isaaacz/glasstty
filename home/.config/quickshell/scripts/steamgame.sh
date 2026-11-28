#!/usr/bin/env bash
# steamgame.sh — the Steam game running now, for GameMode.qml.
# Prints "APPID<TAB>NAME" and exits 0, or exits 1 when no game runs.
#
# Steam starts every game (native or Proton, Flatpak too) under
# `reaper SteamLaunch AppId=N`; the name comes from that app's manifest in
# whichever Steam library has it. Anchored on the reaper binary, so a shell
# that merely mentions the words is not taken for a game.
line=$(pgrep -af '^[^ ]*/reaper SteamLaunch AppId=[0-9]' | head -1)
[ -n "$line" ] || exit 1
id=$(sed -n 's/.*AppId=\([0-9]*\).*/\1/p' <<<"$line")
name=""
for lib in "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam" "$HOME/.local/share/Steam" "$HOME/.steam/steam"; do
    vdf="$lib/steamapps/libraryfolders.vdf"
    dirs="$lib"
    [ -f "$vdf" ] && dirs="$dirs $(sed -n 's/^\s*"path"\s*"\(.*\)"/\1/p' "$vdf")"
    for d in $dirs; do
        f="$d/steamapps/appmanifest_$id.acf"
        if [ -f "$f" ]; then
            name=$(sed -n 's/^\s*"name"\s*"\(.*\)"/\1/p' "$f" | head -1)
            break 2
        fi
    done
done
printf '%s\t%s\n' "$id" "$name"
