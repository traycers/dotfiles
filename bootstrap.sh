#!/usr/bin/env bash
# One-shot bootstrap for a new machine: installs Nix (if missing), enables
# flakes for the current user, and applies the home-manager configuration
# for the given host profile (laptop = niri desktop, work = Ubuntu+GNOME).
# Idempotent — safe to re-run any time to pick up changes.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HM_USER="aldishu"

HOST_PROFILE="${1:-}"
while [[ "$HOST_PROFILE" != "laptop" && "$HOST_PROFILE" != "work" ]]; do
  read -rp "Which machine is this (laptop/work)? " HOST_PROFILE
done

if ! command -v nix >/dev/null 2>&1; then
  echo "==> Nix not found, installing (official multi-user installer)..."
  sh <(curl -fsSL https://nixos.org/nix/install) --daemon

  # shellcheck disable=SC1091
  [ -e /etc/profile.d/nix.sh ] && . /etc/profile.d/nix.sh
fi

if ! command -v nix >/dev/null 2>&1; then
  echo "==> 'nix' still not on PATH — open a new shell and re-run this script." >&2
  exit 1
fi

echo "==> Linking ~/.config/nix/nix.conf (enables flakes)..."
mkdir -p "$HOME/.config/nix"
ln -sf "$REPO_DIR/nix/.config/nix/nix.conf" "$HOME/.config/nix/nix.conf"

CONFIG_NAME="$HM_USER-$HOST_PROFILE"
echo "==> Applying home-manager configuration '$CONFIG_NAME'..."
nix --extra-experimental-features "nix-command flakes" \
  run home-manager/master -- switch --flake "$REPO_DIR#$CONFIG_NAME"

echo "==> Done. Restart your terminal/session to pick up new packages and fonts."
