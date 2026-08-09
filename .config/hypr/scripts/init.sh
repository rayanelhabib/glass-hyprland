#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"
qs_ensure_cache "wallpaper_picker"

FLAG="$QS_STATE_WALLPAPER_PICKER/wallpaper_initialized"
CACHE_IMG="$QS_CACHE_WALLPAPER_PICKER/current_wallpaper.png"

RELOAD_SCRIPT_PATH="$(dirname "${BASH_SOURCE[0]}")/quickshell/wallpaper/matugen_reload.sh"
APPLY_SCRIPT_PATH="$(dirname "${BASH_SOURCE[0]}")/theme_apply.sh"

# If the flag exists, just run matugen and the reload script, then exit
if [ -f "$FLAG" ]; then
    # Use the cached wallpaper image for matugen
    if [ -f "$CACHE_IMG" ] && [ -f "$APPLY_SCRIPT_PATH" ]; then
        chmod +x "$APPLY_SCRIPT_PATH"
        last_name=$(cat "$HOME/.local/state/quickshell/current_wallpaper_name" 2>/dev/null)
        bash "$APPLY_SCRIPT_PATH" "$CACHE_IMG" "$last_name"
    fi
    
    if [ -f "$RELOAD_SCRIPT_PATH" ]; then
        chmod +x "$RELOAD_SCRIPT_PATH"
        bash "$RELOAD_SCRIPT_PATH"
    fi
    
    exit 0
fi

# If no wallpaper dir is set, default to a common one to prevent find from failing
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"

sleep 0.5

# Find a random file
file=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) 2>/dev/null | shuf -n 1)

if [ -n "$file" ]; then
    # Copy to our persistent cache location instead of /tmp
    cp "$file" "$CACHE_IMG"
    
    awww img "$file" --transition-type any --transition-pos 0.5,0.5 --transition-fps 144 --transition-duration 1 &
    
    if [ -f "$APPLY_SCRIPT_PATH" ]; then
        chmod +x "$APPLY_SCRIPT_PATH"
        bash "$APPLY_SCRIPT_PATH" "$CACHE_IMG" "$(basename "$file")"
    fi
    
    # Execute reload script if it exists
    if [ -f "$RELOAD_SCRIPT_PATH" ]; then
        chmod +x "$RELOAD_SCRIPT_PATH"
        bash "$RELOAD_SCRIPT_PATH"
    fi
fi

mkdir -p "$(dirname "$FLAG")"
touch "$FLAG"
