#!/usr/bin/env bash

# Switches the system cursor to match the current Matugen theme.
# The theme is always dark-mode, so the cursor follows the ACCENT color:
#   - warm accents (red/orange/yellow) -> Bibata-Modern-Amber (orange)
#   - cool/neutral accents              -> Bibata-Modern-Ice (white)
#   - light scheme (future/edge case)   -> Bibata-Modern-Classic (black)

QS_JSON="$HOME/.config/hypr/scripts/quickshell/qs_colors.json"
STATE_FILE="$HOME/.config/hypr/.cursor_theme"

CURSOR_SIZE="${CURSOR_SIZE:-24}"
DEFAULT_THEME="Bibata-Modern-Ice"

pick_theme() {
    local accent base
    accent=$(jq -r '.blue // empty' "$QS_JSON" 2>/dev/null)
    base=$(jq -r '.base // empty' "$QS_JSON" 2>/dev/null)

    if [ -z "$accent" ] || [ "$accent" = "null" ]; then
        echo "$DEFAULT_THEME"
        return
    fi

    python3 -c "
import sys, colorsys

accent = '$accent'.lstrip('#')
base = '$base'.lstrip('#')

def hex_to_hsv(h):
    h = h.lstrip('#')
    if len(h) != 6:
        return 0.0, 0.0, 0.0
    r, g, b = (int(h[i:i+2], 16) / 255 for i in (0, 2, 4))
    return colorsys.rgb_to_hsv(r, g, b)

ah, _, _ = hex_to_hsv(accent)
bh, _, bv = hex_to_hsv(base)
hue_deg = ah * 360

# Light background (a light Matugen scheme) -> dark cursor for contrast
if bv > 0.6:
    print('Bibata-Modern-Classic')
# Warm accent (red/orange/yellow) -> orange cursor that matches the theme
elif hue_deg <= 60 or hue_deg >= 330:
    print('Bibata-Modern-Amber')
else:
    print('Bibata-Modern-Ice')
"
}

THEME=$(pick_theme)
echo "$THEME" > "$STATE_FILE"

hyprctl setcursor "$THEME" "$CURSOR_SIZE" 2>/dev/null

if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.desktop.interface cursor-theme "$THEME" 2>/dev/null
    gsettings set org.gnome.desktop.interface cursor-size "$CURSOR_SIZE" 2>/dev/null
fi
