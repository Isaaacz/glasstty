# Contributing

Thanks for wanting to help. glasstty is a personal rice, so changes that keep
it simple and niri-only are the easiest to accept.

- **Bugs:** open an issue with your Fedora and niri versions, what you did,
  what you expected and what happened. `qs log` (the shell's log) and
  `journalctl --user -u niri -b` usually say why.
- **Ideas:** open an issue first, so we can agree before you write code.
- **Pull requests:** one change per PR. Before sending, run what CI runs:

  ```bash
  niri validate -c home/.config/niri/config.kdl
  shellcheck -S error $(git ls-files | xargs grep -lE '^#!.*\b(ba)?sh' 2>/dev/null)
  ```

- **GNOME must stay untouched:** anything that changes shared settings
  (dconf, `~/.config/gtk-*`) has to be scoped to the niri session.

By contributing you agree that your work is released under the GPL-3.0, like
the rest of the project.
