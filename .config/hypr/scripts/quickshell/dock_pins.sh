#!/usr/bin/env bash
# dock_pins.sh — Parse .desktop files and output JSON for the Dock's pinned items.
# Usage: dock_pins.sh org.gnome.Nautilus kitty brave-browser ...

SEARCH_DIRS=(
    "$HOME/.local/share/applications"
    "/usr/share/applications"
    "/usr/local/share/applications"
)

find_desktop() {
    local id="$1"
    for dir in "${SEARCH_DIRS[@]}"; do
        local f="$dir/$id.desktop"
        [[ -f "$f" ]] && echo "$f" && return
    done
    return 1
}

parse_desktop() {
    local file="$1" id="$2"
    local name="" icon="" exec_cmd="" wm_class=""
    local in_desktop_entry=false

    while IFS= read -r line; do
        # Only parse the [Desktop Entry] section (stop at next section)
        if [[ "$line" == "[Desktop Entry]" ]]; then
            in_desktop_entry=true
            continue
        elif [[ "$line" == "["* ]]; then
            in_desktop_entry=false
            continue
        fi

        $in_desktop_entry || continue

        case "$line" in
            Name=*)
                [[ -z "$name" ]] && name="${line#Name=}"
                ;;
            Icon=*)
                [[ -z "$icon" ]] && icon="${line#Icon=}"
                ;;
            Exec=*)
                [[ -z "$exec_cmd" ]] && exec_cmd="${line#Exec=}"
                ;;
            StartupWMClass=*)
                [[ -z "$wm_class" ]] && wm_class="${line#StartupWMClass=}"
                ;;
        esac
    done < "$file"

    # Clean Exec: strip field codes like %U %F %u etc.
    exec_cmd=$(echo "$exec_cmd" | sed 's/ %[UuFfcidDnNvmk]//g; s/--url -- //g')

    # Match pattern: use WMClass if available, else derive from exec or id
    local match
    if [[ -n "$wm_class" ]]; then
        match=$(echo "$wm_class" | tr '[:upper:]' '[:lower:]')
    else
        # Use the basename of exec command
        match=$(basename "$(echo "$exec_cmd" | awk '{print $1}')" | tr '[:upper:]' '[:lower:]')
    fi

    # Emit JSON (using jq for safe escaping)
    jq -n --arg id "$id" --arg name "$name" --arg icon "$icon" \
          --arg cmd "$exec_cmd" --arg match "$match" \
          '{id: $id, name: $name, icon: $icon, fallback: "", cmd: $cmd, match: $match}'
}

# --- Main ---
items=()
for app_id in "$@"; do
    desktop_file=$(find_desktop "$app_id") || continue
    json=$(parse_desktop "$desktop_file" "$app_id") || continue
    items+=("$json")
done

# Output as JSON array
if [[ ${#items[@]} -gt 0 ]]; then
    printf '%s\n' "${items[@]}" | jq -sc '.'
else
    echo "[]"
fi
