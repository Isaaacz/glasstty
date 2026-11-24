# Changelog

## Unreleased

**New**
- **Cards from the notch:** `notch ok|warn|fail|info` shows a coloured card
  from the notch, with buttons that answer back to a script (`--yes`/`--no`),
  a click action (`--open`), `notch run` for a command's result and duration,
  cards updated in place (`--replace`), and a Claude Code hook
  (`notch hook claude`). Inspired by jrnxf/drip.
- **Notifications drop out of the notch:** every notification is its own
  pill-shaped card that falls out of the notch; up to three stack below it
  and the rest wait in a counter. A ring shows the time left, hovering stops
  it, a right click puts the card away. A new tab in Settings › Appearance,
  **Pop-ups**, with a live preview, sets their height, width, distance from the notch, background (notch,
  black or theme) and opacity, colours by kind, duration, hover pause, the
  ring, how many at once, the detail line and the animation, with a button
  that shows an example and one that puts them back to the defaults (kept
  with Apply, like the rest of Appearance); it also switches back to the
  notch stretching.

**Fixed**
- Open GTK apps recolour with the wallpaper when the GTK theme setting is
  Adwaita (Fedora's default).

## v1.1.0 — 2026-11-23

A safer installer and a lot more to shape.

**New**
- **Lock screen you can shape:** twelve layout styles in a drawer of live
  miniatures (some inspired by qylock), and options for the background and
  blur, the clock (position, height, size, weight, font, colour, seconds,
  date format), the password (side incl. centre, height, line or glass box,
  card, your photo), a message, music and battery. A preview stays pinned in
  Settings. Blur, darkening, side, heights and the 12-hour clock reach the
  SDDM login too. The blur is a real gaussian (ImageMagick), cached.
- **Palettes per wallpaper:** up to nine variations of each wallpaper's palette
  (vivid, soft, contrast, from the centre/top/bottom, complementary, light),
  and any single colour can be changed from the Control Centre. Choices are
  remembered per wallpaper.
- **Settings redone** in the look of the menus, opening tiled with glass:
  window effects (transparency, blur, gaps, border, shadow, animations),
  sliders that drag well and take typed values, and Appearance changes that
  show live and are kept with *Apply* (or undone with *Discard*).
- **Exit screen** (`Super+Shift+E`, the power key): full-screen and blurred.
- **Capture screen** (`Print`, `Super+Shift+S`), GNOME-style: area, screen or
  window, photo or video.
- **Game mode:** FPS, CPU and GPU in the bar (MangoHud), performance profile,
  Steam games opaque and fullscreen.
- The screen fades to dark before the idle lock; low-battery warnings.

**Installer**
- Nothing of yours is overwritten: files, folders **and symlinks** in the way
  go to `*.bak-<date>`; changed systemd drop-ins are kept aside; re-running
  changes nothing.
- Optional parts (fonts, wallpapers, spotify, vscode, sddm), asked in a
  terminal or chosen with `--yes`, `--minimal`, `--with`, `--without`.
- Checks before starting and after dnf, errors that name the step and the
  command, a summary (installed, moved aside, kept, left out) and a log.
- The uninstaller removes only what is provably glasstty's and restores
  your backups.

**Fixed**
- The lock screen was black without the SDDM/thyx theme; it uses the wallpaper.
- Brightness can no longer go to 0 (the screen looked off).
- `satty`/`hyprpicker` are not in Fedora 45: dropped from the package list;
  the screenshot notice only offers *Edit* when satty exists.
- Reloading the shell no longer re-announces old notifications.

**Tests**
- `tests/sandbox-install.sh` (42 checks, on every push) and
  `tests/verify-install.sh` for a real install; a clean Fedora 45 VM run is
  recorded in `docs/TESTING.md`.

## v1.0 — 2026-11-19

The first release of glasstty: a rice for niri on Fedora.

- **Shell:** Quickshell notch with clock, media and cava, notifications, OSDs,
  launcher, workspace map and a Control Centre (player, quick toggles,
  calendar, wallpapers, system, manual colours, rices).
- **One wallpaper, one palette:** pywal colours pushed live to niri's borders,
  the shell, kitty, GTK 3/4 and libadwaita (backgrounds and folder icons), Qt,
  Spotify (Catppuccin via spicetify) and VS Code, without restarting apps.
- **Glass:** translucent windows with the wallpaper blurred behind them.
- **Login and lock:** SDDM with the thyx theme and a matching lock screen,
  both following the wallpaper.
- **Rices:** save and switch whole looks with `rice salvar` / `rice usar`
  (shell settings, icons, login layout, wallpaper) as git branches.
- **GNOME untouched:** everything is scoped to the niri session.
- **Install:** `install-niri.sh` (with `--dry-run`) and `uninstall-niri.sh`.

glasstty started as a niri port of [pocket-dots](https://github.com/diegoMalagrida/pocket-dots);
Hyprland support was removed for this release.
