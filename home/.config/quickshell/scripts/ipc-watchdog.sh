#!/bin/sh
# ipc-watchdog.sh — restarts the shell when its IPC is stuck on "Not ready".
#
# Quickshell answers IPC only while one generation of the config is alive.
# During a hot reload there are two for a moment, so `qs ipc` says "Not ready
# to accept queries yet." for a second or two. Now and then the old generation
# is never torn down after a reload: the bar keeps working, but every IPC call
# is refused from then on, and with it every shortcut, swayidle's dim and the
# lock screen (lock.sh falls back to swaylock). Quickshell 0.3.2 has no fix,
# and only a restart clears it.
#
# Started by shell.qml (one copy at a time, through flock); it checks every
# GLASSTTY_WATCHDOG_INTERVAL seconds (15) and restarts after
# GLASSTTY_WATCHDOG_STRIKES refusals in a row (4, about a minute), which no
# reload lasts. Only this config's instance is restarted, not other qs
# instances (qs -p elsewhere). Each restart goes to the journal (glasstty tag).
interval="${GLASSTTY_WATCHDOG_INTERVAL:-15}"
limit="${GLASSTTY_WATCHDOG_STRIKES:-4}"

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/glasstty-ipc-watchdog.lock"
flock -n 9 || exit 0

pid_of_shell() {
    qs list -j 2>/dev/null | sed -n 's/.*"pid": *\([0-9][0-9]*\).*/\1/p' | head -1
}

restart() {
    pid="$1"
    logger -t glasstty "IPC stuck on 'Not ready' for $limit checks in a row; restarting the shell (pid $pid)" 2>/dev/null
    kill "$pid" 2>/dev/null
    i=0
    while [ $i -lt 50 ] && kill -0 "$pid" 2>/dev/null; do i=$((i + 1)); sleep 0.1; done
    kill -9 "$pid" 2>/dev/null
    # Through niri, so it is a child of the session like the qs config.kdl
    # starts; 9>&- so the new shell does not hold the watchdog's lock.
    if ! niri msg action spawn -- qs -n >/dev/null 2>&1 9>&-; then
        setsid -f qs -n >/dev/null 2>&1 </dev/null 9>&-
    fi
    sleep 5
    notify-send -a glasstty "glasstty" "O shell tinha travado e foi reiniciado." 2>/dev/null 9>&-
}

strikes=0
while sleep "$interval"; do
    pid="$(pid_of_shell)"
    if [ -z "$pid" ]; then strikes=0; continue; fi   # not running: nothing to unstick
    case "$(timeout 5 qs ipc show 2>&1 | head -1)" in
        *"Not ready"*) strikes=$((strikes + 1)) ;;
        *) strikes=0 ;;
    esac
    if [ "$strikes" -ge "$limit" ]; then
        restart "$pid"
        strikes=0
    fi
done
