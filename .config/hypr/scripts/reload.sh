#!/usr/bin/env bash

# Reload Hyprland config + the quickshell shell WITHOUT killing anything.
#
# Never `pkill quickshell` here: quickshell hosts the shell chrome AND the
# WlSessionLock instance, so killing it drops the lock screen and every
# QS window, and it takes the running apps' session shell down with it.
# Quickshell is reloaded over its own IPC instead.

SHELL_QML="$HOME/.config/hypr/scripts/quickshell/Shell.qml"

# Safe now that config/plugins.lua no longer loads plugins: the config plugin
# list stays stable, so Hyprland's reload path cannot recurse into a segfault.
hyprctl reload >/dev/null 2>&1

# Re-assert the glass config — idempotent, and survives the reload above.
"$HOME/.config/hypr/scripts/hyprglass_startup.sh" >/dev/null 2>&1 &

# Reload the shell over IPC; only start it if it isn't running at all.
if pgrep -f "quickshell.*Shell.qml" >/dev/null 2>&1; then
    quickshell -p "$SHELL_QML" ipc call main forceReload >/dev/null 2>&1
else
    nohup quickshell -p "$SHELL_QML" >/dev/null 2>&1 &
    disown
fi

if command -v swayosd-client >/dev/null 2>&1; then
    swayosd-client --custom-icon "system-reboot" --custom-message "Hyprland Reloaded" >/dev/null 2>&1 &
elif command -v notify-send >/dev/null 2>&1; then
    notify-send "Hyprland" "Configuration & desktop UI reloaded" -i system-reboot >/dev/null 2>&1 &
fi