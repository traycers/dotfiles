#!/usr/bin/env bash
# Installs JetBrainsMono Nerd Font from upstream GitHub releases. Ubuntu's
# apt only ships the un-patched font (no icon glyphs), which isn't enough
# for waybar/starship/fuzzel icons — so this fetches the patched variant
# directly. Idempotent: skips the download if already installed.
set -euo pipefail

FONT_NAME="JetBrainsMono Nerd Font"
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
RELEASE_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"

if fc-list | grep -qi "JetBrainsMono Nerd Font"; then
    echo "[fonts] $FONT_NAME already installed, skipping"
    exit 0
fi

echo "[fonts] downloading $FONT_NAME..."
tmp_archive="$(mktemp --suffix=.tar.xz)"
trap 'rm -f "$tmp_archive"' EXIT

curl -fLo "$tmp_archive" "$RELEASE_URL"
mkdir -p "$FONT_DIR"
tar -xf "$tmp_archive" -C "$FONT_DIR"
fc-cache -f "$FONT_DIR" >/dev/null

echo "[fonts] installed to $FONT_DIR"
echo "[fonts] verify the exact family name with: fc-list | grep -i jetbrains"
echo "[fonts] (patched builds sometimes register as \"JetBrainsMono NF\" or"
echo "[fonts]  similar — if configs don't pick it up, adjust the family name"
echo "[fonts]  in alacritty/alacritty/alacritty.toml and waybar/waybar/style.css)"
