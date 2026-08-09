#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"

PIPE="$QS_RUN_DIR/qs_audio_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null

cleanup() {
    rm -f "$PIPE"
    [ -n "$MONITOR_PID" ] && kill "$MONITOR_PID" 2>/dev/null
    pkill -P $$ 2>/dev/null
}
trap cleanup EXIT INT TERM

# Run pactl isolated and capture its exact PID to prevent PipeWire connection exhaustion
LC_ALL=C pactl subscribe 2>/dev/null > "$PIPE" &
MONITOR_PID=$!

grep -m 1 -E "sink|server" < "$PIPE" > /dev/null
cleanup
