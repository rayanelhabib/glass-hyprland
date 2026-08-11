-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--  ◈ WINDOW & LAYER RULES
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

hl.layer_rule({ name = "lr1", match = { namespace = "^(volume_osd)$" }, no_anim = true })
hl.layer_rule({ name = "lr2", match = { namespace = "^(brightness_osd)$" }, no_anim = true })
hl.layer_rule({ name = "lr3", match = { namespace = "hyprpicker" }, no_anim = true })
hl.layer_rule({ name = "lr4", match = { namespace = "qsdock" }, no_anim = true })
hl.layer_rule({ name = "lr5", match = { namespace = "ext-session-lock" }, blur = true, ignore_alpha = 0.2 })

-- ───────── Quickshell Liquid-Glass Surfaces ─────────
-- hyprglass already paints glass on all qs namespaces (see plugins.conf);
-- these rules disable the compositor's layer fade so the QML-driven morph
-- and cursor glare animate without fighting a second, offset fade.
hl.layer_rule({ name = "lr6", match = { namespace = "^(qs-master)$" }, no_anim = true })
hl.layer_rule({ name = "lr7", match = { namespace = "^(qs-topbar)$" }, no_anim = true })
hl.layer_rule({ name = "lr8", match = { namespace = "^(qs-popups)$" }, no_anim = true })
hl.layer_rule({ name = "lr9", match = { namespace = "^(qs-floating-overlay)$" }, no_anim = true })

-- ─────────────────────────────
-- Window rules
-- ─────────────────────────────

-- ───────── App Launcher ─────────
hl.window_rule({
    name = "app_launcher",
    match = { title = "^(app-launcher)$" },
    float = true,
    center = true,
    size = "1200 600",
    animation = "slide"
})

-- ───────── MASTER QUICKSHELL CONTAINER ─────────
hl.window_rule({
    name = "master_rule",
    match = { title = "^(qs-master)$" },
    float = true,
    no_shadow = true,
    no_initial_focus = true
})
