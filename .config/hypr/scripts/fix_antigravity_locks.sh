#!/usr/bin/env bash

# ─────────────────────────────────────────────────────────────────────────────
# Clear stale Antigravity IDE locks left behind by a session crash.
#
# The old version of this script only removed locks whose owning PID was dead.
# That misses the case that actually happens when Hyprland segfaults: the IDE
# is still ALIVE as an orphan, but its Wayland connection is gone. Chromium's
# singleton handshake then sees a live lock and refuses to start, reporting
# "Antigravity IDE is already running" even though the window is unreachable.
#
# So an owner counts as an orphan — and gets killed and unlocked — when its
# logind session or its Wayland socket belongs to a session that is no longer
# current. A healthy owner in the current session is always left alone.
# ─────────────────────────────────────────────────────────────────────────────

CONFIG_DIR="$HOME/.config/Antigravity IDE"
[ -d "$CONFIG_DIR" ] || exit 0

CURRENT_SESSION="${XDG_SESSION_ID:-}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# A process is an orphan if its Wayland socket no longer exists in the runtime
# dir, or it belongs to a different logind session than ours.
is_orphan() {
    local pid="$1" env_session env_wayland

    [ -r "/proc/$pid/environ" ] || return 1   # can't verify -> assume healthy

    env_session=$(tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null | sed -n 's/^XDG_SESSION_ID=//p')
    env_wayland=$(tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null | sed -n 's/^WAYLAND_DISPLAY=//p')

    if [ -n "$CURRENT_SESSION" ] && [ -n "$env_session" ] && [ "$env_session" != "$CURRENT_SESSION" ]; then
        return 0
    fi

    # The compositor socket this process was talking to is gone.
    if [ -n "$env_wayland" ] && [ ! -S "$RUNTIME_DIR/$env_wayland" ]; then
        return 0
    fi

    return 1
}

reap() {
    local pid="$1" reason="$2"

    echo "Removing stale Antigravity IDE locks ($reason, pid $pid)..."
    kill -TERM "$pid" 2>/dev/null
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.2
    done
    kill -KILL "$pid" 2>/dev/null

    rm -f "$CONFIG_DIR/SingletonLock" \
          "$CONFIG_DIR/SingletonSocket" \
          "$CONFIG_DIR/SingletonCookie" \
          "$CONFIG_DIR/code.lock"
}

# Electron/Chromium SingletonLock is a symlink to "<host>-<pid>".
if [ -e "$CONFIG_DIR/SingletonLock" ]; then
    PID=$(readlink "$CONFIG_DIR/SingletonLock" 2>/dev/null | awk -F'-' '{print $NF}')
    if [ -n "$PID" ]; then
        if ! kill -0 "$PID" 2>/dev/null; then
            reap "$PID" "dead owner"
        elif is_orphan "$PID"; then
            reap "$PID" "orphan from a dead session"
        fi
    else
        rm -f "$CONFIG_DIR/SingletonLock" "$CONFIG_DIR/SingletonSocket" "$CONFIG_DIR/SingletonCookie"
    fi
fi

# VSCode-style code.lock is a plain PID file.
if [ -e "$CONFIG_DIR/code.lock" ]; then
    PID=$(tr -cd '0-9' <"$CONFIG_DIR/code.lock" 2>/dev/null)
    if [ -n "$PID" ]; then
        if ! kill -0 "$PID" 2>/dev/null; then
            reap "$PID" "dead owner"
        elif is_orphan "$PID"; then
            reap "$PID" "orphan from a dead session"
        fi
    else
        rm -f "$CONFIG_DIR/code.lock"
    fi
fi

exit 0