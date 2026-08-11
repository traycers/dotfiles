#!/usr/bin/env bash
# swayidle has no config-file format of its own — this script is its
# "config", invoked from niri's spawn-at-startup. Locks after 5 minutes
# idle, powers off outputs after 10, and always locks before suspend.
set -euo pipefail

exec swayidle -w \
    timeout 300 "$HOME/.config/niri/scripts/lock.sh" \
    timeout 600 'niri msg action power-off-monitors' \
    resume 'niri msg action power-on-monitors' \
    before-sleep "$HOME/.config/niri/scripts/lock.sh"
