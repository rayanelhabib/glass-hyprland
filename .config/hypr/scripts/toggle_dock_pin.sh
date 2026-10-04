#!/usr/bin/env bash

# toggle_dock_pin.sh — Pin/Unpin applications to/from the Quickshell Dock persistently.
# Usage: toggle_dock_pin.sh <app_id> [pin|unpin|toggle]

SETTINGS_FILE="$HOME/.config/hypr/settings.json"
[ ! -f "$SETTINGS_FILE" ] && exit 1

APP_ID="$1"
ACTION="${2:-toggle}"

if [ -z "$APP_ID" ]; then
    exit 1
fi

# Default pins list
DEFAULT_PINS='["org.gnome.Nautilus","kitty","brave-browser","antigravity-ide","discord","spotify-launcher"]'

# Extract current dockPins from settings.json or fallback
CURRENT_PINS=$(jq -c '.dockPins // '$DEFAULT_PINS "$SETTINGS_FILE" 2>/dev/null)

if [ "$ACTION" == "pin" ]; then
    NEW_PINS=$(echo "$CURRENT_PINS" | jq -c --arg id "$APP_ID" 'if contains([$id]) then . else . + [$id] end')
elif [ "$ACTION" == "unpin" ]; then
    NEW_PINS=$(echo "$CURRENT_PINS" | jq -c --arg id "$APP_ID" 'map(select(. != $id))')
else
    NEW_PINS=$(echo "$CURRENT_PINS" | jq -c --arg id "$APP_ID" 'if contains([$id]) then map(select(. != $id)) else . + [$id] end')
fi

# Save updated JSON safely
TMP_FILE=$(mktemp)
jq --argjson pins "$NEW_PINS" '.dockPins = $pins' "$SETTINGS_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$SETTINGS_FILE"
