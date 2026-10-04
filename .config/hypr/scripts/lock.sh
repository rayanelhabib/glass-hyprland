#!/usr/bin/env bash

# Launch the lock screen.
#
# Locking uses the Wayland ext-session-lock protocol (WlSessionLock in
# Lock.qml). That protocol only asks the compositor to blank the outputs — it
# does not tear down the session, so running apps are untouched by locking.

# Already locked? A second instance would fight the first one for the
# ext-session-lock and crash the WlSessionLock handshake in Hyprland.
if pgrep -f "quickshell.*Lock\.qml" >/dev/null 2>&1; then
    exit 0
fi

# Refuse to lock against a compositor we cannot reach. Without this the lock
# process starts, never gets a session lock, and sits there useless.
if ! hyprctl version >/dev/null 2>&1; then
    exit 0
fi

# Source and initialize quickshell dynamic caching
source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"
qs_ensure_cache "lock"

exec quickshell -n -p ~/.config/hypr/scripts/quickshell/Lock.qml > /tmp/qs_lock_crash.log 2>&1