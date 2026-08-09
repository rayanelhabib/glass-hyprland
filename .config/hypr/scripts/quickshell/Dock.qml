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

            property bool mouseInZone: triggerMouseArea.containsMouse || dockPillHover.containsMouse

            onMouseInZoneChanged: {
                if (mouseInZone) {
                    hideTimer.stop();
                    dockWindow.isRevealed = true;
                } else {
                    hideTimer.restart();
                }
            }

            Timer {
                id: hideTimer
                interval: 450
                repeat: false
                onTriggered: {
                    if (!dockWindow.mouseInZone) {
                        dockWindow.isRevealed = false;
                    }
                }
            }

            property var runningApps: []

            // --- Window Tracking Process ---
            Process {
                id: clientTracker
                running: true
                command: ["bash", "-c", "hyprctl clients -j 2>/dev/null | jq -r '.[].class' 2>/dev/null"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            dockWindow.runningApps = txt.split("\n").map(s => s.toLowerCase());
                        } else {
                            dockWindow.runningApps = [];
                        }
                    }
                }
            }

            Timer {
                interval: 2500
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    clientTracker.running = false;
                    clientTracker.running = true;
                }
            }

            // --- Clean Pinned & Running Applications ---
            readonly property var dockItems: [
                { id: "files", name: "Files", icon: "org.gnome.Nautilus", fallback: "󰈔", cmd: "nautilus", match: "nautilus" },
                { id: "kitty", name: "Terminal", icon: "kitty", fallback: "󰞷", cmd: "kitty", match: "kitty" },
                { id: "brave", name: "Brave Browser", icon: "brave-desktop", fallback: "󰈹", cmd: "brave", match: "brave" },
                { id: "code", name: "Antigravity IDE", icon: "vscode", fallback: "󰨞", cmd: "antigravity-ide", match: "antigravity|code" },
                { id: "discord", name: "Discord", icon: "discord", fallback: "󰙯", cmd: "Discord", match: "discord" },
                { id: "spotify", name: "Spotify", icon: "spotify-launcher", fallback: "󰓇", cmd: "spotify", match: "spotify" }
            ]

            function isAppRunning(matchName) {
                if (!matchName) return false;
                let targets = matchName.toLowerCase().split("|");
                return dockWindow.runningApps.some(app => targets.some(t => app.includes(t)));
            }

            function launchItem(item) {
                if (item.action) {
                    let cmd = `~/.config/hypr/scripts/qs_manager.sh toggle ${item.action}`;
                    Quickshell.execDetached(["bash", "-c", cmd]);
                } else if (item.cmd) {
                    Quickshell.execDetached(["bash", "-c", item.cmd]);
                }
            }

            // =========================================================
            // --- 10PX BOTTOM TRIGGER STRIP (RESPONSIVE FULL-WIDTH SENSOR)
            // =========================================================
            Item {
                id: triggerStrip
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: dockWindow.s(10)

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

                        delegate: Item {
                            id: itemDelegate
                            required property var modelData
                            required property int index

                            width: dockWindow.s(40)
                            height: dockWindow.s(40)

                            // --- APP ICON ITEM ---
                            Item {
                                id: iconContent
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
                                    visible: itemMouseArea.containsMouse && modelData.name !== undefined
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
                                    source: modelData.icon ? "image://icon/" + modelData.icon : ""
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
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
                                    visible: modelData.match ? dockWindow.isAppRunning(modelData.match) : false
                                }

                                MouseArea {
                                    id: itemMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
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
