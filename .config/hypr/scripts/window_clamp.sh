#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ◈ WINDOW CLAMP DAEMON — Prevent floating windows from
#    going above the top bar or outside the screen.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Listens to Hyprland socket2 events and clamps floating
# window positions when they settle outside the usable area.

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
MIN_Y=40  # Top bar height (36px) + small gap

clamp_active_window() {
    local win
    win=$(hyprctl activewindow -j 2>/dev/null) || return

    local is_float x y w h
    is_float=$(echo "$win" | jq -r '.floating // false')
    [[ "$is_float" != "true" ]] && return

    x=$(echo "$win" | jq '.at[0] // 0')
    y=$(echo "$win" | jq '.at[1] // 0')
    w=$(echo "$win" | jq '.size[0] // 100')
    h=$(echo "$win" | jq '.size[1] // 100')

    # Get monitor dimensions
    local mon_id mon_w mon_h
    mon_id=$(hyprctl activeworkspace -j 2>/dev/null | jq '.monitorID // 0')
    local mon
    mon=$(hyprctl monitors -j 2>/dev/null | jq ".[$mon_id]")
    mon_w=$(echo "$mon" | jq '.width // 1920')
    mon_h=$(echo "$mon" | jq '.height // 1080')

    local clamped=false new_x=$x new_y=$y

    # Clamp top — don't go above the bar
    if (( y < MIN_Y )); then
        new_y=$MIN_Y
        clamped=true
    fi

    # Clamp left — keep at least 100px visible
    if (( x + w < 100 )); then
        new_x=$(( 100 - w ))
        clamped=true
    fi

    # Clamp right — keep at least 100px visible
    if (( x > mon_w - 100 )); then
        new_x=$(( mon_w - 100 ))
        clamped=true
    fi

    # Clamp bottom — keep at least 50px of title visible
    if (( y > mon_h - 50 )); then
        new_y=$(( mon_h - 50 ))
        clamped=true
    fi

    if [[ "$clamped" == "true" ]]; then
        hyprctl dispatch movewindowpixel "exact $new_x $new_y,activewindow" 2>/dev/null
    fi
}

# Kill any previous instance
PIDFILE="/tmp/window_clamp_daemon.pid"
if [[ -f "$PIDFILE" ]]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null
fi
echo $$ > "$PIDFILE"

trap 'rm -f "$PIDFILE"; exit 0' EXIT INT TERM

# Listen for relevant events and clamp after drag settles
last_clamp=0
socat -U - "UNIX-CONNECT:$SOCKET" 2>/dev/null | while IFS= read -r event; do
    case "$event" in
        changefloatingmode*|openwindow*)
            # Small delay to let the drag finish settling
            sleep 0.15
            clamp_active_window
            ;;
    esac
done
