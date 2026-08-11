#!/usr/bin/env python3
"""Generate Hyprland's dynamic Lua config modules from settings.json.

Mirrors the .conf pipeline in settings_watcher.sh so that changes made in the
Quickshell settings UI (keyboard layout, wallpaper dir, monitors, keybinds,
startup apps, guide toggle) keep applying under Hyprland's Lua config format.
"""
import json
import os
import subprocess
import sys

BASE = os.path.join(os.path.expanduser("~"), ".config", "hypr")
CONF_DIR = os.path.join(BASE, "config")
TMPL_DIR = os.path.join(BASE, "templates")
SETTINGS_FILE = os.path.join(BASE, "settings.json")

GUIDE_CMD = "bash -c 'sleep 1 && ~/.config/hypr/scripts/qs_manager.sh toggle guide'"


def read(path):
    with open(path, "r") as fh:
        return fh.read()


def write(path, content):
    with open(path, "w") as fh:
        fh.write(content)


def xdg_dir(name, fallback):
    try:
        out = subprocess.run(
            ["xdg-user-dir", name], capture_output=True, text=True, check=False
        ).stdout.strip()
        return out or fallback
    except OSError:
        return fallback


def lua_str(value):
    value = str(value)
    if '"' in value or "\\" in value or "\n" in value or "]" in value:
        if "]]" in value:
            escaped = value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
            return '"' + escaped + '"'
        return "[[" + value + "]]"
    return '"' + value + '"'


def gen_env(settings):
    home = os.path.expanduser("~")
    pics = xdg_dir("PICTURES", os.path.join(home, "Pictures"))
    vids = xdg_dir("VIDEOS", os.path.join(home, "Videos"))
    wp = settings.get("wallpaperDir", "")

    content = read(os.path.join(TMPL_DIR, "env.lua.template"))
    content = content.replace("{{XDG_PICTURES_DIR}}", pics)
    content = content.replace("{{XDG_VIDEOS_DIR}}", vids)
    content = content.replace("{{WALLPAPER_DIR}}", wp)
    content = content.replace("{{SCRIPT_DIR}}", os.path.join(BASE, "scripts"))

    hw_lines = []
    for hw in settings.get("hardwareEnvs", []) or []:
        line = str(hw).strip()
        if line.lower().startswith("env "):
            line = line.split("=", 1)[1].strip()
        key, _, value = line.partition(",")
        if key.strip():
            hw_lines.append('hl.env("%s", "%s")' % (key.strip(), value.strip()))
    content = content.replace("{{HARDWARE_ENV}}", "\n".join(hw_lines))

    write(os.path.join(CONF_DIR, "env.lua"), content)


def gen_settings(settings):
    lang = settings.get("language", "us")
    kbopt = settings.get("kbOptions", "grp:alt_shift_toggle")

    content = read(os.path.join(TMPL_DIR, "settings.lua.template"))
    content = content.replace("{{KB_LAYOUT}}", lang)
    content = content.replace("{{KB_OPTIONS}}", kbopt)

    write(os.path.join(CONF_DIR, "settings.lua"), content)


def gen_autostart(settings):
    content = read(os.path.join(TMPL_DIR, "autostart.lua.template"))

    lines = []
    for entry in settings.get("startup", []) or []:
        cmd = entry.get("command", "") if entry.get("command") is not None else ""
        if cmd:
            lines.append("    hl.exec_cmd(%s)" % lua_str(cmd))

    if settings.get("openGuideAtStartup", True):
        lines.append("    hl.exec_cmd(%s)" % lua_str(GUIDE_CMD))
    lines.append("end)")

    write(os.path.join(CONF_DIR, "autostart.lua"), content + "\n" + "\n".join(lines) + "\n")


MOD_MAP = {
    "$mainMod": "mainMod",
    "SHIFT_L": "SHIFT",
    "SHIFT_R": "SHIFT",
    "CTRL_L": "CTRL",
    "CTRL_R": "CTRL",
    "ALT_L": "ALT",
    "ALT_R": "ALT",
    "SUPER_L": "SUPER",
    "SUPER_R": "SUPER",
}

TYPE_OPTS = {
    "bind": None,
    "binde": "{ repeating = true }",
    "bindl": "{ locked = true }",
    "bindel": "{ locked = true, repeating = true }",
    "bindm": "{ mouse = true }",
    "bindmr": "{ mouse = true, release = true }",
    "bindr": "{ release = true }",
    "bindn": "{ non_consuming = true }",
}

DIRECTION_MAP = {
    "l": "left",
    "r": "right",
    "u": "up",
    "d": "down",
}


def bind_keys(mods, key):
    if not mods:
        return lua_str(key)
    parts = []
    uses_main = False
    for mod in str(mods).split():
        if mod == "$mainMod":
            uses_main = True
        else:
            parts.append(MOD_MAP.get(mod, mod))
    if uses_main:
        suffix = " + ".join(parts + [str(key)])
        return 'mainMod .. " + ' + suffix + '"'
    return lua_str(" + ".join(parts + [str(key)]))


def dispatch(kb):
    cmd = kb.get("command")
    cmd = str(cmd) if cmd is not None else ""
    name = str(kb.get("dispatcher", "exec"))
    stripped = cmd.strip()
    if stripped.lower().startswith("hyprctl dispatch"):
        parts = stripped[len("hyprctl dispatch") :].strip().split(None, 1)
        if parts:
            name = parts[0]
            cmd = parts[1] if len(parts) > 1 else ""
    if name in ("dispatch", "dispatchraw"):
        # Legacy-style "dispatch <dispatcher> <args>" passthrough from the settings UI.
        parts = stripped.split(None, 1)
        if parts:
            return dispatch({"dispatcher": parts[0], "command": parts[1] if len(parts) > 1 else ""})
    if name in ("exec", "exec-once"):
        return "hl.dsp.exec_cmd(" + lua_str(cmd) + ")"
    if name == "killactive":
        return "hl.dsp.window.close()"
    if name == "togglefloating":
        return 'hl.dsp.window.float({ action = "toggle" })'
    if name == "resizeactive":
        xy = cmd.split()
        if len(xy) == 2:
            return "hl.dsp.window.resize({ x = %s, y = %s, relative = true })" % (xy[0], xy[1])
        return "hl.dsp.window.resize()"
    if name in ("movewindow", "movefocus"):
        fn = "window.move" if name == "movewindow" else "focus"
        direction = DIRECTION_MAP.get(cmd, cmd)
        if name == "movewindow":
            # Legacy `movewindow <n>` / `movewindow <name>` moves to a workspace.
            if cmd.isdigit() or (direction and direction not in DIRECTION_MAP.values()):
                val = cmd if cmd.isdigit() else lua_str(cmd)
                return "hl.dsp.window.move({ workspace = %s })" % val
            if not direction:
                return "hl.dsp.window.drag()"
        return "hl.dsp.%s({ direction = %s })" % (fn, lua_str(direction))
    if name == "fullscreen":
        args = str(cmd).split()
        if not args or args[0] == "2":
            return 'hl.dsp.window.fullscreen({ action = "toggle" })'
        if args[0] == "1":
            return 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })'
        return 'hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })'
    if name in ("workspace", "movetoworkspace"):
        arg = str(cmd).strip()
        val = arg if arg.isdigit() else lua_str(arg)
        if name == "workspace":
            return "hl.dsp.focus({ workspace = %s })" % val
        return "hl.dsp.window.move({ workspace = %s })" % val
    # Fail loudly in the generated file instead of silently doing nothing.
    return "hl.dsp.no_op() -- UNMAPPED DISPATCHER %r (add a mapping in gen_lua_config.py)" % name


def gen_keybinds(settings):
    content = read(os.path.join(TMPL_DIR, "keybinds.lua.template"))

    lines = []
    for kb in settings.get("keybinds", []) or []:
        keys = bind_keys(kb.get("mods", ""), kb.get("key", ""))
        opts = TYPE_OPTS.get(str(kb.get("type", "bind")), None)
        line = "hl.bind(%s, %s" % (keys, dispatch(kb))
        if opts:
            line += ", " + opts
        line += ")"
        lines.append(line)

    write(os.path.join(CONF_DIR, "keybindings.lua"), content + "\n" + "\n".join(lines) + "\n")


def gen_monitors(settings):
    content = read(os.path.join(TMPL_DIR, "monitors.lua.template"))

    monitors = settings.get("monitors", []) or []
    blocks = []
    if monitors:
        for mon in monitors:
            fields = [
                "    output   = %s" % lua_str(mon.get("name", "")),
                "    mode     = %s" % lua_str(
                    "%sx%s@%s" % (mon.get("resW", ""), mon.get("resH", ""), mon.get("rate", ""))
                ),
                "    position = %s" % lua_str("%sx%s" % (mon.get("x", 0), mon.get("y", 0))),
                "    scale    = %s" % (mon.get("scale", 1) if mon.get("scale") is not None else 1),
            ]
            transform = mon.get("transform", 0)
            if transform:
                fields.append("    transform = %s" % transform)
            blocks.append("hl.monitor({\n%s\n})" % ",\n".join(fields))
    else:
        blocks.append(
            'hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })'
        )

    write(os.path.join(CONF_DIR, "monitors.lua"), content + "\n\n" + "\n\n".join(blocks) + "\n")


def main():
    if os.path.exists(SETTINGS_FILE):
        with open(SETTINGS_FILE, "r") as fh:
            settings = json.load(fh)
    else:
        settings = {}

    gen_env(settings)
    gen_settings(settings)
    gen_autostart(settings)
    gen_keybinds(settings)
    gen_monitors(settings)
    print("Regenerated Lua config modules.")


if __name__ == "__main__":
    main()
