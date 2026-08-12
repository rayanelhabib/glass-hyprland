import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./"

Variants {
    id: dockVariants
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: dockWindow
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "qs-liquid-dock"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            anchors {
                bottom: true
                left: true
                right: true
            }

            implicitHeight: s(60)

            // Dynamic LayerShell Input Mask — Pass 100% of clicks to apps when hidden!
            mask: Region {
                item: dockWindow.isHidden ? triggerStrip : dockContainer
            }

            // --- Theme & Scaling ---
            MatugenColors { id: _theme }
            Scaler { id: scaler; currentWidth: dockWindow.screen.width }
            
            function s(val) { return scaler.s(val); }

            readonly property color base: _theme.base || "#1e1e2e"
            readonly property color text: _theme.text || "#cdd6f4"
            readonly property color primary: _theme.mauve || "#cba6f7"
            readonly property color surface: _theme.surface0 || "#313244"

            // --- Smart Autohide State with Hysteresis ---
            property bool isRevealed: false
            property bool isHidden: !isRevealed

            // Track how many icon MouseAreas are currently hovered.
            // This is critical because icon MouseAreas sit ON TOP of
            // dockPillHover and steal its containsMouse, causing the
            // dock to think the cursor left and hide mid-interaction.
            property int hoveredIconCount: 0

            // When the active workspace has zero windows, keep the dock always visible.
            property int activeWorkspaceWindows: -1
            property bool isDesktopEmpty: activeWorkspaceWindows === 0

            property bool mouseInZone: triggerMouseArea.containsMouse || dockPillHover.containsMouse || hoveredIconCount > 0

            onMouseInZoneChanged: {
                if (mouseInZone) {
                    hideTimer.stop();
                    dockWindow.isRevealed = true;
                } else if (!isDesktopEmpty) {
                    hideTimer.restart();
                }
            }

            onIsDesktopEmptyChanged: {
                if (isDesktopEmpty) {
                    hideTimer.stop();
                    dockWindow.isRevealed = true;
                } else if (!mouseInZone) {
                    hideTimer.restart();
                }
            }

            Timer {
                id: hideTimer
                interval: 800
                repeat: false
                onTriggered: {
                    if (!dockWindow.mouseInZone && !dockWindow.isDesktopEmpty) {
                        dockWindow.isRevealed = false;
                    }
                }
            }

            // --- Window Tracking Process & Socket Event Streamer ---
            property var runningApps: []
            onRunningAppsChanged: hoveredIconCount = 0

            Process {
                id: clientTracker
                running: true
                command: ["bash", "-c", "PIDFILE=/tmp/.qs_dock_tracker.pid; [ -f $PIDFILE ] && kill $(cat $PIDFILE) 2>/dev/null; echo $$ > $PIDFILE; trap 'rm -f $PIDFILE; kill 0' EXIT; f() { hyprctl clients -j 2>/dev/null | jq -c '[.[] | select(.mapped == true) | {address: .address, class: (.class // .initialClass // \"\"), title: (.title // \"\"), initialClass: (.initialClass // \"\"), workspace: (.workspace.name // \"\")}]' 2>/dev/null; echo \"WS:$(hyprctl activeworkspace -j 2>/dev/null | jq '.windows // 0')\"; }; f; socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock 2>/dev/null | while read -r line; do case \"$line\" in openwindow*|closewindow*|movewindow*|activewindow*|workspace*) f ;; esac; done"]
                stdout: SplitParser {
                    onRead: data => {
                        let txt = data.trim();
                        if (txt.startsWith("[")) {
                            try {
                                dockWindow.runningApps = JSON.parse(txt);
                            } catch(e) {}
                        } else if (txt.startsWith("WS:")) {
                            let n = parseInt(txt.substring(3));
                            if (!isNaN(n)) dockWindow.activeWorkspaceWindows = n;
                        }
                    }
                }
            }

            Timer {
                interval: 3000
                running: true
                repeat: true
                onTriggered: {
                    if (!clientTracker.running) {
                        clientTracker.running = true;
                    }
                }
            }

            // --- Pinned Apps from Desktop Files ---
            Caching { id: paths }

            // Pinned app IDs (desktop file basenames without .desktop)
            // Edit this list to pin/unpin apps from the dock
            readonly property var pinnedAppIds: [
                "org.gnome.Nautilus",
                "kitty",
                "brave-browser",
                "antigravity-ide",
                "discord",
                "spotify-launcher"
            ]

            property var loadedPinnedItems: []

            Process {
                id: pinnedLoader
                running: true
                command: ["bash", "-c", paths.home + "/.config/hypr/scripts/quickshell/dock_pins.sh " + dockWindow.pinnedAppIds.join(" ")]
                stdout: SplitParser {
                    onRead: data => {
                        let txt = data.trim();
                        if (txt.startsWith("[")) {
                            try {
                                dockWindow.loadedPinnedItems = JSON.parse(txt);
                            } catch(e) {}
                        }
                    }
                }
            }

            // Fallback hardcoded pins in case the loader hasn't fired yet
            readonly property var defaultPinnedItems: [
                { id: "files", name: "Files", icon: "org.gnome.Nautilus", fallback: "󰈔", cmd: "nautilus", match: "nautilus" },
                { id: "kitty", name: "Terminal", icon: "kitty", fallback: "󰞷", cmd: "kitty", match: "kitty" },
                { id: "brave", name: "Brave Browser", icon: "brave-desktop", fallback: "󰈹", cmd: "brave", match: "brave" },
                { id: "code", name: "Antigravity IDE", icon: "antigravity-ide", fallback: "󰨞", cmd: "antigravity-ide", match: "antigravity" },
                { id: "discord", name: "Discord", icon: "discord", fallback: "󰙯", cmd: "discord", match: "discord" },
                { id: "spotify", name: "Spotify", icon: "spotify", fallback: "󰓇", cmd: "spotify-launcher", match: "spotify" }
            ]

            readonly property var pinnedItems: loadedPinnedItems.length > 0 ? loadedPinnedItems : defaultPinnedItems

            function isMatch(appClass, matchPattern) {
                if (!appClass || !matchPattern) return false;
                let targets = matchPattern.toLowerCase().split("|");
                let cls = appClass.toLowerCase();
                return targets.some(t => cls.includes(t) || t.includes(cls));
            }

            function isPinnedRunning(pinnedItem) {
                if (!dockWindow.runningApps || dockWindow.runningApps.length === 0) return false;
                return dockWindow.runningApps.some(app => isMatch(app.class, pinnedItem.match) || isMatch(app.initialClass, pinnedItem.match));
            }

            function getRunningInfo(matchPattern) {
                if (!dockWindow.runningApps || dockWindow.runningApps.length === 0) return { address: "", workspace: "" };
                let found = dockWindow.runningApps.find(app => isMatch(app.class, matchPattern) || isMatch(app.initialClass, matchPattern));
                return found ? { address: found.address, workspace: found.workspace || "" } : { address: "", workspace: "" };
            }

            function resolveAppIcon(cls, initialClass, defaultIcon) {
                let c = (cls || initialClass || "").toLowerCase();

                if (c.includes("antigravity")) return "antigravity-ide";
                if (c.includes("spotify")) return "spotify";
                if (c.includes("discord")) return "discord";
                if (c.includes("brave")) return "brave-desktop";
                if (c.includes("code") || c.includes("vscode")) return "vscode";
                if (c.includes("nautilus") || c.includes("files")) return "org.gnome.Nautilus";
                if (c.includes("kitty")) return "kitty";
                if (c.includes("chrome")) return "google-chrome";
                if (c.includes("firefox")) return "firefox";
                if (c.includes("alacritty")) return "alacritty";
                if (c.includes("terminal")) return "utilities-terminal";
                if (c.includes("thunar")) return "thunar";
                if (c.includes("dolphin")) return "system-file-manager";
                if (c.includes("obsidian")) return "obsidian";
                if (c.includes("telegram")) return "telegram";
                if (c.includes("steam")) return "steam";
                if (c.includes("vlc")) return "vlc";
                if (c.includes("gimp")) return "gimp";

                if (defaultIcon && defaultIcon.length > 0) {
                    return defaultIcon.toLowerCase();
                }

                let lastPart = c.split(".").pop();
                return lastPart;
            }

            function getAppIconSource(iconName) {
                if (!iconName) return "";
                let lower = iconName.toLowerCase();
                if (lower === "antigravity-ide" || lower === "antigravity") {
                    return "file:///usr/share/pixmaps/antigravity-ide.png";
                }
                if (lower === "spotify" || lower === "spotify-launcher" || lower.includes("spotify")) {
                    return "file:///usr/share/icons/hicolor/512x512/apps/spotify-launcher.png";
                }
                if (lower === "org.gnome.nautilus" || lower === "nautilus" || lower === "files") {
                    return "image://icon/org.gnome.Nautilus";
                }
                if (lower.startsWith("file://") || lower.startsWith("http")) {
                    return iconName;
                }
                // Preserve original case — Qt icon theme lookups are case-sensitive
                return "image://icon/" + iconName;
            }

            function formatAppName(cls, title) {
                if (!cls || cls.length === 0) return title || "Application";
                let name = cls.split(".").pop();
                if (name.includes("-")) {
                    name = name.split("-")[0];
                }
                if (name.toLowerCase() === "org" || name.toLowerCase() === "com" || name.toLowerCase() === "io") {
                    let parts = cls.split(".");
                    if (parts.length >= 2) {
                        name = parts[parts.length - 2];
                    }
                }
                return name.charAt(0).toUpperCase() + name.slice(1);
            }

            readonly property var dockItems: {
                let list = [];

                // 1. Pinned Applications
                for (let i = 0; i < pinnedItems.length; i++) {
                    let p = pinnedItems[i];
                    let running = isPinnedRunning(p);
                    let info = running ? getRunningInfo(p.match) : { address: "", workspace: "" };
                    list.push({
                        id: p.id,
                        name: p.name,
                        icon: resolveAppIcon(p.match, p.match, p.icon),
                        fallback: p.fallback,
                        cmd: p.cmd,
                        match: p.match,
                        isPinned: true,
                        isRunning: running,
                        address: info.address,
                        workspace: info.workspace,
                        isSeparator: false
                    });
                }

                // 2. Unpinned Running Applications
                let unpinnedList = [];
                if (dockWindow.runningApps && dockWindow.runningApps.length > 0) {
                    for (let j = 0; j < dockWindow.runningApps.length; j++) {
                        let app = dockWindow.runningApps[j];
                        let cls = app.class || app.initialClass || "";
                        if (!cls) continue;

                        let isPinnedMatch = pinnedItems.some(p => isMatch(cls, p.match));
                        if (!isPinnedMatch) {
                            let alreadyAdded = unpinnedList.some(u => isMatch(cls, u.match));
                            if (!alreadyAdded) {
                                let displayName = formatAppName(cls, app.title);
                                let iconName = resolveAppIcon(cls, app.initialClass, cls.toLowerCase());
                                unpinnedList.push({
                                    id: "unpinned_" + cls.toLowerCase(),
                                    name: displayName,
                                    icon: iconName,
                                    fallback: "󰣆",
                                    cmd: "",
                                    match: cls.toLowerCase(),
                                    isPinned: false,
                                    isRunning: true,
                                    address: app.address,
                                    workspace: app.workspace || "",
                                    isSeparator: false
                                });
                            }
                        }
                    }
                }

                // 3. Separator + Unpinned Running Items
                if (unpinnedList.length > 0) {
                    list.push({
                        id: "dock_separator",
                        isSeparator: true
                    });
                    for (let k = 0; k < unpinnedList.length; k++) {
                        list.push(unpinnedList[k]);
                    }
                }

                return list;
            }

            function launchItem(item) {
                if (item.action) {
                    let cmd = `~/.config/hypr/scripts/qs_manager.sh toggle ${item.action}`;
                    Quickshell.execDetached(["bash", "-c", cmd]);
                } else if (item.cmd && item.cmd !== "") {
                    let cmd = item.cmd;
                    if (cmd.includes(" ") || cmd.includes("|") || cmd.includes(">") || cmd.includes("<") || cmd.includes("&") || cmd.includes(";") || cmd.includes("(") || cmd.includes("$")) {
                        Quickshell.execDetached(["bash", "-c", cmd]);
                    } else {
                        Quickshell.execDetached([cmd]);
                    }
                } else if (item.match) {
                    Quickshell.execDetached(["gio", "launch", item.match + ".desktop"]);
                }
            }

            // =========================================================
            // --- BOTTOM TRIGGER STRIP (RESPONSIVE FULL-WIDTH SENSOR)
            // =========================================================
            Item {
                id: triggerStrip
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: dockWindow.s(18)

                MouseArea {
                    id: triggerMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }

            // =========================================================
            // --- MAIN FLOATING MACOS LIQUID GLASS DOCK CONTAINER
            // =========================================================
            Item {
                id: dockContainer
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: dockWindow.isHidden ? -dockWindow.s(55) : dockWindow.s(6)

                Behavior on anchors.bottomMargin {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                width: pillRow.width + dockWindow.s(22)
                height: dockWindow.s(46)

                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                // --- Dark Translucent Glass Backdrop ---
                LiquidGlass {
                    anchors.fill: parent
                    cornerRadius: dockWindow.s(16)
                    bodyOpacity: 0.12
                    tint: Qt.rgba(0.08, 0.08, 0.1, 0.75)
                    cursorSheen: true
                    cursorX: dockPillHover.mouseX
                    cursorY: dockPillHover.mouseY
                    sheenGlow: dockPillHover.containsMouse ? 0.6 : 0.0
                }

                // --- Outer Glass Gloss Border ---
                Rectangle {
                    anchors.fill: parent
                    radius: dockWindow.s(16)
                    color: "transparent"
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.2)
                    border.width: 1
                }

                MouseArea {
                    id: dockPillHover
                    anchors.fill: parent
                    hoverEnabled: true
                }

                // --- Dock Items Row ---
                Row {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: dockWindow.s(6)

                    Repeater {
                        model: dockWindow.dockItems

                        delegate: Component {
                            id: itemDelegate

                            Item {
                                required property var modelData
                                required property int index

                                width: modelData.isSeparator ? dockWindow.s(14) : dockWindow.s(40)
                                height: dockWindow.s(40)

                                // --- GLASS SEPARATOR LINE ---
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: modelData.isSeparator === true
                                    width: 1
                                    height: dockWindow.s(22)
                                    radius: 1
                                    color: Qt.rgba(1, 1, 1, 0.25)
                                }

                                // --- APP ICON CONTENT ---
                                Item {
                                    id: iconContent
                                    visible: !modelData.isSeparator
                                    anchors.centerIn: parent
                                    width: dockWindow.s(36)
                                    height: dockWindow.s(36)

                                    property bool isHovered: itemMouseArea.containsMouse
                                    scale: isHovered ? 1.25 : 1.0

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 150
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    // =========================================================
                                    // --- MACOS SPEECH BUBBLE TOOLTIP WITH POINTER TAIL ---
                                    // =========================================================
                                    Item {
                                        id: macosTooltip
                                        visible: itemMouseArea.containsMouse && modelData.name !== undefined && !modelData.isSeparator
                                        anchors.bottom: iconContent.top
                                        anchors.bottomMargin: dockWindow.s(6)
                                        anchors.horizontalCenter: iconContent.horizontalCenter
                                        width: tooltipBg.width
                                        height: tooltipBg.height + dockWindow.s(5)
                                        z: 100

                                        Rectangle {
                                            id: tooltipBg
                                            anchors.top: parent.top
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: tooltipLabel.implicitWidth + dockWindow.s(16)
                                            height: dockWindow.s(22)
                                            radius: dockWindow.s(6)
                                            color: Qt.rgba(0.12, 0.12, 0.14, 0.95)
                                            border.color: Qt.rgba(1, 1, 1, 0.2)
                                            border.width: 1

                                            Text {
                                                id: tooltipLabel
                                                anchors.centerIn: parent
                                                text: modelData.name || ""
                                                font.pixelSize: dockWindow.s(11)
                                                font.weight: Font.DemiBold
                                                font.family: "JetBrains Mono"
                                                color: "#ffffff"
                                            }
                                        }

                                        // Downward Triangle Pointer Tail
                                        Canvas {
                                            id: pointerTail
                                            anchors.top: tooltipBg.bottom
                                            anchors.topMargin: -1
                                            anchors.horizontalCenter: tooltipBg.horizontalCenter
                                            width: dockWindow.s(10)
                                            height: dockWindow.s(6)

                                            onPaint: {
                                                var ctx = getContext("2d");
                                                ctx.clearRect(0, 0, width, height);
                                                ctx.fillStyle = "rgba(30, 30, 35, 0.95)";
                                                ctx.beginPath();
                                                ctx.moveTo(0, 0);
                                                ctx.lineTo(width / 2, height);
                                                ctx.lineTo(width, 0);
                                                ctx.closePath();
                                                ctx.fill();
                                            }
                                        }
                                    }

                                    // =========================================================
                                    // --- REAL SYSTEM ICON IMAGE ---
                                    // =========================================================
                                    Image {
                                        id: appImg
                                        anchors.centerIn: parent
                                        width: dockWindow.s(32)
                                        height: dockWindow.s(32)
                                        source: (modelData.icon && !modelData.isSeparator) ? dockWindow.getAppIconSource(modelData.icon) : ""
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        antialiasing: true
                                        visible: status === Image.Ready
                                    }

                                    // Fallback Pixmap Image if System Icon Theme Fails
                                    Image {
                                        id: appImgFallback
                                        anchors.centerIn: parent
                                        width: dockWindow.s(32)
                                        height: dockWindow.s(32)
                                        source: (!modelData.isSeparator && appImg.status !== Image.Ready && modelData.icon) ?
                                                (modelData.icon.toLowerCase().includes("spotify") ? "file:///usr/share/pixmaps/spotify-launcher.png" :
                                                (modelData.icon.toLowerCase().includes("antigravity") ? "file:///usr/share/pixmaps/antigravity-ide.png" : "")) : ""
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        antialiasing: true
                                        visible: appImg.status !== Image.Ready && status === Image.Ready
                                    }

                                    // Fallback Badge / Icon if System Icon Fails Completely
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: dockWindow.s(30)
                                        height: dockWindow.s(30)
                                        radius: dockWindow.s(8)
                                        color: Qt.rgba(1, 1, 1, 0.15)
                                        border.color: Qt.rgba(1, 1, 1, 0.25)
                                        border.width: 1
                                        visible: !modelData.isSeparator && appImg.status !== Image.Ready && appImgFallback.status !== Image.Ready

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.fallback ? modelData.fallback : ((modelData.name && modelData.name.length > 0) ? modelData.name.charAt(0).toUpperCase() : "?")
                                            font.pixelSize: dockWindow.s(14)
                                            font.weight: Font.Bold
                                            font.family: modelData.fallback ? "Material Design Icons" : "JetBrains Mono"
                                            color: dockWindow.text
                                        }
                                    }

                                    // =========================================================
                                    // --- ACTIVE RUNNING APP WHITE DOT INDICATOR ---
                                    // =========================================================
                                    Rectangle {
                                        id: runningDot
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: -dockWindow.s(2)
                                        width: dockWindow.s(4)
                                        height: dockWindow.s(4)
                                        radius: 2
                                        color: "#ffffff"
                                        opacity: 0.9
                                        visible: !modelData.isSeparator && modelData.isRunning === true
                                    }

                                    MouseArea {
                                        id: itemMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        // Keep dock alive while hovering any icon
                                        property bool wasHovered: false
                                        onContainsMouseChanged: {
                                            if (containsMouse) {
                                                wasHovered = true;
                                                dockWindow.hoveredIconCount++;
                                            } else {
                                                wasHovered = false;
                                                dockWindow.hoveredIconCount = Math.max(0, dockWindow.hoveredIconCount - 1);
                                            }
                                        }
                                        Component.onDestruction: {
                                            if (wasHovered) {
                                                dockWindow.hoveredIconCount = Math.max(0, dockWindow.hoveredIconCount - 1);
                                            }
                                        }

                                        onClicked: {
                                            if (modelData.isRunning && modelData.match) {
                                                let focusCmd = "";
                                                if (modelData.workspace && modelData.workspace !== "") {
                                                    focusCmd = `hyprctl --batch "dispatch hl.dsp.focus({ workspace = '${modelData.workspace}' }); dispatch hl.dsp.focus({ window = 'address:${modelData.address}' })" 2>/dev/null || hyprctl --batch "dispatch hl.dsp.focus({ window = 'class:^(${modelData.match})$' })"`;
                                                } else if (modelData.address && modelData.address !== "") {
                                                    focusCmd = `hyprctl --batch "dispatch hl.dsp.focus({ window = 'address:${modelData.address}' })" 2>/dev/null || hyprctl --batch "dispatch hl.dsp.focus({ window = 'class:^(${modelData.match})$' })"`;
                                                } else {
                                                    focusCmd = `hyprctl --batch "dispatch hl.dsp.focus({ window = 'class:^(${modelData.match})$' })"`;
                                                }
                                                Quickshell.execDetached(["bash", "-c", focusCmd]);
                                            } else {
                                                dockWindow.launchItem(modelData);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

