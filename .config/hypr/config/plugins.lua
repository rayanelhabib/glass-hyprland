-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--  ◈ PLUGIN LOADING & CONFIG (hyprglass)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- NOTE: hyprglass must be loaded at STARTUP. Hot-loading it at runtime
-- (hyprctl plugin load/reload/unload) crashes Hyprland — the crashes were NOT
-- a version issue. Rebuilt against 0.56.1 headers.
hl.plugin.load("/home/rayan/.local/share/hyprglass/hyprglass.so")

if hl.plugin.hyprglass then
    hl.plugin.hyprglass.config({
        -- Windows keep their normal look; glass is enabled ONLY on the quickshell
        -- master layer surface (qs-master) via the `layers` block below.
        enabled = 0,

        default_theme = "dark",
        default_preset = "qsglass",

        layers = {
            enabled = 1,
            namespaces = "qs-master, qs-topbar, qs-floating-overlay, qs-popups",
            namespace_presets = "qs-master:qsglass, qs-topbar:qsglassbar, qs-floating-overlay:qsglass, qs-popups:qsglass",
            namespace_mask_thresholds = "qs-master=0.01",
            -- LIVE backdrop: re-sample + re-blur every frame so moving content
            -- (video, window drags, animated wallpaper) shows through the glass
            -- in real time. The alternative (0) caches a scene-generation
            -- snapshot and only refreshes on discrete events (focus/ws/layer
            -- moves) — cheaper but stale. Any non-zero value = live.
            live_refresh = 1
        }
    })

    -- Liquid glass (per hyprnux/hyprglass "glass" preset + the purple-lines
    -- shader recipe): keep the backdrop sharp (light blur), strong edge
    -- refraction + chromatic, glossy specular highlights. NO tint, NO frost
    -- veil — the backdrop's own color IS the glass. Dark override only
    -- neutralizes the dimming/desaturation defaults that caused the grey cast.
    -- Real-glass recipe: the backdrop passes through UNTOUCHED (zero blur, no
    -- tint, no brightness/saturation change — nothing to add colour or grey).
    -- The liquid look is carried entirely by the edge effects: refraction warp,
    -- chromatic fringing, lens distortion and specular gloss on the rim.
    hl.plugin.hyprglass.preset("qsglass", {
        inherits = "glass",
        blur_strength = 0.45,
        blur_iterations = 2,
        lens_distortion = 0.05,
        refraction_strength = 1.2,
        chromatic_aberration = 0.0,
        fresnel_strength = 0.15,
        specular_strength = 0.5,
        glass_opacity = 0.92,
        edge_thickness = 0.01,
        tint_color = 0,
        dark = {
            brightness = 1.0,
            contrast = 1.0,
            saturation = 1.0,
            adaptive_dim = 0.0,
            adaptive_boost = 0.0
        },
        light = {
            brightness = 1.0,
            contrast = 1.0,
            saturation = 1.0,
            adaptive_dim = 0.0,
            adaptive_boost = 0.0,
            tint_color = 0
        }
    })

    -- Topbar variant: a touch more frost so text/icons stay readable.
    hl.plugin.hyprglass.preset("qsglassbar", {
        inherits = "qsglass",
        blur_strength = 0.7,
        blur_iterations = 2,
        refraction_strength = 1.0,
        specular_strength = 0.3,
        fresnel_strength = 0.1,
        edge_thickness = 0.006
    })
end
