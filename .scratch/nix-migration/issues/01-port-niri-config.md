# Port niri config.kdl into the flake

Status: open

## Context

Packages for the laptop's wlroots stack (niri, waybar, mako, swappy, swayidle,
swaylock, fuzzel, awww, xdg-desktop-portal-gnome, etc.) are installed via
`home/laptop.nix`, but the actual compositor config — keybinds, outputs,
spawn-at-startup, window rules — hasn't been ported from the old stow-based
`niri/niri/config.kdl` (deleted in commit `df10da3`, still recoverable via
`git show c675e6d:niri/niri/config.kdl`) into a home-manager module.

## What needs to happen

- Bring `config.kdl` (and the companion scripts under `niri/niri/scripts/`:
  `bluetooth-menu.sh`, `clipboard-picker.sh`, `lock.sh`, `screenshot.sh`,
  `wifi-menu.sh`) under home-manager management — either `xdg.configFile`
  pointing at files in this repo, or a `wayland.windowManager.niri`-style
  module if one exists for home-manager by then.
- Add the session-bootstrap line niri needs before the new
  `systemd.user.services` (`awww-daemon`, `xdg-desktop-portal-gnome`) can
  actually come up:
  `spawn-at-startup "dbus-update-activation-environment" "--systemd" "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP"`
  followed by starting `graphical-session.target` — see the comment in
  `home/laptop.nix` above the `systemd.user.services` block.
- Replace old `swww` invocations in scripts/config with `awww` — the
  nixpkgs package (and its binaries) were renamed `swww` → `awww` upstream;
  `pkgs.swww` is currently just a deprecated alias.
- Old config referenced `JetBrainsMono Nerd Font` (waybar, mako) — update to
  `Iosevka Nerd Font` (or whatever the actual registered family name turns
  out to be via `fc-list` once applied — see chat history, not yet verified
  on real hardware).
- Decide whether `mako`/`waybar`/`fuzzel` stay as `home.packages` + raw
  `xdg.configFile` dotfiles, or get migrated to their dedicated home-manager
  `programs.*` modules (`programs.waybar`, `programs.mako`, etc.) for
  declarative config generation instead — see `docs/tutorial/12-home-manager.md`
  on the `programs.*` vs `home.packages` distinction.

## Comments
