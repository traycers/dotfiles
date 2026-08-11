#!/usr/bin/env bash
# Deploys this repo's configs onto the machine: installs packages, backs up
# any pre-existing ~/.config entries, then symlinks this repo's app folders
# in their place. Safe to re-run — every step is idempotent.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
backed_up_anything=false
failed_packages=()

log() { echo "[install] $*"; }

# --- 1. apt packages (installed individually so one unavailable/renamed
#        package doesn't abort the whole run) ---
APT_PACKAGES=(
    waybar neovim tmux fuzzel mako-notifier swaylock swayidle
    alacritty cliphist wl-clipboard grim slurp swappy
    fonts-jetbrains-mono network-manager bluez libnotify-bin
)

log "updating apt package lists..."
sudo apt-get update

for pkg in "${APT_PACKAGES[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        log "$pkg already installed, skipping"
        continue
    fi
    log "installing $pkg..."
    if ! sudo apt-get install -y "$pkg"; then
        log "WARNING: failed to install $pkg (package name may differ on this release)"
        failed_packages+=("$pkg")
    fi
done

# --- 2. niri: not reliably available via plain apt on very new Ubuntu
#        releases. Try apt first; otherwise point at the official docs
#        rather than guessing at a third-party PPA. ---
if command -v niri >/dev/null 2>&1; then
    log "niri already installed, skipping"
elif sudo apt-get install -y niri 2>/dev/null; then
    log "niri installed via apt"
else
    log "WARNING: niri is not available via apt on this system."
    log "  See the official install docs for Ubuntu-specific instructions:"
    log "  https://github.com/YaLTeR/niri/wiki/Getting-Started"
    log "  (uncomment the cargo-build block below if you'd rather build from source)"
    # sudo apt-get install -y cargo build-essential libwayland-dev \
    #     libxkbcommon-dev libudev-dev libinput-dev libgbm-dev libseat-dev \
    #     libpixman-1-dev libdisplay-info-dev
    # cargo install --locked niri
    failed_packages+=("niri")
fi

# --- 3. starship: try apt, fall back to the official installer ---
if command -v starship >/dev/null 2>&1; then
    log "starship already installed, skipping"
elif sudo apt-get install -y starship 2>/dev/null; then
    log "starship installed via apt"
else
    log "starship not in apt, using the official installer instead"
    curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

# --- 4. Nerd Font (not packaged in apt at all) ---
bash "$REPO_DIR/fonts/install-nerd-font.sh"

# --- 5. backup + symlink directory-based app configs ---
mkdir -p "$BACKUP_DIR"

link_dir() {
    local app="$1"
    local target="$CONFIG_DIR/$app"
    local source="$REPO_DIR/$app/$app"

    if [ -L "$target" ]; then
        if [ "$(readlink -f "$target")" = "$(readlink -f "$source")" ]; then
            log "[$app] already correctly linked, skipping"
            return
        fi
        log "[$app] symlink points elsewhere, relinking"
        rm "$target"
    elif [ -e "$target" ]; then
        log "[$app] backing up existing config to $BACKUP_DIR/$app"
        mv "$target" "$BACKUP_DIR/$app"
        backed_up_anything=true
    fi

    ln -s "$source" "$target"
    log "[$app] linked -> $source"
}

APPS=(niri waybar nvim tmux fuzzel mako swaylock swayidle swappy alacritty)
for app in "${APPS[@]}"; do
    link_dir "$app"
done

# --- 6. single-file configs (starship.toml) ---
link_file() {
    local target="$1"
    local source="$2"

    if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$source")" ]; then
        log "[$(basename "$target")] already correctly linked, skipping"
        return
    fi
    if [ -e "$target" ] || [ -L "$target" ]; then
        log "[$(basename "$target")] backing up existing file to $BACKUP_DIR/"
        mv "$target" "$BACKUP_DIR/$(basename "$target")"
        backed_up_anything=true
    fi
    ln -s "$source" "$target"
    log "[$(basename "$target")] linked -> $source"
}

link_file "$CONFIG_DIR/starship.toml" "$REPO_DIR/starship/starship.toml"

if $backed_up_anything; then
    log "backups saved to $BACKUP_DIR"
else
    rmdir "$BACKUP_DIR"
fi

# --- 7. wire starship into bash ---
grep -qxF 'eval "$(starship init bash)"' "$HOME/.bashrc" 2>/dev/null || \
    echo 'eval "$(starship init bash)"' >> "$HOME/.bashrc"

# --- 8. summary ---
echo
log "done."
if [ "${#failed_packages[@]}" -gt 0 ]; then
    log "packages needing manual attention: ${failed_packages[*]}"
fi
log "manual steps remaining:"
log "  1. run 'niri msg outputs' after first login and fill in real"
log "     connector names in niri/niri/config.kdl's output block"
log "  2. log out and select niri as your session at the login screen"
log "  3. open nvim and run :Lazy sync to install its plugins"
