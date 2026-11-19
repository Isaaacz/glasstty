#!/usr/bin/env bash
# updates.sh — pending updates on Fedora: dnf packages + Flatpak apps.
#
#   updates.sh            one JSON line for the shell: {"text","tooltip","class"}
#   updates.sh --refresh  same, but forces dnf to refresh its metadata first
#   updates.sh --list     the pending updates, one per line (for a terminal)
#
# Read by ShellState.qml (the "updates" block). class is "updates", "none" or
# "error", so the shell knows what kind of number `text` is. The texts go
# through tr_() like the other scripts' notifications (lang.sh).
set -u
. "$HOME/.config/glasstty/scripts/lang.sh" 2>/dev/null || tr_() { printf '%s' "$1"; }

state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/glasstty"
lock_file="$state_dir/updates.lock"
error_log="$state_dir/updates.error.log"
mkdir -p "$state_dir"

emit_json() {
    printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$1" "$2" "$3"
}

# Only one check at a time: dnf takes a few seconds and the shell may ask again.
exec 9> "$lock_file"
if ! flock -w 120 9; then
    emit_json "?" "$(tr_ 'Otra consulta de actualizaciones sigue en curso' 'Another update check is still running')" "error"
    exit 0
fi

refresh=()
[ "${1:-}" = --refresh ] && refresh=(--refresh)

# dnf check-upgrade: exit 100 = updates pending, 0 = none, anything else = error.
# It works as a normal user, reading (and, when stale, refreshing) the user's
# metadata cache. Only lines shaped like "name.arch  version  repo" are counted.
dnf_out=$(timeout 120 dnf check-upgrade -q "${refresh[@]}" 2>"$error_log")
dnf_rc=$?
dnf_list=$(awk 'NF == 3 && $1 ~ /\.[A-Za-z0-9_]+$/ { print $1 }' <<< "$dnf_out")
dnf_n=$(grep -c . <<< "$dnf_list")

flat_list=$(timeout 60 flatpak remote-ls --updates --columns=application 2>/dev/null)
flat_n=$(grep -c . <<< "$flat_list")

if [ "${1:-}" = --list ]; then
    { [ -n "$dnf_list" ] && printf '%s\n' "$dnf_list"
      [ -n "$flat_list" ] && printf 'flatpak: %s\n' $flat_list; } || true
    [ $((dnf_n + flat_n)) -eq 0 ] && printf '%s\n' "$(tr_ 'Sin actualizaciones' 'No updates')"
    exit 0
fi

if [ "$dnf_rc" -ne 0 ] && [ "$dnf_rc" -ne 100 ]; then
    emit_json "?" "$(tr_ "Fallo al consultar · detalles en" "Check failed · details in") $error_log" "error"
    exit 0
fi
rm -f "$error_log"

total=$((dnf_n + flat_n))
if [ "$total" -gt 0 ]; then
    emit_json "$total" "$total $(tr_ 'actualizaciones disponibles' 'updates available') · dnf $dnf_n · flatpak $flat_n" "updates"
else
    emit_json "0" "$(tr_ 'Sistema actualizado' 'System up to date')" "none"
fi
