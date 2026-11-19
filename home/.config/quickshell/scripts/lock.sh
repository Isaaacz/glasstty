#!/bin/sh
# lock.sh — lock the session with the shell's lock screen (LockScreen.qml).
#
# Used by Super+L, the power menu, swayidle and `loginctl lock-session`.
# Waits until niri confirms the lock is SECURE (important before suspend), and
# if the shell does not get there within 2 s (not running, crashed, broken
# config) falls back to swaylock, so the screen is never left unlocked.
qs ipc call lock lock >/dev/null 2>&1
i=0
while [ $i -lt 20 ]; do
    [ "$(qs ipc call lock status 2>/dev/null)" = secure ] && exit 0
    i=$((i + 1))
    sleep 0.1
done
exec swaylock -f
