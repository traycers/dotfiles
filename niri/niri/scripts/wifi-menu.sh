#!/usr/bin/env bash
# Wi-Fi picker via fuzzel + NetworkManager (nmcli). Lists nearby networks,
# connects to a known profile directly or prompts for a password (also via
# fuzzel) for a new one.
set -euo pipefail

nmcli device wifi rescan >/dev/null 2>&1 || true

# Fields ordered with SSID last: any ':' embedded in an SSID just becomes
# part of the final `read` variable instead of breaking the parse.
mapfile -t lines < <(nmcli -t -f IN-USE,SECURITY,SIGNAL,SSID device wifi list | sort -t: -k3 -rn)

declare -A entry_for_label
menu=()

for line in "${lines[@]}"; do
    IFS=: read -r inuse security signal ssid <<<"$line"
    [ -n "$ssid" ] || continue

    mark=""
    [ "$inuse" = "*" ] && mark=" (connected)"
    lock=""
    [ -n "$security" ] && lock=" 🔒"

    label="${ssid}${lock} - ${signal}%${mark}"
    [ -n "${entry_for_label[$label]:-}" ] && continue # dedupe repeat SSIDs (multiple APs)

    menu+=("$label")
    entry_for_label["$label"]="$ssid|$security"
done

choice=$(printf '%s\n' "${menu[@]}" | fuzzel --dmenu --prompt "wifi> ")
[ -n "$choice" ] || exit 0

IFS='|' read -r ssid security <<<"${entry_for_label[$choice]}"

if nmcli -t -f NAME connection show | grep -qxF "$ssid"; then
    if output=$(nmcli connection up "$ssid" 2>&1); then
        notify-send "Wi-Fi" "Connected to $ssid"
    else
        notify-send -u critical "Wi-Fi" "$output"
    fi
elif [ -n "$security" ]; then
    password=$(fuzzel --dmenu --password --prompt "password for $ssid> ")
    [ -n "$password" ] || exit 0
    if output=$(nmcli device wifi connect "$ssid" password "$password" 2>&1); then
        notify-send "Wi-Fi" "Connected to $ssid"
    else
        notify-send -u critical "Wi-Fi" "$output"
    fi
else
    if output=$(nmcli device wifi connect "$ssid" 2>&1); then
        notify-send "Wi-Fi" "Connected to $ssid"
    else
        notify-send -u critical "Wi-Fi" "$output"
    fi
fi
