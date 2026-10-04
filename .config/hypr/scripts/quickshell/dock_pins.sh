#!/usr/bin/env bash
# dock_pins.sh — Parse .desktop files and output JSON for the Dock's pinned items.
# Reads pinned app IDs from command arguments or ~/.config/hypr/settings.json

SETTINGS_FILE="$HOME/.config/hypr/settings.json"
DEFAULT_PINS=("org.gnome.Nautilus" "kitty" "brave-browser" "antigravity-ide" "discord" "spotify-launcher")

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
    for dir in "${SEARCH_DIRS[@]}"; do
        local match_wm=$(grep -il "StartupWMClass=$id" "$dir"/*.desktop 2>/dev/null | head -n 1)
        [[ -n "$match_wm" ]] && echo "$match_wm" && return
        local match_exec=$(grep -il "Exec=.*$id" "$dir"/*.desktop 2>/dev/null | head -n 1)
        [[ -n "$match_exec" ]] && echo "$match_exec" && return
    done
    return 1
}

parse_desktop() {
    local file="$1" id="$2"
    local name="" icon="" exec_cmd="" wm_class=""
    local in_desktop_entry=false

    while IFS= read -r line; do
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

    exec_cmd=$(echo "$exec_cmd" | sed 's/ %[UuFfcidDnNvmk]//g; s/--url -- //g')

    local match
    if [[ -n "$wm_class" ]]; then
        match=$(echo "$wm_class" | tr '[:upper:]' '[:lower:]')
    else
        match=$(basename "$(echo "$exec_cmd" | awk '{print $1}')" | tr '[:upper:]' '[:lower:]')
    fi

    jq -n --arg id "$id" --arg name "$name" --arg icon "$icon" \
          --arg cmd "$exec_cmd" --arg match "$match" \
          '{id: $id, name: $name, icon: $icon, fallback: "", cmd: $cmd, match: $match}'
}

# Collect IDs
app_ids=()
if [[ $# -gt 0 ]]; then
    app_ids=("$@")
elif [[ -f "$SETTINGS_FILE" ]]; then
    mapfile -t app_ids < <(jq -r '.dockPins[]? // empty' "$SETTINGS_FILE" 2>/dev/null)
fi

if [[ ${#app_ids[@]} -eq 0 ]]; then
    app_ids=("${DEFAULT_PINS[@]}")
fi

items=()
for app_id in "${app_ids[@]}"; do
    desktop_file=$(find_desktop "$app_id") || continue
    json=$(parse_desktop "$desktop_file" "$app_id") || continue
    items+=("$json")
done

if [[ ${#items[@]} -gt 0 ]]; then
    printf '%s\n' "${items[@]}" | jq -sc '.'
else
    echo "[]"
fi
