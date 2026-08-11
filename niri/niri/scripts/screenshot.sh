#!/usr/bin/env bash
# Region screenshot (default) or full-screen (--full), piped into swappy
# for annotation. swappy's own save/copy keybinds (Ctrl+S / Ctrl+C) handle
# where the result ends up.
set -euo pipefail

mkdir -p "$HOME/Pictures/Screenshots"

if [ "${1:-}" = "--full" ]; then
    grim - | swappy -f -
else
    region=$(slurp) || exit 0
    grim -g "$region" - | swappy -f -
fi
