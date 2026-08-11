#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ◈ DOUBLE-CLICK FULLSCREEN TOGGLE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Detects double-click by checking timing between
# two consecutive calls. If < 400ms apart, toggle
# fullscreen (maximize). Otherwise, do nothing.

LOCKFILE="/tmp/.dblclick_fs_$$_lock"
TIMEFILE="/tmp/.dblclick_fs_time"
THRESHOLD=400  # ms

# Get current time in milliseconds
now_ms() {
    echo $(( $(date +%s%N) / 1000000 ))
}

NOW=$(now_ms)

if [[ -f "$TIMEFILE" ]]; then
    LAST=$(cat "$TIMEFILE" 2>/dev/null)
    DIFF=$(( NOW - LAST ))
    
    if (( DIFF > 0 && DIFF < THRESHOLD )); then
        # Double-click detected! Toggle maximize
        hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "set" })' 2>/dev/null
        rm -f "$TIMEFILE"
        exit 0
    fi
fi

# First click — record timestamp
echo "$NOW" > "$TIMEFILE"
