#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"

PIPE="$QS_RUN_DIR/qs_network_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null

cleanup() {
    rm -f "$PIPE"
    [ -n "$MONITOR_PID" ] && kill "$MONITOR_PID" 2>/dev/null
    pkill -P $$ 2>/dev/null
}
trap cleanup EXIT INT TERM

# Run nmcli completely isolated and capture its exact PID
LC_ALL=C nmcli monitor 2>/dev/null > "$PIPE" &
MONITOR_PID=$!

# Grep blocks until it reads the first match from the FIFO, then exits.
# Exiting triggers the trap, immediately killing nmcli and ending the script.
grep -m 1 -iwE "connected|disconnected|enabled|disabled|activated|deactivated|available|unavailable" < "$PIPE" > /dev/null
cleanup
