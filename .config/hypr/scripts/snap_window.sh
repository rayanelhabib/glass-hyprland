#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ◈ SNAP WINDOW — Windows-style window snapping for Hyprland
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
#  Usage: snap_window.sh <zone>
#
#  Zones:
#    left, right        — Half screen (left/right)
#    top, bottom        — Half screen (top/bottom)
#    topleft, topright   — Quarter screen (corners)
#    bottomleft, bottomright
#    maximize           — Fullscreen (non-exclusive)
#    center             — Centered at 70% size
#    third-left, third-center, third-right — Thirds
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ZONE="${1:-center}"
GAP=4

# Get active monitor geometry
MONITOR_JSON=$(hyprctl activeworkspace -j 2>/dev/null)
MONITOR_ID=$(echo "$MONITOR_JSON" | jq -r '.monitorID // 0')

MON_INFO=$(hyprctl monitors -j 2>/dev/null | jq ".[$MONITOR_ID]")
MON_W=$(echo "$MON_INFO" | jq '.width // 1920')
MON_H=$(echo "$MON_INFO" | jq '.height // 1080')
MON_X=$(echo "$MON_INFO" | jq '.x // 0')
MON_Y=$(echo "$MON_INFO" | jq '.y // 0')
SCALE=$(echo "$MON_INFO" | jq '.scale // 1.0')

# Reserved space (top bar, etc.)
RESERVED=$(echo "$MON_INFO" | jq -r '.reserved // [0,0,0,0]')
RES_TOP=$(echo "$RESERVED" | jq '.[1] // 0')
RES_BOT=$(echo "$RESERVED" | jq '.[3] // 0')
RES_LEFT=$(echo "$RESERVED" | jq '.[0] // 0')
RES_RIGHT=$(echo "$RESERVED" | jq '.[2] // 0')

# Usable area (after reserved space and gaps)
AREA_X=$((MON_X + RES_LEFT + GAP))
AREA_Y=$((MON_Y + RES_TOP + GAP))
AREA_W=$((MON_W - RES_LEFT - RES_RIGHT - GAP * 2))
AREA_H=$((MON_H - RES_TOP - RES_BOT - GAP * 2))

# Make sure window is floating first
WINDOW_JSON=$(hyprctl activewindow -j 2>/dev/null)
IS_FLOATING=$(echo "$WINDOW_JSON" | jq '.floating // false')

# A fullscreen/maximized window can't be moved or resized — unset it first so
# the snap applies instead of silently doing nothing.
FS_STATE=$(echo "$WINDOW_JSON" | jq '.fullscreen // 0')
if [[ "$FS_STATE" != "0" ]]; then
    hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "fullscreen", action = "unset" })' 2>/dev/null
    hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "unset" })' 2>/dev/null
    sleep 0.05
fi

if [[ "$IS_FLOATING" != "true" && "$ZONE" != "maximize" ]]; then
    hyprctl dispatch 'hl.dsp.window.float({ action = "toggle" })' 2>/dev/null
    sleep 0.05
fi

# Calculate target position and size based on zone
case "$ZONE" in
    left)
        X=$AREA_X
        Y=$AREA_Y
        W=$(( AREA_W / 2 - GAP / 2 ))
        H=$AREA_H
        ;;
    right)
        W=$(( AREA_W / 2 - GAP / 2 ))
        X=$(( AREA_X + AREA_W - W ))
        Y=$AREA_Y
        H=$AREA_H
        ;;
    top)
        X=$AREA_X
        Y=$AREA_Y
        W=$AREA_W
        H=$(( AREA_H / 2 - GAP / 2 ))
        ;;
    bottom)
        H=$(( AREA_H / 2 - GAP / 2 ))
        X=$AREA_X
        Y=$(( AREA_Y + AREA_H - H ))
        W=$AREA_W
        ;;
    topleft)
        X=$AREA_X
        Y=$AREA_Y
        W=$(( AREA_W / 2 - GAP / 2 ))
        H=$(( AREA_H / 2 - GAP / 2 ))
        ;;
    topright)
        W=$(( AREA_W / 2 - GAP / 2 ))
        X=$(( AREA_X + AREA_W - W ))
        Y=$AREA_Y
        H=$(( AREA_H / 2 - GAP / 2 ))
        ;;
    bottomleft)
        X=$AREA_X
        H=$(( AREA_H / 2 - GAP / 2 ))
        Y=$(( AREA_Y + AREA_H - H ))
        W=$(( AREA_W / 2 - GAP / 2 ))
        ;;
    bottomright)
        W=$(( AREA_W / 2 - GAP / 2 ))
        H=$(( AREA_H / 2 - GAP / 2 ))
        X=$(( AREA_X + AREA_W - W ))
        Y=$(( AREA_Y + AREA_H - H ))
        ;;
    third-left)
        X=$AREA_X
        Y=$AREA_Y
        W=$(( AREA_W / 3 - GAP * 2 / 3 ))
        H=$AREA_H
        ;;
    third-center)
        W=$(( AREA_W / 3 - GAP * 2 / 3 ))
        X=$(( AREA_X + (AREA_W - W) / 2 ))
        Y=$AREA_Y
        H=$AREA_H
        ;;
    third-right)
        W=$(( AREA_W / 3 - GAP * 2 / 3 ))
        X=$(( AREA_X + AREA_W - W ))
        Y=$AREA_Y
        H=$AREA_H
        ;;
    maximize)
        hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "set" })' 2>/dev/null
        exit 0
        ;;
    center)
        W=$(( AREA_W * 70 / 100 ))
        H=$(( AREA_H * 75 / 100 ))
        X=$(( AREA_X + (AREA_W - W) / 2 ))
        Y=$(( AREA_Y + (AREA_H - H) / 2 ))
        ;;
    *)
        echo "Unknown zone: $ZONE" >&2
        exit 1
        ;;
esac

# Apply the snap — resize FIRST (resize keeps the window centered, which
# shifts x/y), then move to the exact target position so the final result
# lands precisely on the zone.
hyprctl --batch "dispatch hl.dsp.window.resize({ x = $W, y = $H }); dispatch hl.dsp.window.move({ x = $X, y = $Y })" 2>/dev/null
