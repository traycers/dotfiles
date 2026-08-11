# dotfiles

Config files for a Wayland desktop on Ubuntu 26.04, built around **niri**,
**waybar**, **neovim**, and **tmux**, plus the companion tools niri needs
to be a full desktop: **fuzzel** (launcher), **mako** (notifications),
**swaylock**/**swayidle** (lock/idle), **alacritty** (terminal),
**cliphist** (clipboard history), **starship** (bash prompt), and
**grim**/**slurp**/**swappy** (screenshots). Everything is themed in
**VS Code Dark+** — see [`palette.md`](palette.md) for the canonical color
values every config draws from.

## Install

```sh
./install.sh
```

This installs the required apt packages, backs up any existing
`~/.config/<app>` directories to `~/.config-backup-<timestamp>/`, and
symlinks each app's config from this repo into `~/.config`. It's safe to
re-run — already-correct symlinks and already-installed packages are
skipped.

Two things it can't fully automate on a brand-new Ubuntu release:

- **niri** may not be in Ubuntu's apt repos yet. The script tries apt
  first and otherwise points you at niri's own install docs instead of
  guessing at a third-party PPA.
- **starship** falls back to its official installer script if apt doesn't
  have it.

## Manual steps after install

1. Run `niri msg outputs` once you're in a niri session and fill in your
   real monitor connector name(s) in `niri/niri/config.kdl`'s `output`
   block (the shipped one uses a placeholder `"eDP-1"`).
2. Log out and select **niri** as your session at the login screen.
3. Open `nvim` and run `:Lazy sync` to install its plugins on first launch.

## Layout

Each app's folder mirrors its eventual `~/.config/<app>` 1:1
(`niri/niri/`, `waybar/waybar/`, etc.) so `install.sh` can symlink them
generically. `starship.toml` is the one single-file exception (no
`~/.config/starship` directory).

## Neovim scope

The neovim config is intentionally a themed, lean editor — colorscheme
(`Mofiqul/vscode.nvim`), treesitter, telescope, lualine, nvim-tree. It has
no LSP, completion, or formatter setup; that's a deliberate boundary, not
an oversight, to keep this a config task rather than a full IDE distro.

## Keybinds (niri)

| Bind | Action |
|---|---|
| `Mod+Return` | open alacritty |
| `Mod+D` | open fuzzel |
| `Mod+Shift+V` | clipboard history picker |
| `Mod+Shift+W` | Wi-Fi picker (fuzzel + nmcli) |
| `Mod+Shift+B` | Bluetooth picker (fuzzel + bluetoothctl) |
| `Mod+L` / `Mod+Shift+Q` | lock screen |
| `Print` | region screenshot -> swappy |
| `Mod+Print` | full-screen screenshot -> swappy |
| `Mod+Q` | close window |
| `Mod+Shift+E` | quit niri |

See `niri/niri/config.kdl` for the full list (window/column/workspace
navigation).

## Font size

Default text size is **18** everywhere (alacritty, waybar, fuzzel, mako,
swaylock) to stay readable at a glance. If you need it bigger or smaller,
these are the places to change:

| App | File | Key |
|---|---|---|
| alacritty | `alacritty/alacritty/alacritty.toml` | `[font] size` |
| waybar | `waybar/waybar/style.css` | `font-size` (also bump `height`/`icon-size` in `config.jsonc` if you go much bigger) |
| fuzzel | `fuzzel/fuzzel/fuzzel.ini` | `font=...:size=` |
| mako | `mako/mako/config` | `font=` |
| swaylock | `swaylock/swaylock/config` | `font-size=` |

tmux and neovim have no font setting of their own — both inherit whatever
size alacritty is running at.

## Wi-Fi / Bluetooth

Both are fuzzel menus backed by the standard CLI tools rather than a
separate GUI app:

- **Wi-Fi**: `niri/niri/scripts/wifi-menu.sh` lists nearby networks via
  `nmcli` (NetworkManager), connects to a known profile directly or
  prompts for a password through fuzzel's password-entry mode for a new
  one. Also reachable by clicking the network module in waybar.
- **Bluetooth**: `niri/niri/scripts/bluetooth-menu.sh` lists already
  *paired* devices via `bluetoothctl`, toggles power, scans for 8s, and
  connects/disconnects. Pairing a brand-new device for the first time
  isn't automated here — do that once via `bluetoothctl` in a terminal
  (`scan on`, `pair <MAC>`, `trust <MAC>`), after which it shows up in
  this menu. Also reachable by clicking the bluetooth module in waybar.
