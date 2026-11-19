# Changelog

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
