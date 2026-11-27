#!/usr/bin/env bash
# tests/ipc-watchdog-test.sh — scripts/ipc-watchdog.sh against stand-ins for
# qs, niri, logger and notify-send, in a throwaway folder: nothing of the real
# session is touched. Runs in CI (see .github/workflows/checks.yml).
#
# Scenarios:
#   healthy    IPC answers: the shell is left alone
#   reload     "Not ready" for less than the limit (a hot reload): left alone
#   stuck      "Not ready" for good: the shell is killed and started again
#   single     a second watchdog exits at once
# shellcheck disable=SC2034  # second and old are read inside check's eval
set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
dog="$repo/home/.config/quickshell/scripts/ipc-watchdog.sh"
root="$(mktemp -d "${TMPDIR:-/tmp}/glasstty-watchdog.XXXXXX")"
case "$root" in "${TMPDIR:-/tmp}"/glasstty-watchdog.*) ;; *) echo "unexpected temp dir: $root" >&2; exit 2 ;; esac
pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done; rm -rf -- "$root"; }
trap cleanup EXIT

# Stand-ins. The fake shell is a `sleep`; `qs ipc show` answers whatever
# $root/answer holds, and counts its calls; niri records the spawn.
mkdir -p "$root/bin"
cat > "$root/bin/qs" <<EOF
#!/bin/sh
case "\$1" in
    list) [ -s "$root/shell.pid" ] && kill -0 "\$(cat "$root/shell.pid")" 2>/dev/null \
              && printf '[{"pid": %s, "id": "x"}]\n' "\$(cat "$root/shell.pid")" || echo '[]' ;;
    ipc) echo x >> "$root/calls"; cat "$root/answer" ;;
esac
EOF
printf '#!/bin/sh\necho "$*" >> "%s/spawned"\n' "$root" > "$root/bin/niri"
printf '#!/bin/sh\necho "$*" >> "%s/journal"\n' "$root" > "$root/bin/logger"
printf '#!/bin/sh\nexit 0\n' > "$root/bin/notify-send"
chmod +x "$root"/bin/*
export PATH="$root/bin:$PATH" XDG_RUNTIME_DIR="$root" GLASSTTY_WATCHDOG_INTERVAL=0.2 GLASSTTY_WATCHDOG_STRIKES=4

failures=0
check() { if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; failures=$((failures + 1)); fi; }

start_shell() { sleep 300 & echo $! > "$root/shell.pid"; pids+=($!); }
start_dog() { sh "$dog" & dog_pid=$!; pids+=("$dog_pid"); }
stop_dog() { kill "$dog_pid" 2>/dev/null; wait "$dog_pid" 2>/dev/null; }
calls() { [ -f "$root/calls" ] && wc -l < "$root/calls" || echo 0; }

echo "── healthy"
start_shell; echo "target notch" > "$root/answer"; start_dog
sleep 1.5
check "shell still running" 'kill -0 "$(cat "$root/shell.pid")"'
check "nothing spawned" '[ ! -e "$root/spawned" ]'
check "it did check" '[ "$(calls)" -ge 3 ]'

echo "── reload"
echo "Not ready to accept queries yet." > "$root/answer"
sleep 0.5   # two or three refusals, under the limit of four
echo "target notch" > "$root/answer"
sleep 1
check "shell still running" 'kill -0 "$(cat "$root/shell.pid")"'
check "nothing spawned" '[ ! -e "$root/spawned" ]'

echo "── single"
sh "$dog"; second=$?
check "a second watchdog exits at once" '[ $second = 0 ]'
check "the first keeps running" 'kill -0 "$dog_pid"'

echo "── stuck"
old="$(cat "$root/shell.pid")"
echo "Not ready to accept queries yet." > "$root/answer"
for _ in $(seq 40); do [ -e "$root/spawned" ] && break; sleep 0.1; done
check "old shell killed" '! kill -0 "$old" 2>/dev/null'
check "new shell spawned through niri" 'grep -q "action spawn -- qs -n" "$root/spawned" 2>/dev/null'
check "restart logged" 'grep -q "restarting the shell" "$root/journal" 2>/dev/null'
stop_dog

echo
if [ $failures = 0 ]; then echo "all good"; else echo "$failures failure(s)"; exit 1; fi
