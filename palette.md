# VS Code Dark+ palette

Canonical hex values reused across every config in this repo. If you tweak a
color, change it here first and propagate it — don't invent new shades
per-app.

## Surfaces

| Role                          | Hex       |
|--------------------------------|-----------|
| Base background                | `#1e1e1e` |
| Panel / secondary surface       | `#252526` |
| Tertiary surface (hover/tabs)   | `#333333` |
| Hover / line highlight          | `#2a2a2a` |
| Widget / dropdown border        | `#454545` |
| Selection background            | `#264f78` |

## Text

| Role              | Hex       |
|-------------------|-----------|
| Primary foreground | `#d4d4d4` |
| Dim foreground     | `#858585` |
| Bright foreground  | `#c6c6c6` |
| Terminal foreground (VS Code integrated terminal default — intentionally distinct from primary fg) | `#cccccc` |
| Cursor             | `#aeafad` |

## Accent (blue)

| Role            | Hex       |
|-----------------|-----------|
| Primary accent   | `#007acc` |
| Secondary accent | `#0e639c` |
| Hover accent     | `#1177bb` |
| Focus border     | `#007fd4` |

## Diagnostics / semantic

| Role              | Hex       |
|-------------------|-----------|
| Error              | `#f44747` |
| Warning            | `#cca700` |
| Info               | `#3794ff` |
| Git added (bright) | `#89d185` |
| Git added (subdued)| `#587c0c` |
| Git modified       | `#0c7d9d` |
| Git deleted        | `#f14c4c` |

## Syntax accents

| Token             | Hex       |
|-------------------|-----------|
| Keyword / control  | `#569cd6` |
| Function name      | `#dcdcaa` |
| String             | `#ce9178` |
| Number             | `#b5cea8` |
| Type / class       | `#4ec9b0` |
| Variable/parameter | `#9cdcfe` |
| Constant           | `#4fc1ff` |
| Comment            | `#6a9955` |

## 16 ANSI terminal colors

VS Code's default dark integrated-terminal palette (used verbatim in
`alacritty/alacritty/alacritty.toml`):

```
normal:                      bright:
  black   #000000              black   #666666
  red     #cd3131              red     #f14c4c
  green   #0dbc79              green   #23d18b
  yellow  #e5e510              yellow  #f5f543
  blue    #2472c8              blue    #3b8eea
  magenta #bc3fbc              magenta #d670d6
  cyan    #11a8cd              cyan    #29b8db
  white   #e5e5e5              white   #e5e5e5
```

## Per-app mapping

- **alacritty**: bg `#1e1e1e`, fg `#d4d4d4`, cursor `#aeafad`, selection bg `#264f78`, ANSI table above.
- **waybar**: CSS custom properties — `--bg:#1e1e1e; --bg-alt:#252526; --fg:#d4d4d4; --fg-dim:#858585; --accent:#007acc; --warn:#cca700; --error:#f44747; --good:#89d185;`.
- **mako**: background `#252526E6`, text `#d4d4d4`, border `#007acc`; critical urgency bg `#5a1d1d`, text `#f44747`, border `#f44747`.
- **swaylock**: bare hex, no `#` prefix — ring `1e1e1e`, inside `252526`, text `d4d4d4`, key-highlight `0e639c`, verifying `569cd6`, wrong `f44747`.
- **swappy**: default annotation color `#f44747`, extra swatches from the accent/diagnostic set.
- **starship**: directory segment bg `#0e639c` / fg `#1e1e1e`, git-branch bg `#569cd6`, git-status bg `#cca700` (dirty) / `#f44747` (error), prompt char `#89d185` success / `#f44747` error.
- **nvim**: `Mofiqul/vscode.nvim` colorscheme (`style = 'dark'`) — a faithful port, matches this palette almost exactly out of the box.
- **niri**: border `active-color "#007acc"`, `inactive-color "#454545"`.
- **tmux**: status bar bg `#1e1e1e`, active window `#007acc` on `#1e1e1e`, inactive window fg `#858585`, pane border `#454545`, active pane border `#007acc`.
