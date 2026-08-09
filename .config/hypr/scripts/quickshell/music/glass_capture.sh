#!/usr/bin/env bash
# glass_capture.sh <x> <y> <w> <h>
# grim-captures the real desktop region behind the glass card (expanded by the
# pad margin), applies the ShojiWM blur-layer look (gaussian + mix(tex, white,
# 0.12) * 1.03 lift + mild sat), and writes
# $HOME/.cache/quickshell/music/glass_backdrop.png.
#
# The pad is shrunk as needed so the whole capture rect stays on-screen and
# symmetric around the card — the popup must render the backdrop with the SAME
# margin (LiquidCard.marginOverride), or the refracted content misaligns.
#
# Capturing the live desktop (not a wallpaper file) is what makes the glass a
# true window into what's behind it — wallpaper, topbar, everything.

OUT="$HOME/.cache/quickshell/music/glass_backdrop.png"
mkdir -p "$(dirname "$OUT")"

X="${1:-0}"; Y="${2:-0}"; W="${3:-100}"; H="${4:-100}"

# Screen size
read -r SW SH < <(hyprctl monitors -j | jq -r '.[0] | "\(.width) \(.height)"')

maxdim=$(( W > H ? W : H ))
rawpx=$(( maxdim * 15 / 100 ))

# Fit margin: shrink to stay on-screen symmetrically
fmin=8
px=$rawpx
[ "$X" -lt "$px" ] && px=$X
[ "$Y" -lt "$px" ] && px=$Y
[ $(( SW - X - W )) -lt "$px" ] && px=$(( SW - X - W ))
[ $(( SH - Y - H )) -lt "$px" ] && px=$(( SH - Y - H ))
[ "$px" -lt "$fmin" ] && px=$fmin

CX=$(( X - px )); CY=$(( Y - px )); CW=$(( W + 2*px )); CH=$(( H + 2*px ))

RAW="$HOME/.cache/quickshell/music/glass_backdrop_raw.png"
if grim -g "${CX},${CY} ${CW}x${CH}" "$RAW" 2>/dev/null && [ -s "$RAW" ]; then
    mv "$RAW" "$OUT"
fi

echo "$OUT"
