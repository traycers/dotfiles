#!/usr/bin/env bash
# Locks the screen with swaylock, using the config at
# ~/.config/swaylock/config (VS Code Dark+ colors). Shared by the niri
# keybind and swayidle's before-sleep/timeout hooks so the lock styling
# lives in exactly one place.
set -euo pipefail

exec swaylock
