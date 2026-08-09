#!/usr/bin/env bash

# Generates a Matugen theme for a wallpaper.
#   - Known wallpapers (theme_signatures.json) get a signature hue, so each one
#     produces a clearly distinct theme (bar, borders, icons, cursor all follow).
#   - New/unknown wallpapers are themed from their own most vivid color.
#
# Usage: theme_apply.sh <IMAGE> [ORIGINAL_NAME]
#   ORIGINAL_NAME lets callers using a cached copy keep the real filename for
#   the signature lookup (init.sh at boot).

SCRIPTS_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
RELOAD_SCRIPT="$SCRIPTS_DIR/quickshell/wallpaper/matugen_reload.sh"
MAP_FILE="$SCRIPTS_DIR/theme_signatures.json"

DEBUG_LOG="/tmp/opencode/theme_apply_debug.log"
log() { echo "[$(date +'%H:%M:%S')] $*" >> "$DEBUG_LOG"; }

IMAGE="${1:-}"
ORIGINAL_NAME="${2:-}"
log "START args='$IMAGE' name='$ORIGINAL_NAME'"
[ -n "$IMAGE" ] && [ -f "$IMAGE" ] || { log "EXIT file missing: '$IMAGE'"; exit 1; }

NAME="$ORIGINAL_NAME"
[ -z "$NAME" ] && NAME="$(basename "$IMAGE")"

# Remember the applied wallpaper so a later boot (init.sh) can re-theme correctly
mkdir -p "$HOME/.local/state/quickshell"
echo "$NAME" > "$HOME/.local/state/quickshell/current_wallpaper_name"

hue=""
if [ -f "$MAP_FILE" ]; then
    hue=$(jq -r --arg name "$NAME" '.[$name] // empty' "$MAP_FILE" 2>/dev/null)
fi

if [ -n "$hue" ] && [ "$hue" != "null" ]; then
    SOLID="$(mktemp --suffix=.png /tmp/qs_sig_XXXXXX)"
    log "SIGNATURE hue=$hue solid=$SOLID"
    magick -size 64x64 "xc:hsl(${hue},95%,55%)" "$SOLID" 2>>"$DEBUG_LOG"
    matugen image "$SOLID" --source-color-index 0 --mode dark 2>>"$DEBUG_LOG"
    log "MATUGEN-SIG exit=$?"
    rm -f "$SOLID"
else
    log "AUTO image=$IMAGE"
    matugen image "$IMAGE" --prefer saturation --mode dark 2>>"$DEBUG_LOG"
    log "MATUGEN-AUTO exit=$?"
fi

if [ -f "$RELOAD_SCRIPT" ]; then
    chmod +x "$RELOAD_SCRIPT"
    bash "$RELOAD_SCRIPT"
fi
log "DONE"
