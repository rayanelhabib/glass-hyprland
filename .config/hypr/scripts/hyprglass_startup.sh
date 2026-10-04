#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# hyprglass loader — runs OUTSIDE Hyprland's config-reload path.
#
# WHY THIS IS A SCRIPT AND NOT LUA:
#   Calling hl.plugin.load() from config/plugins.lua makes Hyprland 0.56.1
#   recurse forever (reload -> postConfigReload -> handlePluginLoads -> reload)
#   and segfault, killing the entire session. See the comment in
#   config/plugins.lua. Loading from here keeps the compositor's config
#   plugin list stable, so `hyprctl reload` stays safe.
#
# The look is reproduced from the old custom "qsglass"/"qsglassbar" presets by
# setting hyprglass's own config keys directly (they are plain Hyprlang values).
# A named preset would win over these keys at render time, so default_preset is
# deliberately left empty and the values below are the source of truth.
# ─────────────────────────────────────────────────────────────────────────────

PLUGIN="/home/rayan/.local/share/hyprglass/hyprglass.so"
LOG="/tmp/hyprglass_startup.log"

# Built-in preset used for the top bar so its text stays readable over busy
# wallpapers. The old custom "qsglassbar" preset is gone (custom presets can
# only be registered from Lua, which is what caused the crash), so this picks
# the closest built-in. Change to "glass", "clear" or "high_contrast", or set
# to "" to make the top bar match the other layers exactly.
TOPBAR_PRESET="subtle"

log() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*" >>"$LOG"; }

# Wait for the compositor to answer IPC (autostart can race session startup).
for _ in $(seq 1 50); do
    hyprctl version >/dev/null 2>&1 && break
    sleep 0.2
done
if ! hyprctl version >/dev/null 2>&1; then
    log "compositor not reachable, aborting"
    exit 0
fi

[ -f "$PLUGIN" ] || { log "plugin missing: $PLUGIN"; exit 0; }

# Already loaded (e.g. re-run after a reload)? Then just (re)apply the config.
if ! hyprctl plugin list 2>/dev/null | grep -q "hyprglass.so"; then
    log "loading plugin"
    hyprctl plugin load "$PLUGIN" >/dev/null 2>&1
fi

# Wait for the plugin to register its config values before writing to them.
for _ in $(seq 1 50); do
    hyprctl getoption plugin:hyprglass:enabled >/dev/null 2>&1 && break
    sleep 0.2
done

set_kv() { hyprctl setconfig "$1" "$2" >/dev/null 2>&1; }

# Global: windows keep their normal look, glass is for the quickshell layers.
# default_preset is deliberately NOT set. Its built-in default is "default",
# which is not a real preset name, so preset resolution falls through to the
# dark:/light: overrides and then the global keys below — i.e. these values are
# what actually renders. Setting a real preset name here would shadow them all.
set_kv plugin:hyprglass:enabled 0
set_kv plugin:hyprglass:manage_window_blur 1
set_kv plugin:hyprglass:default_theme dark

# Base recipe (was the custom "qsglass" preset): backdrop passes through
# untouched, the liquid look comes entirely from the edge effects.
set_kv plugin:hyprglass:blur_strength 0.45
set_kv plugin:hyprglass:blur_iterations 2
set_kv plugin:hyprglass:lens_distortion 0.05
set_kv plugin:hyprglass:refraction_strength 1.2
set_kv plugin:hyprglass:chromatic_aberration 0.0
set_kv plugin:hyprglass:fresnel_strength 0.15
set_kv plugin:hyprglass:specular_strength 0.5
set_kv plugin:hyprglass:glass_opacity 0.92
set_kv plugin:hyprglass:edge_thickness 0.01
set_kv plugin:hyprglass:tint_color 0

# Neutralise the dimming/desaturation defaults that caused a grey cast.
for scope in dark light; do
    set_kv "plugin:hyprglass:$scope:brightness" 1.0
    set_kv "plugin:hyprglass:$scope:contrast" 1.0
    set_kv "plugin:hyprglass:$scope:saturation" 1.0
    set_kv "plugin:hyprglass:$scope:adaptive_dim" 0.0
    set_kv "plugin:hyprglass:$scope:adaptive_boost" 0.0
done

# Layer surfaces: only the quickshell chrome gets the glass treatment.
set_kv plugin:hyprglass:layers:enabled 1
set_kv plugin:hyprglass:layers:namespaces "qs-master, qs-topbar, qs-floating-overlay, qs-popups"
set_kv plugin:hyprglass:layers:namespace_mask_thresholds "qs-master=0.01"
set_kv plugin:hyprglass:layers:live_refresh 1

# Topbar keeps a frostier variant so text stays readable over busy wallpaper.
# Uses a built-in preset name since custom presets are no longer defined.
if [ -n "$TOPBAR_PRESET" ]; then
    set_kv plugin:hyprglass:layers:namespace_presets "qs-topbar:$TOPBAR_PRESET"
else
    set_kv plugin:hyprglass:layers:namespace_presets ""
fi

log "configured (topbar preset=${TOPBAR_PRESET:-none}, base=explicit global keys)"