# Testing glasstty

## Automatic (every push)

`tests/sandbox-install.sh` runs `install-niri.sh` and `uninstall-niri.sh` in a
throwaway `HOME`, with stand-ins for the commands that would touch the real
machine. It checks a dry run, a fresh install, a second run, an install over
your own files and symlinks (and that uninstalling brings them back exactly),
an edited copy surviving the uninstall, and an install that fails midway. CI
runs it on every push; run it locally the same way:

```bash
tests/sandbox-install.sh
```

`tests/qml-check.sh` checks the QML before it reaches a live session: qmllint
over every file, failing only on what breaks at runtime (syntax errors,
imports that do not resolve, names that exist nowhere, members missing from
glasstty's own types such as `ShellState.typo`), and then the whole shell
started by Quickshell in a headless sway, which must reach
`Configuration Loaded` without a `ReferenceError`. CI runs it in an Arch Linux
container; on Fedora, run it the same way with podman, away from your session:

```bash
podman run --rm -v "$PWD:/repo:ro,Z" archlinux:latest bash -c 'pacman -Syu --noconfirm --needed quickshell qt6-declarative qt6-multimedia sway python >/dev/null && /repo/tests/qml-check.sh'
```

## In a virtual machine (done for v1.1)

The installer was run on a fresh **Fedora 45 Cloud** image under QEMU/KVM
(2 CPUs, 2 GB): 552 packages, 44 items installed, `tests/verify-install.sh`
all good, the shell loading with no errors under niri, and an
uninstall + reinstall afterwards. What it found is fixed: `satty` and
`hyprpicker` are not in Fedora 45 (they are now optional), and
`xdg-user-dirs` was missing from the package list.

With a virgl GPU (`-device virtio-vga-gl -display egl-headless`; niri skips
software rendering, so plain VGA shows nothing) the desktop was checked too:
bar and notch, kitty with the glass, the Control Centre, Settings, the exit
screen, the capture screen, a wallpaper change (the whole palette followed in
under 5 s) and the lock screen. One more fix came out of it: without the
SDDM/thyx login theme the lock screen was black; it now uses the wallpaper.

## On a real machine

`tests/verify-install.sh` checks an installed system without changing anything:
the links, the copied files, the programs, the fonts, the niri config, and —
depending on where you run it — that the shell is up (inside niri) or that
GNOME is untouched (inside GNOME). Each line is ✓, ! (worth a look) or ✗.

### 1. A clean account (closest to a new Fedora)

A separate user has an empty `HOME`, so nothing of yours is involved.

```bash
sudo useradd -m glasstest && sudo passwd glasstest
```

Log out, log in as **glasstest** in GNOME, open a terminal and run:

```bash
git clone https://github.com/Isaaacz/glasstty.git ~/Projetos/glasstty
cd ~/Projetos/glasstty
./install-niri.sh
tests/verify-install.sh
```

Then log out, pick **niri** on the login screen, log in as glasstest and run
`~/Projetos/glasstty/tests/verify-install.sh` again. Go through the desktop:
`Super+D`, `Super+W` (change the wallpaper), `Super+L`, `Print`,
`Super+Shift+E`, Settings (`Super+,`).

Back in GNOME, `tests/verify-install.sh` should say GNOME is untouched. To
finish, try `./uninstall-niri.sh`, then remove the account:

```bash
sudo userdel -r glasstest
```

### 2. An account with GNOME already set up

Same as above, but in an account where GNOME has been used and customised (a
theme, icons, extensions, your own `~/.config/kitty` or `~/.config/fastfetch`).
Check that:

- the installer's summary lists your files under *moved aside* or *left as they were*;
- GNOME looks exactly as before (`tests/verify-install.sh` from GNOME);
- `./uninstall-niri.sh` puts your files back.

### What to report

The output of `./install-niri.sh` (its summary at the end) and of
`tests/verify-install.sh`, plus anything that looked wrong. Open an issue with
them.
