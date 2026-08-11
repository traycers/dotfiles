#!/usr/bin/env bash
# Shows clipboard history via fuzzel and copies the chosen entry back to the
# clipboard. Requires the cliphist watchers spawned in niri's config.kdl to
# actually be recording history.
set -euo pipefail

selection=$(cliphist list | fuzzel --dmenu --prompt "clipboard> ")
[ -n "$selection" ] || exit 0

echo "$selection" | cliphist decode | wl-copy
