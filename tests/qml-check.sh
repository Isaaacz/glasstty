#!/usr/bin/env bash
# tests/qml-check.sh — catches QML mistakes before they reach a live session,
# where they only show up as a broken bar after the hot reload. Two checks on
# home/.config/quickshell, neither of which touches the repository:
#
#   lint   qmllint over every file, failing only on what breaks at runtime:
#          syntax errors, imports that do not resolve, names that exist
#          nowhere ("X is not defined") and members missing from glasstty's
#          own types (ShellState.typo). The rest of qmllint's advice (parent
#          scope access, duck-typed members of Qt types) is left out.
#   load   starts the whole shell with Quickshell in a headless sway and
#          fails unless it reaches "Configuration Loaded" without a
#          ReferenceError on the way.
#
#   tests/qml-check.sh [lint|load]     both when no argument is given
#
# Needs qmllint (qt6-declarative), qs (quickshell), sway and python3. CI runs
# it in an Arch Linux container (see .github/workflows/checks.yml); to run it
# the same way on Fedora, without touching your session:
#
#   podman run --rm -v "$PWD:/repo:ro,Z" archlinux:latest bash -c \
#     'pacman -Syu --noconfirm --needed quickshell qt6-declarative qt6-multimedia sway python >/dev/null && /repo/tests/qml-check.sh'
set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
src="$repo/home/.config/quickshell"
work="$(mktemp -d "${TMPDIR:-/tmp}/glasstty-qml.XXXXXX")"
case "$work" in "${TMPDIR:-/tmp}"/glasstty-qml.*) ;; *) echo "unexpected temp dir: $work" >&2; exit 2 ;; esac
sway_pid=""
cleanup() { [ -n "$sway_pid" ] && kill "$sway_pid" 2>/dev/null; rm -rf -- "$work"; }
trap cleanup EXIT

qmllint="$(command -v qmllint || echo /usr/lib/qt6/bin/qmllint)"
qtqml="$(dirname "$(dirname "$qmllint")")/qml"
[ -d "$qtqml" ] || qtqml=/usr/lib/qt6/qml

lint() {
    echo "── lint"
    # A copy with a qmldir naming the singletons: Quickshell finds them on its
    # own, qmllint needs to be told, or every Colors.x would look missing.
    cp -r "$src" "$work/qml"
    (
        cd "$work/qml" || exit 2
        echo "module glasstty"
        for f in *.qml; do
            n="${f%.qml}"
            if grep -q '^pragma Singleton' "$f"; then echo "singleton $n 1.0 $f"; else echo "$n 1.0 $f"; fi
        done
    ) > "$work/qml/qmldir"
    (cd "$work/qml" && "$qmllint" -I "$qtqml" --json "$work/lint.json" ./*.qml >/dev/null 2>&1)
    python3 - "$work/lint.json" "$work/qml" <<'PY'
import json, os, re, sys

report, folder = sys.argv[1], sys.argv[2]
own = {f[:-4] for f in os.listdir(folder) if f.endswith(".qml")}
# Context properties a delegate gets without declaring them.
context = {"index", "modelData", "model"}
bad = []
for entry in json.load(open(report))["files"]:
    name = os.path.basename(entry["filename"])
    lines = open(os.path.join(folder, entry["filename"]), encoding="utf-8").read().split("\n")
    if not entry.get("success", True) and not entry["warnings"]:
        bad.append(f"{name}: qmllint could not read it")
    for w in entry["warnings"]:
        kind, msg = w.get("id", ""), w.get("message", "")
        where = f"{name}:{w.get('line', '?')}:{w.get('column', '?')}"
        notes = json.dumps(w.get("suggestions", []))
        if kind == "syntax" or w.get("type") == "critical":
            bad.append(f"{where}: {msg}")
        elif kind == "import" and msg.startswith("Failed to import"):
            bad.append(f"{where}: {msg}")
        elif kind == "unqualified" and msg == "Unqualified access":
            if "member of a parent" in notes or "ComponentBehavior" in notes:
                continue
            line, col = w.get("line", 0), w.get("column", 0)
            word = re.match(r"[A-Za-z_$][\w$]*", lines[line - 1][col - 1:]) if line else None
            word = word.group(0) if word else "?"
            if word in context:
                continue
            bad.append(f"{where}: {word} is not defined")
        elif kind == "missing-property":
            m = re.search(r'not found on type "?(\w+)"?', msg)
            if m and m.group(1) in own:
                bad.append(f"{where}: {msg}")
for b in bad:
    print("  ✗ " + b)
print(f"  {len(bad)} problem(s)" if bad else "  ok")
sys.exit(1 if bad else 0)
PY
}

load() {
    echo "── load"
    export XDG_RUNTIME_DIR="$work/run" HOME="$work/home"
    mkdir -m 700 "$XDG_RUNTIME_DIR"; mkdir "$HOME"
    # A copy of sway drops its file capabilities, which containers refuse to
    # exec ("Operation not permitted").
    cp "$(command -v sway)" "$work/sway"
    WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
        "$work/sway" -c /dev/null > "$work/sway.log" 2>&1 &
    sway_pid=$!
    for _ in $(seq 40); do
        sock="$(cd "$XDG_RUNTIME_DIR" && ls wayland-? 2>/dev/null | head -1)"
        [ -n "$sock" ] && break
        sleep 0.25
    done
    if [ -z "$sock" ]; then echo "  ✗ headless sway did not start"; tail -5 "$work/sway.log"; return 1; fi
    WAYLAND_DISPLAY="$sock" QT_QPA_PLATFORM=wayland timeout 20 qs -p "$src" > "$work/qs.log" 2>&1
    sed -E 's/\x1b\[[0-9;]*m//g' "$work/qs.log" > "$work/qs.txt"
    local fail=0
    if ! grep -q "Configuration Loaded" "$work/qs.txt"; then
        echo "  ✗ the shell did not load:"; grep -E "ERROR|rror" "$work/qs.txt" | head -20 | sed 's/^/    /'; fail=1
    fi
    if grep -qE "ReferenceError|is not defined" "$work/qs.txt"; then
        echo "  ✗ undefined names while loading:"; grep -E "ReferenceError|is not defined" "$work/qs.txt" | head -20 | sed 's/^/    /'; fail=1
    fi
    [ $fail = 0 ] && echo "  ok"
    return $fail
}

status=0
case "${1:-all}" in
    lint) lint || status=1 ;;
    load) load || status=1 ;;
    all) lint || status=1; load || status=1 ;;
    *) echo "usage: $0 [lint|load]" >&2; exit 2 ;;
esac
exit $status
