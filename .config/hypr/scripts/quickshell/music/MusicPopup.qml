import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../"

/**
 * MusicPopup.qml — Modern Liquid Glass Media Player
 *
 * Dark Frosted Liquid Glass Surface with 100% clipped bounds and subtle 10px artwork corners.
 */
Item {
    id: root

    // =========================================================================
    // 1. RESPONSIVE SCALER & THEME SYSTEM
    // =========================================================================
    Scaler { id: scaler; currentWidth: Screen.width }
    function s(val) { return scaler.s(val); }

    MatugenColors { id: _theme }
    readonly property color surface0: _theme.surface0

    // Cursor-tracking specular glare (fed by hover-only catcher below)
    property real cursorX: 0.5
    property real cursorY: 0.5
    property real sheenGlow: 0.0

    // =========================================================================
    // 2. PLAYER DATA STATE & DURATION FORMATTING
    // =========================================================================
    property var musicData: {
        "title": "Not Playing",
        "artist": "",
        "status": "Stopped",
        "percent": 0,
        "lengthStr": "00:00",
        "positionStr": "00:00",
        "timeStr": "--:-- / --:--",
        "source": "Offline",
        "playerName": "",
        "artUrl": ""
    }

    // Calculates remaining track duration formatted as "-MM:SS"
    readonly property string remainingTimeStr: {
        if (!root.musicData || !root.musicData.positionStr || !root.musicData.lengthStr ||
            root.musicData.status === "Stopped" ||
            (root.musicData.positionStr === "00:00" && root.musicData.lengthStr === "00:00")) return "-00:00";
        function toSec(t) { var p = t.split(":"); return (p.length === 2) ? parseInt(p[0], 10) * 60 + parseInt(p[1], 10) : 0; }
        var totalSec = toSec(root.musicData.lengthStr);
        var curSec = toSec(root.musicData.positionStr);
        if (totalSec <= 0 || totalSec < curSec) return "-00:00";
        var rem = Math.max(0, totalSec - curSec);
        var m = Math.floor(rem / 60); var sc = rem % 60;
        return "-" + (m < 10 ? "0" : "") + m + ":" + (sc < 10 ? "0" : "") + sc;
    }

    property bool userIsSeeking: false
    property bool userToggledPlay: false

    // =========================================================================
    // 3. LIVE HAPTIC EQUALIZER SPECTRUM
    // =========================================================================
    property real eqBar1: 0.15
    property real eqBar2: 0.25
    property real eqBar3: 0.35
    property real eqBar4: 0.20

    // High-frequency spectrum pulse generator (updates every 60ms during playback)
    Timer {
        interval: 60
        running: root.musicData.status === "Playing"
        repeat: true
        onTriggered: {
            root.eqBar1 = 0.10 + Math.random() * 0.90;
            root.eqBar2 = 0.10 + Math.random() * 0.90;
            root.eqBar3 = 0.10 + Math.random() * 0.90;
            root.eqBar4 = 0.10 + Math.random() * 0.90;
        }
    }

    // Reset equalizer bars when playback pauses or stops
    onMusicDataChanged: {
        if (musicData && musicData.status !== "Playing") {
            eqBar1 = 0.15; eqBar2 = 0.25; eqBar3 = 0.35; eqBar4 = 0.20;
        }
    }

    // =========================================================================
    // 4. ENTRANCE ANIMATIONS & SHELL EXECUTOR
    // =========================================================================
    property real introMain: 0
    property real introContent: 0

    ParallelAnimation {
        running: true
        NumberAnimation { target: root; property: "introMain"; from: 0; to: 1.0; duration: 550; easing.type: Easing.OutQuart }
        SequentialAnimation {
            PauseAnimation { duration: 70 }
            NumberAnimation { target: root; property: "introContent"; from: 0; to: 1.0; duration: 600; easing.type: Easing.OutCubic }
        }
    }

    function execCmd(cmdStr) {
        var safeCmd = cmdStr.replace(/`/g, "\\`");
        Qt.createQmlObject(`import Quickshell.Io; Process { command: ["bash","-c",\`${safeCmd}\`]; running:true; onExited:(c)=>destroy() }`, root);
    }

    // Data Polling & Debounce Timers
    Timer { id: seekDebounce; interval: 2500; onTriggered: root.userIsSeeking = false }
    Timer { id: playDebounce; interval: 1500; onTriggered: root.userToggledPlay = false }
    Timer {
        interval: 500; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { if (!musicProc.running) musicProc.running = true; }
    }

    Process {
        id: musicProc; running: true
        command: ["bash", "-c", "$HOME/.config/hypr/scripts/quickshell/music/music_info.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text) {
                    var textStr = this.text.trim();
                    if (textStr.length > 0) {
                        try {
                            var dataObj = JSON.parse(textStr);
                            if (root.userToggledPlay) dataObj.status = root.musicData.status;
                            root.musicData = dataObj;
                        } catch(e) {}
                    }
                }
            }
        }
    }

    // =========================================================================
    // 5. MAIN CONTAINER (DARK FROSTED LIQUID GLASS SURFACE)
    // =========================================================================
    Item {
        id: mainWrapper
        anchors.fill: parent
        scale: 0.95 + 0.05 * root.introMain
        opacity: root.introMain
        transform: Translate { y: root.s(6) * (1 - root.introMain) }

        // Elevation Drop Shadow
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: root.s(20) + 2
            color: "transparent"
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.85
                shadowBlur: 0.90
                shadowVerticalOffset: 6
            }
        }

        // Clipped Transparent Glass Container (Same pattern as SettingsPopup)
        Rectangle {
            id: mainCard
            anchors.fill: parent
            color: "transparent"
            radius: root.s(20)
            border.width: 0
            clip: true

            // Transparent Liquid Glass Surface
            LiquidGlass {
                id: glassSheen
                anchors.fill: parent
                tint: "#ffffff"
                cornerRadius: root.s(20)
                bodyOpacity: 0.04
                cursorSheen: true
                cursorX: root.cursorX
                cursorY: root.cursorY
                sheenGlow: root.sheenGlow
            }

            // Hairline Refractive Specular Border Outline
            Rectangle {
                anchors.fill: parent
                radius: root.s(20)
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.16)
            }

            // Hover-only glare catcher — sits below the content so it never
            // steals hover/clicks from artwork or controls, just tracks the cursor.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                onPositionChanged: (mouse) => {
                    root.cursorX = mouse.x / parent.width;
                    root.cursorY = mouse.y / parent.height;
                    root.sheenGlow = 1.0;
                }
                onExited: root.sheenGlow = 0.0
            }

        // =================================================================
        // 6. CONTENT LAYOUT (ARTWORK - METADATA & CONTROLS - LIVE EQ)
        // =================================================================
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.s(16)
            anchors.rightMargin: root.s(16)
            anchors.topMargin: root.s(14)
            anchors.bottomMargin: root.s(14)
            spacing: root.s(16)
            opacity: root.introContent

                // -------------------------------------------------------------
                // A. ALBUM ARTWORK POD (Premium Glass Design)
                // -------------------------------------------------------------
                Item {
                    Layout.preferredWidth: root.s(96)
                    Layout.preferredHeight: root.s(96)
                    Layout.alignment: Qt.AlignVCenter

                    // Soft Luminous Glow Aura Behind Artwork
                    Image {
                        id: artGlow
                        anchors.centerIn: parent
                        width: parent.width + root.s(24)
                        height: parent.height + root.s(24)
                        source: coverArt.source
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        visible: false
                        asynchronous: true
                    }
                    MultiEffect {
                        source: artGlow
                        anchors.fill: artGlow
                        blurEnabled: true
                        blurMax: 48
                        blur: 1.0
                        saturation: 0.4
                        opacity: coverArt.status === Image.Ready ? 0.45 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 500 } }
                    }

                    MouseArea {
                        id: artHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        scale: artHover.containsMouse ? 1.03 : 1.0
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                        // GPU Mask Item with Smooth 16px Antialiased Corners
                        Rectangle {
                            id: artMask
                            anchors.fill: parent
                            radius: root.s(16)
                            color: "#000000"
                            visible: false
                            antialiasing: true
                            layer.enabled: true
                            layer.smooth: true
                        }

                        // Clean Artwork Container
                        Rectangle {
                            id: artBox
                            anchors.fill: parent
                            radius: root.s(16)
                            color: "transparent"
                            antialiasing: true

                            Image {
                                id: coverArt
                                anchors.fill: parent
                                source: root.musicData.artUrl ? (root.musicData.artUrl.indexOf("file://") === 0 ? root.musicData.artUrl : "file://" + root.musicData.artUrl) : ""
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                mipmap: true
                                antialiasing: true
                                asynchronous: true
                                opacity: status === Image.Ready ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 300 } }
                                layer.enabled: true
                                layer.smooth: true
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: artMask
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: coverArt.status !== Image.Ready
                                text: "󰎆"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: root.s(32)
                                color: Qt.rgba(1.0, 1.0, 1.0, 0.35)
                            }
                        }

                        // Glass Reflection Highlight (Diagonal Sheen)
                        Rectangle {
                            id: reflectionMask
                            anchors.fill: parent
                            radius: root.s(16)
                            visible: false
                            antialiasing: true
                            layer.enabled: true
                            layer.smooth: true
                            color: "#000"
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: root.s(16)
                            antialiasing: true
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.18) }
                                GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.04) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                            opacity: coverArt.status === Image.Ready ? 1.0 : 0.0
                            layer.enabled: true
                            layer.smooth: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: reflectionMask
                            }
                        }

                        // Subtle Inner Shadow Vignette (Depth)
                        Rectangle {
                            id: innerShadowMask
                            anchors.fill: parent
                            radius: root.s(16)
                            visible: false
                            antialiasing: true
                            layer.enabled: true
                            layer.smooth: true
                            color: "#000"
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: root.s(16)
                            antialiasing: true
                            color: "transparent"
                            border.width: root.s(3)
                            border.color: Qt.rgba(0, 0, 0, 0.25)
                            opacity: coverArt.status === Image.Ready ? 1.0 : 0.0
                            layer.enabled: true
                            layer.smooth: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: innerShadowMask
                                blurEnabled: true
                                blurMax: 8
                                blur: 1.0
                            }
                        }
                    }
                }

                // -------------------------------------------------------------
                // B. CENTER COLUMN (Title, Artist, Progress Slider, Controls)
                // -------------------------------------------------------------
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Item { height: root.s(2); Layout.fillWidth: true }

                    // Track Title (Left-aligned, Bold White)
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignLeft
                        text: root.musicData.title
                        color: "#FFFFFF"
                        font.family: "Inter, JetBrains Mono, sans-serif"
                        font.pixelSize: root.s(18)
                        font.bold: true
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    // Artist Name (Left-aligned, Subtext Gray)
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignLeft
                        Layout.topMargin: root.s(3)
                        text: root.musicData.artist || ""
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.65)
                        font.family: "Inter, JetBrains Mono, sans-serif"
                        font.pixelSize: root.s(13)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        visible: text !== ""
                    }

                    Item { Layout.fillHeight: true }

                    // Progress Slider Row: 00:00 ────────●────── -00:00
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.s(8)

                        Text {
                            text: root.musicData.status === "Stopped" ? "00:00" : (root.musicData.positionStr || "00:00")
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.70)
                            font.family: "JetBrains Mono"
                            font.pixelSize: root.s(11)
                            font.bold: true
                        }

                        Slider {
                            id: progBar
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.s(14)
                            from: 0; to: 100

                            Connections {
                                target: root
                                function onMusicDataChanged() {
                                    if (!progBar.pressed && !root.userIsSeeking) {
                                        if (root.musicData && root.musicData.percent !== undefined) {
                                            var pct = Number(root.musicData.percent);
                                            if (!isNaN(pct)) progBar.value = pct;
                                        }
                                    }
                                }
                            }

                            Behavior on value {
                                enabled: !progBar.pressed && !root.userIsSeeking
                                NumberAnimation { duration: 400; easing.type: Easing.OutSine }
                            }

                            onPressedChanged: {
                                if (pressed) {
                                    root.userIsSeeking = true;
                                    seekDebounce.stop();
                                } else {
                                    var tempObj = Object.assign({}, root.musicData);
                                    tempObj.percent = value;
                                    root.musicData = tempObj;
                                    var playerStr = root.musicData.playerName || "";
                                    root.execCmd(`$HOME/.config/hypr/scripts/quickshell/music/player_control.sh seek ${value.toFixed(2)} ${root.musicData.length} "${playerStr}"`);
                                    seekDebounce.restart();
                                }
                            }

                            background: Item {
                                x: progBar.leftPadding
                                y: progBar.topPadding + (progBar.availableHeight - root.s(3.5)) / 2
                                width: progBar.availableWidth
                                height: root.s(3.5)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: root.s(1.75)
                                    color: Qt.rgba(1.0, 1.0, 1.0, 0.22)
                                }

                                Rectangle {
                                    width: Math.max(0, progBar.handle.x - progBar.leftPadding + (progBar.handle.width / 2))
                                    height: parent.height
                                    radius: root.s(1.75)
                                    color: "#FFFFFF"
                                }
                            }

                            handle: Rectangle {
                                x: progBar.leftPadding + progBar.visualPosition * (progBar.availableWidth - width)
                                y: progBar.topPadding + (progBar.availableHeight - height) / 2
                                implicitWidth: root.s(10); implicitHeight: root.s(10)
                                width: root.s(10); height: root.s(10)
                                radius: root.s(5)
                                color: "#FFFFFF"
                                scale: progBar.pressed ? 1.4 : (progBar.hovered ? 1.2 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                            }
                        }

                        Text {
                            text: root.remainingTimeStr
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.70)
                            font.family: "JetBrains Mono"
                            font.pixelSize: root.s(11)
                            font.bold: true
                        }
                    }

                    Item { height: root.s(2); Layout.fillWidth: true }

                    // Playback Controls Row (Previous, Play/Pause, Next)
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: root.s(24)

                        // Previous Track Button
                        MouseArea {
                            width: root.s(28); height: root.s(28)
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.execCmd("playerctl previous")
                            Text {
                                anchors.centerIn: parent
                                text: "\uf048"
                                color: parent.containsMouse ? "#FFFFFF" : Qt.rgba(1.0, 1.0, 1.0, 0.85)
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: root.s(18)
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            scale: pressed ? 0.84 : (containsMouse ? 1.10 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                        }

                        // Play/Pause Button
                        MouseArea {
                            width: root.s(32); height: root.s(32)
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                root.userToggledPlay = true;
                                playDebounce.restart();
                                var tempObj = Object.assign({}, root.musicData);
                                tempObj.status = (tempObj.status === "Playing" ? "Paused" : "Playing");
                                root.musicData = tempObj;
                                root.execCmd("playerctl play-pause");
                            }
                            Text {
                                anchors.centerIn: parent
                                text: root.musicData.status === "Playing" ? "\uf04c" : "\uf04b"
                                color: parent.containsMouse ? "#FFFFFF" : Qt.rgba(1.0, 1.0, 1.0, 0.95)
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: root.s(22)
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            scale: pressed ? 0.84 : (containsMouse ? 1.12 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                        }

                        // Next Track Button
                        MouseArea {
                            width: root.s(28); height: root.s(28)
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.execCmd("playerctl next")
                            Text {
                                anchors.centerIn: parent
                                text: "\uf051"
                                color: parent.containsMouse ? "#FFFFFF" : Qt.rgba(1.0, 1.0, 1.0, 0.85)
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: root.s(18)
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            scale: pressed ? 0.84 : (containsMouse ? 1.10 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                        }
                    }
                }

                // -------------------------------------------------------------
                // C. RIGHT SECTION (4 Live Haptic Equalizer Bars)
                // -------------------------------------------------------------
                Item {
                    Layout.preferredWidth: root.s(24)
                    Layout.fillHeight: true

                    Item {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.s(22)
                        height: root.s(36)

                        // Equalizer Bar 1
                        Rectangle {
                            x: 0
                            width: root.s(4)
                            height: root.s(4) + root.eqBar1 * root.s(32)
                            anchors.bottom: parent.bottom
                            radius: root.s(2)
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.90)
                            Behavior on height { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
                        }

                        // Equalizer Bar 2
                        Rectangle {
                            x: root.s(6)
                            width: root.s(4)
                            height: root.s(4) + root.eqBar2 * root.s(32)
                            anchors.bottom: parent.bottom
                            radius: root.s(2)
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.90)
                            Behavior on height { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
                        }

                        // Equalizer Bar 3
                        Rectangle {
                            x: root.s(12)
                            width: root.s(4)
                            height: root.s(4) + root.eqBar3 * root.s(32)
                            anchors.bottom: parent.bottom
                            radius: root.s(2)
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.90)
                            Behavior on height { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
                        }

                        // Equalizer Bar 4
                        Rectangle {
                            x: root.s(18)
                            width: root.s(4)
                            height: root.s(4) + root.eqBar4 * root.s(32)
                            anchors.bottom: parent.bottom
                            radius: root.s(2)
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.90)
                            Behavior on height { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
                        }
                    }
                }
            }
        }
    }
}
