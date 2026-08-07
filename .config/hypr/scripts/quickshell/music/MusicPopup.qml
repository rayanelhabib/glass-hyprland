import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../"

/**
 * MusicPopup.qml — Compact macOS Liquid Glass Media Card
 *
 * Layout (520x135):
 * ┌────────────────────────────────────────────────────────────────────────┐
 * │ ┌───────────┐  Song Title                                              │
 * │ │           │  Artist Name                                             │
 * │ │ ALBUM ART │  02:07 ────────────────●───────── -01:18    ▌▌▌▌ (EQ)   │
 * │ │ (110x110) │              ⏮       ▌▌       ⏭                      │
 * │ └───────────┘                                                          │
 * └────────────────────────────────────────────────────────────────────────┘
 */
Item {
    id: root

    // =========================================================================
    // 1. RESPONSIVE SCALER & THEME SYSTEM
    // =========================================================================
    Scaler { id: scaler; currentWidth: Screen.width }
    function s(val) { return scaler.s(val); }

    MatugenColors { id: _theme }
    readonly property color base: _theme.base
    readonly property color surface0: _theme.surface0

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
        "blur": "",
        "grad": "",
        "textColor": "#ffffff",
        "deviceIcon": "󰓃",
        "deviceName": "Speaker",
        "artUrl": ""
    }

    // Calculates remaining track duration formatted as "-MM:SS"
    readonly property string remainingTimeStr: {
        if (!root.musicData || !root.musicData.positionStr || !root.musicData.lengthStr ||
            (root.musicData.positionStr === "00:00" && root.musicData.lengthStr === "00:00")) return "-00:00";
        
        function toSeconds(timeStr) {
            var parts = timeStr.split(":");
            return (parts.length === 2) ? parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10) : 0;
        }
        
        var remainingSec = Math.max(0, toSeconds(root.musicData.lengthStr) - toSeconds(root.musicData.positionStr));
        var mins = Math.floor(remainingSec / 60);
        var secs = remainingSec % 60;
        return "-" + (mins < 10 ? "0" : "") + mins + ":" + (secs < 10 ? "0" : "") + secs;
    }

    property bool userIsSeeking: false
    property bool userToggledPlay: false

    // =========================================================================
    // 3. LIVE HAPTIC EQUALIZER STATE
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
    // 5. MAIN CARD & LIQUID GLASS CONTAINER
    // =========================================================================
    Item {
        id: mainWrapper
        anchors.fill: parent
        scale: 0.95 + 0.05 * root.introMain
        opacity: root.introMain
        transform: Translate { y: root.s(6) * (1 - root.introMain) }

        // Soft Elevation Drop Shadow
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: root.s(18) + 2
            color: "transparent"
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.75
                shadowBlur: 0.8
                shadowVerticalOffset: 6
            }
        }

        // Main Glass Body Surface (Liquid Glass)
        LiquidCard {
            id: mainCard
            anchors.fill: parent
            cornerRadius: root.s(18)
            artUrl: (root.musicData && root.musicData.blur) ? root.musicData.blur : ((root.musicData && root.musicData.artUrl) ? root.musicData.artUrl : "")
            tint: Qt.rgba(0.06, 0.065, 0.09, 1.0)
            tintOpacity: 0.25
            noiseOpacity: 0.15
            elevation: root.introMain

            // =================================================================
            // 6. CONTENT LAYOUT (ARTWORK - METADATA/CONTROLS - LIVE EQ)
            // =================================================================
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.s(12)
                anchors.rightMargin: root.s(12)
                anchors.topMargin: root.s(12)
                anchors.bottomMargin: root.s(12)
                spacing: root.s(14)
                opacity: root.introContent

                // -------------------------------------------------------------
                // A. ALBUM ARTWORK POD (macOS 24px Squircle with Hover Effect)
                // -------------------------------------------------------------
                Item {
                    Layout.preferredWidth: root.s(110)
                    Layout.preferredHeight: root.s(110)
                    Layout.alignment: Qt.AlignVCenter

                    MouseArea {
                        id: artHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        scale: artHover.containsMouse ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                        Rectangle {
                            id: artBox
                            anchors.fill: parent
                            radius: root.s(24)
                            color: root.surface0
                            clip: true

                            Image {
                                id: coverArt
                                anchors.fill: parent
                                source: root.musicData.artUrl ? "file://" + root.musicData.artUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                mipmap: true
                                opacity: status === Image.Ready ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 350 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: coverArt.status !== Image.Ready
                                text: "󰎆"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: root.s(32)
                                color: Qt.rgba(1.0, 1.0, 1.0, 0.25)
                            }
                        }

                        // Hover Border Highlight
                        Rectangle {
                            anchors.fill: parent
                            radius: root.s(24)
                            color: "transparent"
                            border.width: artHover.containsMouse ? 1.5 : 0
                            border.color: Qt.rgba(1.0, 1.0, 1.0, 0.35)
                            Behavior on border.width { NumberAnimation { duration: 200 } }
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

                    // Track Title
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.musicData.title
                        color: "#FFFFFF"
                        font.family: "JetBrains Mono"
                        font.pixelSize: root.s(15)
                        font.bold: true
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    // Artist Name
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.topMargin: root.s(2)
                        text: root.musicData.artist || ""
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.55)
                        font.family: "JetBrains Mono"
                        font.pixelSize: root.s(12)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        visible: text !== ""
                    }

                    Item { Layout.fillHeight: true }

                    // Progress Slider Row: 02:07 ────────●────── -01:18
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.s(8)

                        Text {
                            text: root.musicData.positionStr || "00:00"
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.65)
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
                                    color: Qt.rgba(1.0, 1.0, 1.0, 0.20)
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
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.65)
                            font.family: "JetBrains Mono"
                            font.pixelSize: root.s(11)
                            font.bold: true
                        }
                    }

                    Item { height: root.s(4); Layout.fillWidth: true }

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
                            scale: pressed ? 0.85 : (containsMouse ? 1.08 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        }

                        // Play / Pause Toggle Button
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
                            scale: pressed ? 0.85 : (containsMouse ? 1.1 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
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
                            scale: pressed ? 0.85 : (containsMouse ? 1.08 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
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
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.88)
                            Behavior on height { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
                        }

                        // Equalizer Bar 2
                        Rectangle {
                            x: root.s(6)
                            width: root.s(4)
                            height: root.s(4) + root.eqBar2 * root.s(32)
                            anchors.bottom: parent.bottom
                            radius: root.s(2)
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.88)
                            Behavior on height { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
                        }

                        // Equalizer Bar 3
                        Rectangle {
                            x: root.s(12)
                            width: root.s(4)
                            height: root.s(4) + root.eqBar3 * root.s(32)
                            anchors.bottom: parent.bottom
                            radius: root.s(2)
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.88)
                            Behavior on height { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
                        }

                        // Equalizer Bar 4
                        Rectangle {
                            x: root.s(18)
                            width: root.s(4)
                            height: root.s(4) + root.eqBar4 * root.s(32)
                            anchors.bottom: parent.bottom
                            radius: root.s(2)
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.88)
                            Behavior on height { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
                        }
                    }
                }
            }
        }
    }
}
