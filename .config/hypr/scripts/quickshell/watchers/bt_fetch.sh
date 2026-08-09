#!/usr/bin/env bash

get_bt_info() {
    local show_out
    show_out=$(LC_ALL=C timeout 0.5 bluetoothctl show 2>/dev/null)
    
    local status="off"
    if echo "$show_out" | grep -q "Powered: yes"; then
        status="on"
    fi
    
    local icon="󰂲"
    local connected="Off"
    
    if [ "$status" = "on" ]; then
        local dev_out
        dev_out=$(LC_ALL=C timeout 0.5 bluetoothctl devices Connected 2>/dev/null)
        if [ -n "$dev_out" ]; then
            icon="󰂱"
            connected=$(echo "$dev_out" | head -n1 | cut -d' ' -f3-)
            [ -z "$connected" ] && connected="Connected"
        else
            icon="󰂯"
            connected="Disconnected"
        fi
    fi
    
    jq -n -c --arg status "$status" --arg icon "$icon" --arg connected "$connected" \
        '{status: $status, icon: $icon, connected: $connected}'
}

toggle_bt() {
    if LC_ALL=C timeout 0.5 bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
        LC_ALL=C timeout 0.5 bluetoothctl power off 2>/dev/null
    else
        LC_ALL=C timeout 0.5 bluetoothctl power on 2>/dev/null
    fi
}

case $1 in
    --toggle) toggle_bt ;;
    *) get_bt_info ;;
esac
