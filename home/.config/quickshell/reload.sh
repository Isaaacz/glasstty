#!/usr/bin/env bash
# Clean reload of Quickshell (bar + notch + sidebar + overview + wallpaper).
# Normally it is NOT needed: quickshell watches its .qml files and hot-reloads.
# This is the safety net for when something gets stuck.

# ONE reload at a time. Pressing Super+G several times in a row opened several
# bars: each copy of the script killed qs, slept 0.4s by guesswork and started
# its own, so the three pkills were spent at the start -- when there was still
# nothing to kill -- and the three qs were born afterwards, without getting in
# each other's way. The lock discards presses that arrive while a reload is
# running, which is what you want: there is no point queueing reloads.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/quickshell-reload.lock"
flock -n 9 || exit 0

pkill -x qs 2>/dev/null

# Wait for it to die FOR REAL instead of trusting a fixed sleep: if it takes
# longer than expected, the old one and the new one end up overlapping.
for _ in {1..50}; do
    pgrep -x qs >/dev/null || break
    sleep 0.1
done
pgrep -x qs >/dev/null && pkill -9 -x qs 2>/dev/null

# Bring it up through niri, so it is a child of the session like the qs that
# config.kdl starts. Without niri (a TTY, a test), at least leave it running.
#
# 9>&- is NOT decorative: descriptors are inherited, so without it qs keeps
# hold of the lock for as long as it lives and the next Super+G finds the flock
# taken and does nothing.
if ! niri msg action spawn -- qs -n >/dev/null 2>&1 9>&-; then
    setsid -f qs -n >/dev/null 2>&1 </dev/null 9>&-
fi

# The lock is released on exit, so do not exit until the new qs is up:
# otherwise a second press would come in and kill it halfway through starting.
for _ in {1..30}; do
    pgrep -x qs >/dev/null && break
    sleep 0.1
done
