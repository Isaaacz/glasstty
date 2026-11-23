#!/usr/bin/env bash
# Game mode reader. Emits one line per second:
#   1 fps frametime_ms cpu_load gpu_load cpu_temp gpu_temp   a game is running
#   0                                                         no game right now
#
# The numbers come from MangoHud, not from us: only the game process knows its
# own frame rate. MangoHud draws a FULLY TRANSPARENT overlay (alpha=0 in the
# pywal template colors-mangohud.conf; no_display would also stop the logger)
# and logs to CSV every 500 ms, flushing each row, so the
# newest file in $dir is the live game. A file that has not been written for
# 3 s means the game is gone (or paused logging), and the bar item hides.
#
# Only runs while game mode is on: ShellState starts and stops this Process.
dir="${MANGOHUD_LOG_DIR:-$HOME/.var/app/com.valvesoftware.Steam/cache/mangohud}"
mkdir -p "$dir"
# One CSV per game session, a few hundred KB an hour. Keep three days.
find "$dir" -maxdepth 1 -name '*.csv' -mtime +3 -delete 2>/dev/null

while true; do
  f=$(ls -t "$dir"/*.csv 2>/dev/null | grep -v '_summary\.csv$' | head -1)
  if [ -n "$f" ] && [ $(( $(date +%s) - $(stat -c %Y "$f") )) -le 3 ]; then
    # Column positions are read from the header, not hard-coded: MangoHud
    # has already reordered them between versions.
    line=$(awk -F, '
      /^fps,/ { for (i = 1; i <= NF; i++) col[$i] = i; next }
      ("fps" in col) && $1 ~ /^[0-9.]+$/ { last = $0 }
      END {
        if (last == "") exit
        n = split(last, v, ",")
        printf "1 %d %.1f %d %d %d %d\n", v[col["fps"]], v[col["frametime"]],
          v[col["cpu_load"]], v[col["gpu_load"]], v[col["cpu_temp"]], v[col["gpu_temp"]]
      }' "$f")
    echo "${line:-0}"
  else
    echo 0
  fi
  sleep 1
done
