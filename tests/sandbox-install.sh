#!/usr/bin/env bash
# tests/sandbox-install.sh — install-niri.sh / uninstall-niri.sh in a throwaway
# HOME, with stand-ins for the commands that would touch the real machine
# (systemctl, wal, niri, curl, fonts). Nothing outside a fresh temporary folder
# is read or written. Runs in CI (see .github/workflows/checks.yml).
#
#   tests/sandbox-install.sh        all scenarios; exit 1 if any fails
#
# Scenarios:
#   dry-run        --dry-run changes nothing
#   fresh          install on an empty HOME, then uninstall leaves only the wallpapers
#   rerun          a second install changes nothing
#   your-files     install over your own files, folders and symlinks, then
#                  uninstall: the HOME is back exactly as it was
#   edited-copy    a copied file you edited survives the uninstall
#   interrupted    a failure midway is reported with a summary, and a rerun finishes
set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
root="$(mktemp -d "${TMPDIR:-/tmp}/glasstty-sandbox.XXXXXX")"
case "$root" in "${TMPDIR:-/tmp}"/glasstty-sandbox.*) ;; *) echo "unexpected temp dir: $root" >&2; exit 2 ;; esac
cleanup() { chmod -R u+w -- "$root" 2>/dev/null; rm -rf -- "$root"; }
trap cleanup EXIT

# Stand-ins: succeed and do nothing (fc-list reports the Nerd Font as present).
mkdir -p "$root/bin"
for c in systemctl wal niri curl fc-cache; do printf '#!/bin/sh\nexit 0\n' > "$root/bin/$c"; done
printf '#!/bin/sh\necho "Symbols Nerd Font"\n' > "$root/bin/fc-list"
printf '#!/bin/sh\necho "$HOME"\n' > "$root/bin/xdg-user-dir"
chmod +x "$root"/bin/*
export PATH="$root/bin:$PATH"

pass=0; fail=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=$((fail + 1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

newhome() { export HOME="$root/$1"; mkdir -p "$HOME"; }
# Everything in HOME (names, types, link targets, file contents) except the
# wallpapers, which are copied on purpose and left by the uninstaller.
snap() {
    # (and the install logs, which stay in ~/.cache/glasstty on purpose)
    (cd "$HOME" && find . -not -path './Pictures*' -not -path './.cache' -not -path './.cache/glasstty*' -printf '%y %p %l\n' | sort
     find . -not -path './Pictures*' -not -path './.cache/glasstty*' -type f -print0 | sort -z | xargs -0 -r md5sum) | md5sum
}
inst()   { "$repo/install-niri.sh" --no-packages --no-fonts --yes "$@" > "$root/out.txt" 2>&1; }
uninst() { "$repo/uninstall-niri.sh" "$@" > "$root/out.txt" 2>&1; }

echo "dry-run"
newhome dry
s0="$(snap)"; inst --dry-run; rc=$?
check "exits 0" '[ $rc -eq 0 ]'
check "changes nothing" '[ "$(snap)" = "$s0" ]'

echo "fresh"
newhome fresh
inst; rc=$?
check "install exits 0" '[ $rc -eq 0 ]'
check "quickshell is linked into the repo" '[ "$(readlink -f "$HOME/.config/quickshell")" = "$repo/home/.config/quickshell" ]'
check "niri config is linked" '[ -L "$HOME/.config/niri/config.kdl" ]'
check "systemd drop-in copied" '[ -f "$HOME/.config/systemd/user/niri.service.d/theme-env.conf" ]'
check "wallpapers copied" 'ls "$HOME"/Pictures/wallpapers/*.jpg >/dev/null 2>&1'
check "summary printed" 'grep -q "installed or updated" "$root/out.txt"'

echo "rerun"
s1="$(snap)"; inst; rc=$?
check "second install exits 0" '[ $rc -eq 0 ]'
check "second install changes nothing" '[ "$(snap)" = "$s1" ]'
check "and says so (0 installed)" 'grep -q "installed or updated: 0" "$root/out.txt"'

uninst; rc=$?
check "uninstall exits 0" '[ $rc -eq 0 ]'
check "uninstall leaves only the wallpapers (and the log)" '[ -z "$(cd "$HOME" && find . -not -path "./Pictures*" -not -path "./.cache/glasstty*" \( -type f -o -type l \))" ]'

echo "parts"
newhome minimal
inst --minimal; rc=$?
check "--minimal exits 0" '[ $rc -eq 0 ]'
check "--minimal still installs the core" '[ -L "$HOME/.config/quickshell" ]'
check "--minimal copies no wallpapers" '[ ! -d "$HOME/Pictures/wallpapers" ]'
check "--minimal adds no Spotify launcher" '[ ! -e "$HOME/.local/share/applications/com.spotify.Client.desktop" ]'
check "--minimal links no code wrapper" '[ ! -e "$HOME/.local/bin/code" ]'
check "the summary lists what was left out" 'grep -q "not installed (optional parts left out)" "$root/out.txt"'
check "a log file is written" 'ls "$HOME"/.cache/glasstty/install-*.log >/dev/null 2>&1'
newhome withspotify
inst --with spotify,vscode --without wallpapers; rc=$?
check "--with/--without exits 0" '[ $rc -eq 0 ]'
check "--with spotify adds the launcher and the theme" '[ -f "$HOME/.local/share/applications/com.spotify.Client.desktop" ] && [ -L "$HOME/.config/spicetify/Themes" ]'
check "--with vscode links the code wrapper" '[ -L "$HOME/.local/bin/code" ]'
check "--without wallpapers copies none" '[ ! -d "$HOME/Pictures/wallpapers" ]'
inst --with nonsense; rc=$?
check "an unknown part is refused" '[ $rc -ne 0 ] && grep -q "unknown part" "$root/out.txt"'

echo "your-files"
newhome yours
mkdir -p "$HOME/.config/fastfetch" "$HOME/dots/kitty" "$HOME/.config/systemd/user/niri.service.d" \
         "$HOME/.local/bin" "$HOME/.local/share/applications"
echo mine > "$HOME/.config/fastfetch/config.jsonc"
ln -s "$HOME/dots/kitty" "$HOME/.config/kitty"
echo "[Service]" > "$HOME/.config/systemd/user/niri.service.d/oo7.conf"
printf '#!/bin/sh\necho my code\n' > "$HOME/.local/bin/code"
s0="$(snap)"
inst; rc=$?
check "install exits 0" '[ $rc -eq 0 ]'
check "your kitty symlink was moved aside, not lost" '[ "$(readlink "$(ls -d "$HOME"/.config/kitty.bak-* | head -n1)")" = "$HOME/dots/kitty" ]'
check "your fastfetch folder was moved aside" 'grep -q mine "$(ls -d "$HOME"/.config/fastfetch.bak-* | head -n1)/config.jsonc"'
check "your different drop-in was moved aside" 'grep -q "^\[Service\]$" "$(ls "$HOME"/.config/systemd/user/niri.service.d/oo7.conf.bak-* | head -n1)"'
check "your command was not replaced" 'grep -q "my code" "$HOME/.local/bin/code"'
check "the summary lists what was moved" 'grep -q "moved aside" "$root/out.txt"'
uninst; rc=$?
check "uninstall exits 0" '[ $rc -eq 0 ]'
check "HOME is back exactly as it was" '[ "$(snap)" = "$s0" ]'

echo "edited-copy"
newhome edited
inst
echo "# my change" >> "$HOME/.local/share/applications/org.gnome.Settings.desktop"
# one effects file as Settings writes it, one of your own with a similar name
printf '// Generated by Settings > Appearance > Effects.\nlayout { gaps 6; }\n' > "$HOME/.config/niri/efeitos.kdl"
printf 'layout { gaps 9; }\n' > "$HOME/.config/niri/efeitos-meus.kdl"
uninst; rc=$?
check "uninstall exits 0" '[ $rc -eq 0 ]'
check "the copy you edited is still there" 'grep -q "# my change" "$HOME/.local/share/applications/org.gnome.Settings.desktop"'
check "and is listed as kept" 'grep -q "you changed it" "$root/out.txt"'
check "the generated effects file is removed" '[ ! -e "$HOME/.config/niri/efeitos.kdl" ]'
check "your own .kdl with no marker is kept" '[ -f "$HOME/.config/niri/efeitos-meus.kdl" ]'

echo "interrupted"
newhome broken
if [ "$(id -u)" -eq 0 ]; then
    echo "  (skipped: root ignores the read-only folder used to break the install)"
else
    mkdir -p "$HOME/.config/systemd/user"
    chmod 555 "$HOME/.config/systemd/user"
    inst; rc=$?
    check "a failing install exits non-zero" '[ $rc -ne 0 ]'
    check "it names the step and the command" 'grep -q "during \"systemd drop-ins\"" "$root/out.txt" && grep -q "mkdir -p" "$root/out.txt"'
    check "it prints the summary so far" 'grep -q "stopped early" "$root/out.txt"'
    chmod 755 "$HOME/.config/systemd/user"
    inst; rc=$?
    check "a rerun finishes" '[ $rc -eq 0 ]'
fi

echo
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
