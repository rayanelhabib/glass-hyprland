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

            implicitHeight: s(120)

            // --- Dynamic Mask Area covering the dock container and active trigger zone ---
            Item {
                id: dockMaskArea
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: Math.max(dockContainer.width + dockWindow.s(30), dockWindow.s(300))
                height: dockWindow.isHidden ? dockWindow.s(24) : (dockContainer.height + dockWindow.s(24))
            }

            // Dynamic LayerShell Input Mask — Pass 100% of clicks to apps instantly!
            mask: Region {
                item: contextMenu.visible ? contextMenuOverlay : dockMaskArea
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
            property bool isRevealed: true
            property bool isHidden: !isRevealed

            property int hoveredIconCount: 0
            property int activeWorkspaceWindows: 0
            property bool isDesktopEmpty: activeWorkspaceWindows === 0

            property bool mouseInZone: triggerMouseArea.containsMouse || dockPillHover.containsMouse || hoveredIconCount > 0 || contextMenu.visible

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
                    if (!dockWindow.mouseInZone && !dockWindow.isDesktopEmpty && !contextMenu.visible) {
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
                interval: 2000
                running: true
                repeat: true
                onTriggered: {
                    if (!clientTracker.running) {
                        clientTracker.running = true;
                    }
                }
            }

            // --- Pinned Apps Loader & Watcher ---
            Caching { id: paths }

            property var loadedPinnedItems: []

            Process {
                id: pinnedLoader
                running: true
                command: ["bash", "-c", paths.home + "/.config/hypr/scripts/quickshell/dock_pins.sh"]
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

            // Periodically refresh pins if settings.json changes
            Timer {
                interval: 1500
                running: true
                repeat: true
                onTriggered: {
                    if (pinnedLoader.running) {
                        pinnedLoader.running = false;
                    }
                    pinnedLoader.running = true;
                }
            }

            // Fallback default pins
            readonly property var defaultPinnedItems: [
                { id: "org.gnome.Nautilus", name: "Files", icon: "org.gnome.Nautilus", fallback: "󰈔", cmd: "nautilus", match: "nautilus" },
                { id: "kitty", name: "Terminal", icon: "kitty", fallback: "󰞷", cmd: "kitty", match: "kitty" },
                { id: "brave-browser", name: "Brave Browser", icon: "brave-desktop", fallback: "󰈹", cmd: "brave", match: "brave" },
                { id: "antigravity-ide", name: "Antigravity IDE", icon: "antigravity-ide", fallback: "󰨞", cmd: "antigravity-ide", match: "antigravity" },
                { id: "discord", name: "Discord", icon: "discord", fallback: "󰙯", cmd: "discord", match: "discord" },
                { id: "spotify-launcher", name: "Spotify", icon: "spotify", fallback: "󰓇", cmd: "spotify-launcher", match: "spotify" }
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
                return dockWindow.runningApps.some(app => isMatch(app.class, pinnedItem.match) || isMatch(app.initialClass, pinnedItem.match) || isMatch(app.class, pinnedItem.id) || isMatch(app.initialClass, pinnedItem.id));
            }

            function getRunningInfo(matchPattern, appId) {
                if (!dockWindow.runningApps || dockWindow.runningApps.length === 0) return { address: "", workspace: "" };
                let found = dockWindow.runningApps.find(app => isMatch(app.class, matchPattern) || isMatch(app.initialClass, matchPattern) || isMatch(app.class, appId) || isMatch(app.initialClass, appId));
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
                    let info = running ? getRunningInfo(p.match, p.id) : { address: "", workspace: "" };
                    list.push({
                        id: p.id,
                        name: p.name,
                        icon: resolveAppIcon(p.match, p.match, p.icon),
                        fallback: p.fallback,
                        cmd: p.cmd,
                        match: p.match || p.id,
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

                        let isPinnedMatch = pinnedItems.some(p => isMatch(cls, p.match) || isMatch(cls, p.id));
                        if (!isPinnedMatch) {
                            let alreadyAdded = unpinnedList.some(u => isMatch(cls, u.match));
                            if (!alreadyAdded) {
                                let displayName = formatAppName(cls, app.title);
                                let iconName = resolveAppIcon(cls, app.initialClass, cls.toLowerCase());
                                unpinnedList.push({
                                    id: cls,
                                    name: displayName,
                                    icon: iconName,
                                    fallback: "󰣆",
                                    cmd: cls.toLowerCase(),
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

            // --- Fast Ultra-Optimized Focus & Launch Functions ---
            function focusApp(item) {
                if (item.address && item.address !== "") {
                    // Direct address focus execution (instant < 2ms)
                    Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + item.address]);
                } else if (item.match && item.match !== "") {
                    Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "class:^(" + item.match + ")$"]);
                } else {
                    launchItem(item);
                }
            }

            function launchItem(item) {
                if (item.cmd && item.cmd !== "") {
                    let cmd = item.cmd;
                    if (cmd.includes(" ") || cmd.includes("|") || cmd.includes(">") || cmd.includes("&") || cmd.includes(";")) {
                        Quickshell.execDetached(["bash", "-c", cmd]);
                    } else {
                        Quickshell.execDetached([cmd]);
                    }
                } else if (item.id) {
                    Quickshell.execDetached(["gio", "launch", item.id + ".desktop"]);
                }
            }

            function togglePinItem(item) {
                let action = item.isPinned ? "unpin" : "pin";
                let appId = item.id;
                Quickshell.execDetached(["bash", "-c", paths.home + "/.config/hypr/scripts/toggle_dock_pin.sh " + appId + " " + action]);
                // Trigger immediate pin reload
                pinnedLoader.running = false;
                pinnedLoader.running = true;
            }

            // =========================================================
            // --- CONTEXT MENU OVERLAY (CLICK OUTSIDE TO CLOSE)
            // =========================================================
            Item {
                id: contextMenuOverlay
                anchors.fill: parent
                visible: contextMenu.visible

                MouseArea {
                    anchors.fill: parent
                    onClicked: contextMenu.close()
                }
            }

            // =========================================================
            // --- BOTTOM TRIGGER STRIP (RESPONSIVE SENSOR)
            // =========================================================
            Item {
                id: triggerStrip
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: dockWindow.s(24)

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
                        duration: 180
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
                                id: delegateRoot
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
                                    property bool isPressed: itemMouseArea.pressed

                                    // Smooth macOS spring magnification & tactile press scale
                                    scale: isPressed ? 0.92 : (isHovered ? 1.28 : 1.0)

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 120
                                            easing.type: Easing.OutQuint
                                        }
                                    }

                                    // =========================================================
                                    // --- MACOS SPEECH BUBBLE TOOLTIP ---
                                    // =========================================================
                                    Item {
                                        id: macosTooltip
                                        visible: itemMouseArea.containsMouse && !contextMenu.visible && modelData.name !== undefined && !modelData.isSeparator
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

                                        // Downward Pointer Tail
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

                                    // Fallback Pixmap Image
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

                                    // Fallback Text Badge
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
                                    // --- ACTIVE RUNNING APP DOT INDICATOR ---
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
                                        opacity: 0.95
                                        visible: !modelData.isSeparator && modelData.isRunning === true
                                    }

                                    // =========================================================
                                    // --- FAST MOUSE & RIGHT CLICK CONTEXT MENU HANDLER ---
                                    // =========================================================
                                    MouseArea {
                                        id: itemMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor

                                        property bool wasHovered: false
                                        onContainsMouseChanged: {
                                            if (containsMouse) {
                                                wasHovered = true;
                                                dockWindow.hoveredIconCount++;
                                                dockWindow.isRevealed = true;
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

                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton) {
                                                contextMenu.openFor(modelData, mapToItem(dockWindow.contentItem, mouse.x, mouse.y));
                                            } else if (mouse.button === Qt.LeftButton) {
                                                contextMenu.close();
                                                if (modelData.isRunning) {
                                                    dockWindow.focusApp(modelData);
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

            // =========================================================
            // --- CLEAN SINGLE-BUTTON RIGHT-CLICK CONTEXT MENU (PIN / UNPIN)
            // =========================================================
            Item {
                id: contextMenu
                visible: opacity > 0
                opacity: 0
                scale: opacity > 0 ? 1.0 : 0.88
                z: 1000

                property var targetItem: null

                Behavior on opacity {
                    NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: 130; easing.type: Easing.OutBack }
                }

                function openFor(itemData, pos) {
                    if (itemData.isSeparator) return;
                    targetItem = itemData;

                    let menuW = dockWindow.s(160);
                    let menuH = dockWindow.s(36);

                    let posX = pos.x - menuW / 2;
                    let posY = dockContainer.y - menuH - dockWindow.s(8);

                    // Clamp to screen edges
                    posX = Math.max(dockWindow.s(10), Math.min(posX, dockWindow.width - menuW - dockWindow.s(10)));

                    contextMenu.x = posX;
                    contextMenu.y = posY;
                    contextMenu.opacity = 1.0;
                }

                function close() {
                    contextMenu.opacity = 0;
                    targetItem = null;
                }

                width: dockWindow.s(160)
                height: dockWindow.s(36)

                // Translucent Glass Menu Container
                LiquidGlass {
                    anchors.fill: parent
                    cornerRadius: dockWindow.s(10)
                    bodyOpacity: 0.25
                    tint: Qt.rgba(0.08, 0.08, 0.12, 0.92)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: dockWindow.s(10)
                    color: "transparent"
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.22)
                    border.width: 1
                }

                // Single Pin / Unpin Action Button
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: dockWindow.s(3)
                    radius: dockWindow.s(8)
                    color: pinBtnHover.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: dockWindow.s(10)
                        anchors.rightMargin: dockWindow.s(10)
                        spacing: dockWindow.s(8)

                        Text {
                            text: contextMenu.targetItem && contextMenu.targetItem.isPinned ? "📌" : "📍"
                            font.pixelSize: dockWindow.s(13)
                        }
                        Text {
                            text: contextMenu.targetItem && contextMenu.targetItem.isPinned ? "Unpin from Dock" : "Pin to Dock"
                            font.pixelSize: dockWindow.s(12)
                            font.weight: Font.DemiBold
                            font.family: "JetBrains Mono"
                            color: "#ffffff"
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: pinBtnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (contextMenu.targetItem) {
                                dockWindow.togglePinItem(contextMenu.targetItem);
                            }
                            contextMenu.close();
                        }
                    }
                }
            }
        }
    }
}
