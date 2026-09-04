# Write niri config for the flake (from scratch, not ported)

Status: open

## Context

Packages for the laptop's wlroots stack (niri, waybar, mako, swappy, swayidle,
swaylock, fuzzel, awww, xdg-desktop-portal-gnome, etc.) are installed via
`home/laptop.nix`, but there's no compositor config yet — keybinds, outputs,
spawn-at-startup, window rules, and the companion menu scripts (bluetooth/
wifi/clipboard/lock/screenshot).

**The old stow-based configs are explicitly not being carried over** (see
chat history: "те конфиги старые и меня не устраивают, поэтому я начал
заново") — this is a from-scratch design pass, not a port. The old files
(`git show c675e6d:niri/niri/config.kdl` etc., deleted in `df10da3`) are only
useful as a reference for *what functionality existed*, not as source to
reuse.

## What needs to happen

- Design and write a new `config.kdl` (and whatever menu scripts are still
  wanted — bluetooth/wifi/clipboard/lock/screenshot picker via fuzzel) under
  home-manager management — either `xdg.configFile` pointing at files in this
  repo, or a `wayland.windowManager.niri`-style module if one exists for
  home-manager by then.
- Add the session-bootstrap step niri needs before the
  `systemd.user.services` already declared in `home/laptop.nix`
  (`awww-daemon`, `xdg-desktop-portal-gnome`) can actually come up:
  `spawn-at-startup "dbus-update-activation-environment" "--systemd" "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP"`
  followed by starting `graphical-session.target` — see the comment above
  that block in `home/laptop.nix`.
- Wallpaper tool is `awww`/`awww-daemon` (nixpkgs renamed it from
  `swww`/`swww-daemon` upstream) — use the new binary names in whatever gets
  written.
- Font: `Iosevka Nerd Font` is what's installed (`home/common.nix`), not
  `JetBrainsMono Nerd Font` — confirm exact registered family name via
  `fc-list` once applied on real hardware.
- Decide whether `mako`/`waybar`/`fuzzel` get raw `xdg.configFile` dotfiles or
  their dedicated home-manager `programs.*` modules (`programs.waybar`,
  `programs.mako`, etc.) for declarative config generation instead — see
  `docs/tutorial/12-home-manager.md` on the `programs.*` vs `home.packages`
  distinction.

## Comments
