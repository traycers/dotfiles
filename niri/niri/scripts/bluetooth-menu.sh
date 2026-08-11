#!/usr/bin/env bash
# Bluetooth picker via fuzzel + bluetoothctl. Handles power toggle, scanning,
# and connect/disconnect for already-paired devices. Pairing a brand-new
# device is a one-time interactive step better done directly with
# `bluetoothctl` in a terminal (or `blueman-manager` if installed) — this
# menu deliberately doesn't try to automate first-time pairing.
set -euo pipefail

power_state=$(bluetoothctl show | awk -F': ' '/Powered/{print $2}')

mapfile -t macs < <(bluetoothctl devices Paired | awk '{print $2}')

menu=("power: ${power_state}" "scan for devices (8s)")
declare -A entry_for_label

for mac in "${macs[@]}"; do
    info=$(bluetoothctl info "$mac")
    name=$(awk -F': ' '/Name/{print $2; exit}' <<<"$info")
    [ -n "$name" ] || name="$mac"
    if grep -q "Connected: yes" <<<"$info"; then
        state="connected"
    else
        state="disconnected"
    fi
    label="$name ($state)"
    menu+=("$label")
    entry_for_label["$label"]="$mac|$state"
done

choice=$(printf '%s\n' "${menu[@]}" | fuzzel --dmenu --prompt "bluetooth> ")
[ -n "$choice" ] || exit 0

case "$choice" in
"power: yes")
    bluetoothctl power off
    notify-send "Bluetooth" "Powered off"
    ;;
"power: no")
    bluetoothctl power on
    notify-send "Bluetooth" "Powered on"
    ;;
"scan for devices (8s)")
    notify-send "Bluetooth" "Scanning..."
    bluetoothctl --timeout 8 scan on
    exec "$0"
    ;;
*)
    IFS='|' read -r mac state <<<"${entry_for_label[$choice]}"
    if [ "$state" = "connected" ]; then
        if bluetoothctl disconnect "$mac"; then
            notify-send "Bluetooth" "Disconnected"
        else
            notify-send -u critical "Bluetooth" "Failed to disconnect"
        fi
    else
        if bluetoothctl connect "$mac"; then
            notify-send "Bluetooth" "Connected"
        else
            notify-send -u critical "Bluetooth" "Failed to connect"
        fi
    fi
    ;;
esac
