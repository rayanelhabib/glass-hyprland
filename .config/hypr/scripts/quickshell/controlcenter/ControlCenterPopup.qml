import "../"
import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io

/**
 * ControlCenterPopup.qml — a calm, minimal control panel.
 *
 * Simple glass card. Clean toggle rows, two sliders. No glare, no orbs,
 * no music, no telemetry. Just the essentials, spacious and quiet.
 */
Item {
    id: root

    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay0: _theme.overlay0
    readonly property color overlay1: _theme.overlay1
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color mauve: _theme.mauve
    readonly property color pink: _theme.pink
    readonly property color red: _theme.red
    readonly property color maroon: _theme.maroon
    readonly property color peach: _theme.peach
    readonly property color yellow: _theme.yellow
    readonly property color green: _theme.green
    readonly property color teal: _theme.teal
    readonly property color sapphire: _theme.sapphire
    readonly property color blue: _theme.blue

    property var masterWindow: null

    // ------------------------------------------------------------------
    // SYSTEM STATE
    // ------------------------------------------------------------------
    property string wifiStatus: "disabled"
    property string wifiSsid: ""
    property string ethStatus: "Disconnected"
    property string btStatus: "off"
    property string btIcon: "󰂲"
    property string btDevice: ""
    property string volPercent: "0"
    property string volIcon: "󰕾"
    property bool isMuted: false
    property bool dndEnabled: false
    property int brightnessPct: 100
    property int maxBrightness: 100
    property bool isWifiOn: root.wifiStatus === "enabled"
    property bool isBtOn: root.btStatus === "on"
    property bool isSoundActive: !root.isMuted && parseInt(root.volPercent) > 0
    property bool isNetUp: root.isWifiOn || root.ethStatus === "Connected"

    property string clock: Qt.formatDateTime(new Date(), "HH:mm")

    // ------------------------------------------------------------------
    // ENTRANCE
    // ------------------------------------------------------------------
    property real introMain: 0

    function s(val) {
        return scaler.s(val);
    }

    function alpha(color, a) {
        return Qt.rgba(color.r, color.g, color.b, a);
    }

    // ------------------------------------------------------------------
    // HELPERS
    // ------------------------------------------------------------------
    function execCmd(cmdStr) {
        var safeCmd = cmdStr.replace(/`/g, "\\`");
        Qt.createQmlObject(`import Quickshell.Io; Process { command: ["bash","-c",\`${safeCmd}\`]; running:true; onExited:(c)=>destroy() }`, root);
    }

    function toggleWifi() {
        Quickshell.execDetached(["bash", "-c", root.scriptsDir + "/watchers/network_fetch.sh --toggle"]);
        wifiPoller.running = true;
    }

    function toggleBt() {
        Quickshell.execDetached(["bash", "-c", root.scriptsDir + "/watchers/bt_fetch.sh --toggle"]);
        btPoller.running = true;
    }

    function toggleDnd() {
        let next = root.dndEnabled ? "0" : "1";
        Quickshell.execDetached(["sh", "-c", "echo '" + next + "' > " + root.dndStateFile]);
        root.dndEnabled = !root.dndEnabled;
    }

    function toggleSound() {
        Quickshell.execDetached(["bash", "-c", root.scriptsDir + "/watchers/audio_fetch.sh --toggle"]);
        audioPoller.running = true;
    }

    function closePopup() {
        if (root.masterWindow && root.masterWindow.switchWidget)
            root.masterWindow.switchWidget("hidden", "");
        else
            Quickshell.execDetached(["bash", "-c", root.scriptsDir + "/../../qs_manager.sh close"]);
    }

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell"
    readonly property string dndStateFile: paths.getCacheDir("dnd") + "/state"

    focus: true

    // ------------------------------------------------------------------
    // SCALING & THEME
    // ------------------------------------------------------------------
    Scaler {
        id: scaler

        currentWidth: Screen.width
    }

    Caching {
        id: paths
    }

    MatugenColors {
        id: _theme
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.clock = Qt.formatDateTime(new Date(), "HH:mm")
    }

    // ------------------------------------------------------------------
    // DATA POLLERS
    // ------------------------------------------------------------------
    Process {
        id: wifiPoller

        running: true
        command: ["bash", "-c", root.scriptsDir + "/watchers/network_fetch.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try {
                        let d = JSON.parse(txt);
                        root.wifiStatus = d.status || root.wifiStatus;
                        root.wifiSsid = d.ssid || "";
                        root.ethStatus = d.eth_status || "Disconnected";
                    } catch (e) {
                    }
                }
            }
        }

    }

    Process {
        id: btPoller

        running: true
        command: ["bash", "-c", root.scriptsDir + "/watchers/bt_fetch.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try {
                        let d = JSON.parse(txt);
                        root.btStatus = d.status || root.btStatus;
                        root.btIcon = d.icon || root.btIcon;
                        root.btDevice = d.connected || "";
                    } catch (e) {
                    }
                }
            }
        }

    }

    Process {
        id: audioPoller

        running: true
        command: ["bash", "-c", root.scriptsDir + "/watchers/audio_fetch.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try {
                        let d = JSON.parse(txt);
                        root.volPercent = d.volume !== undefined ? d.volume.toString() : root.volPercent;
                        root.volIcon = d.icon || root.volIcon;
                        root.isMuted = (d.is_muted === "true");
                    } catch (e) {
                    }
                }
            }
        }

    }

    Process {
        id: dndPoller

        running: true
        command: ["bash", "-c", "cat '" + root.dndStateFile + "' 2>/dev/null || echo '0'"]

        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                let next = (txt === "1");
                if (root.dndEnabled !== next)
                    root.dndEnabled = next;

            }
        }

    }

    Process {
        id: brightnessPoller

        running: true
        command: ["bash", "-c", "brightnessctl -m 2>/dev/null | head -n1 | cut -d, -f4,6"]

        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    let parts = txt.split(",");
                    if (parts.length === 2) {
                        let pct = parseInt(parts[0]);
                        let max = parseInt(parts[1]);
                        if (!isNaN(pct))
                            root.brightnessPct = pct;

                        if (!isNaN(max) && max > 0)
                            root.maxBrightness = max;

                    }
                }
            }
        }

    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            wifiPoller.running = true;
            btPoller.running = true;
            audioPoller.running = true;
            dndPoller.running = true;
            brightnessPoller.running = true;
        }
    }

    Timer {
        id: volThrottle

        property int targetPct: -1

        interval: 60
        onTriggered: {
            if (targetPct >= 0) {
                if (targetPct > 0 && root.isMuted)
                    Quickshell.execDetached(["bash", root.scriptsDir + "/volume/audio_control.sh", "toggle-mute", "sink", "@DEFAULT@"]);
                Quickshell.execDetached(["bash", root.scriptsDir + "/volume/audio_control.sh", "set-volume", "sink", "@DEFAULT@", targetPct]);
                targetPct = -1;
            }
        }
    }

    Timer {
        id: brightThrottle

        property int targetPct: -1

        interval: 60
        onTriggered: {
            if (targetPct >= 0) {
                Quickshell.execDetached(["bash", "-c", "brightnessctl -q set " + targetPct + "%"]);
                targetPct = -1;
            }
        }
    }

    // ------------------------------------------------------------------
    // COMPONENTS
    // ------------------------------------------------------------------

    // Clean toggle row: icon, label, status, animated switch.
    component ToggleRow: Item {
        id: trow

        property bool active: false
        property color accent: root.blue
        property string icon: ""
        property string label: ""
        property string sublabel: ""
        property var onToggle: null

        Layout.fillWidth: true
        Layout.preferredHeight: root.s(62)

        Rectangle {
            anchors.fill: parent
            radius: root.s(18)
            color: trow.active ? root.alpha(trow.accent, 0.16) : Qt.rgba(0.5, 0.5, 0.52, 0.16)
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1

            Behavior on color {
                ColorAnimation {
                    duration: 220
                }
            }

        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (trow.onToggle) trow.onToggle()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.s(16)
            anchors.rightMargin: root.s(14)
            spacing: root.s(14)

            Rectangle {
                Layout.preferredWidth: root.s(40)
                Layout.preferredHeight: root.s(40)
                radius: root.s(14)
                color: trow.active ? root.alpha(trow.accent, 0.22) : Qt.rgba(1, 1, 1, 0.08)

                Behavior on color {
                    ColorAnimation {
                        duration: 220
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: trow.icon
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: root.s(18)
                    color: trow.active ? trow.accent : root.subtext0

                    Behavior on color {
                        ColorAnimation {
                            duration: 220
                        }
                    }

                }

            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.s(1)

                Text {
                    text: trow.label
                    font.family: "Inter, JetBrains Mono, sans-serif"
                    font.weight: Font.DemiBold
                    font.pixelSize: root.s(15)
                    color: root.text
                }

                Text {
                    text: trow.sublabel
                    elide: Text.ElideRight
                    font.family: "Inter, JetBrains Mono, sans-serif"
                    font.pixelSize: root.s(12.5)
                    color: trow.active ? root.alpha(trow.accent, 0.9) : root.overlay0

                    Behavior on color {
                        ColorAnimation {
                            duration: 220
                        }
                    }

                }

            }

            // Animated switch
            Item {
                Layout.preferredWidth: root.s(48)
                Layout.preferredHeight: root.s(28)

                Rectangle {
                    anchors.fill: parent
                    radius: root.s(14)
                    color: trow.active ? trow.accent : root.alpha("#ffffff", 0.14)

                    Behavior on color {
                        ColorAnimation {
                            duration: 220
                        }
                    }

                }

                Rectangle {
                    width: root.s(22)
                    height: root.s(22)
                    radius: root.s(11)
                    color: "#ffffff"
                    x: trow.active ? parent.width - width - root.s(3) : root.s(3)
                    y: root.s(3)

                    Behavior on x {
                        NumberAnimation {
                            duration: 240
                            easing.type: Easing.OutCubic
                        }
                    }

                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (trow.onToggle) trow.onToggle()
                    scale: pressed ? 0.92 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: 140
                            easing.type: Easing.OutBack
                        }
                    }

                }

            }

        }

    }

    // Clean slider row: icon, gradient track, knob, value.
    component SliderRow: Item {
        id: srow

        property string icon: ""
        property color accent: root.sapphire
        property real value: 0
        property string pctText: ""
        property var onSet: null
        property var onCommit: null

        Layout.fillWidth: true
        Layout.preferredHeight: root.s(54)

        Rectangle {
            anchors.fill: parent
            radius: root.s(18)
            color: Qt.rgba(0.5, 0.5, 0.52, 0.16)
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.s(16)
            anchors.rightMargin: root.s(16)
            spacing: root.s(14)

            Text {
                text: srow.icon
                font.family: "Iosevka Nerd Font"
                font.pixelSize: root.s(18)
                color: srow.accent
                Layout.preferredWidth: root.s(24)
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.s(26)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: root.s(6)
                    radius: root.s(3)
                    color: root.alpha("#ffffff", 0.12)
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    width: parent.width * (srow.value / 100)
                    height: root.s(6)
                    radius: root.s(3)

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0
                            color: srow.accent
                        }

                        GradientStop {
                            position: 1
                            color: Qt.lighter(srow.accent, 1.35)
                        }

                    }

                    Behavior on width {
                        enabled: !srowMa.dragging

                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutQuint
                        }
                    }

                }

                Rectangle {
                    id: srowKnob

                    width: root.s(17)
                    height: root.s(17)
                    radius: root.s(8.5)
                    color: srow.accent
                    border.color: root.alpha("#ffffff", 0.5)
                    border.width: 1
                    x: parent.width * (srow.value / 100) - width / 2
                    y: (parent.height - height) / 2
                    scale: srowMa.dragging || srowMa.containsMouse ? 1.3 : 1.0

                    Behavior on x {
                        enabled: !srowMa.dragging

                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutQuint
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutBack
                        }
                    }

                }

                MouseArea {
                    id: srowMa

                    property bool dragging: false

                    function setFromX(mx) {
                        let pct = Math.max(0, Math.min(100, Math.round((mx / width) * 100)));
                        if (srow.onSet) srow.onSet(pct);
                    }

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: (mouse) => {
                        dragging = true;
                        setFromX(mouse.x);
                    }
                    onPositionChanged: (mouse) => {
                        if (dragging)
                            setFromX(mouse.x);
                    }
                    onReleased: {
                        dragging = false;
                        if (srow.onCommit) srow.onCommit();
                    }
                }

            }

            Text {
                text: srow.pctText
                font.family: "Inter, JetBrains Mono, sans-serif"
                font.weight: Font.Medium
                font.pixelSize: root.s(13)
                color: root.subtext0
                Layout.preferredWidth: root.s(42)
                horizontalAlignment: Text.AlignRight
            }

        }

    }

    // ------------------------------------------------------------------
    // UI
    // ------------------------------------------------------------------
    Item {
        anchors.fill: parent
        scale: 0.94 + (0.06 * root.introMain)
        opacity: root.introMain

        Rectangle {
            id: mainCard

            anchors.fill: parent
            color: "transparent"
            radius: root.s(24)
            border.width: 0
            clip: true

            // ── Unified liquid-glass surface ──
            LiquidGlass {
                anchors.fill: parent
                tint: "#ffffff"
                cornerRadius: root.s(24)
                bodyOpacity: 0.04
            }

            // ── Hairline specular border ──
            Rectangle {
                anchors.fill: parent
                radius: root.s(24)
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.16)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: root.s(20)
                anchors.bottomMargin: root.s(20)
                anchors.leftMargin: root.s(20)
                anchors.rightMargin: root.s(20)
                spacing: root.s(14)

                // ── Header ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.s(12)

                    Text {
                        text: "Control Center"
                        font.family: "Inter, JetBrains Mono, sans-serif"
                        font.weight: Font.DemiBold
                        font.pixelSize: root.s(18)
                        color: root.text
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.clock
                        font.family: "Inter, JetBrains Mono, sans-serif"
                        font.weight: Font.Medium
                        font.pixelSize: root.s(14)
                        color: root.subtext0
                    }

                    Rectangle {
                        Layout.preferredWidth: root.s(36)
                        Layout.preferredHeight: root.s(36)
                        radius: root.s(18)
                        color: closeMa.containsMouse ? root.alpha("#ffffff", 0.1) : root.alpha("#ffffff", 0.04)
                        border.color: root.alpha("#ffffff", 0.08)
                        border.width: 1
                        scale: closeMa.pressed ? 0.88 : (closeMa.containsMouse ? 1.06 : 1.0)

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutBack
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅀"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: root.s(16)
                            color: root.subtext0
                        }

                        MouseArea {
                            id: closeMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closePopup()
                        }

                    }

                }

                // ── Toggles ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: root.s(8)

                    ToggleRow {
                        active: root.isWifiOn
                        accent: root.blue
                        icon: root.isNetUp ? (root.isWifiOn ? "󰤨" : "󰈀") : "󰤮"
                        label: "Wi-Fi"
                        sublabel: root.isNetUp
                            ? (root.isWifiOn ? (root.wifiSsid !== "" ? root.wifiSsid : "Connected") : "Ethernet")
                            : "Offline"
                        onToggle: root.toggleWifi
                    }

                    ToggleRow {
                        active: root.isBtOn
                        accent: root.mauve
                        icon: root.btIcon
                        label: "Bluetooth"
                        sublabel: root.isBtOn
                            ? (root.btDevice && root.btDevice !== "Disconnected" && root.btDevice !== "Off" ? root.btDevice : "Ready")
                            : "Off"
                        onToggle: root.toggleBt
                    }

                    ToggleRow {
                        active: root.dndEnabled
                        accent: root.red
                        icon: root.dndEnabled ? "󰂛" : "󰂚"
                        label: "Focus"
                        sublabel: root.dndEnabled ? "Do not disturb on" : "Do not disturb off"
                        onToggle: root.toggleDnd
                    }

                    ToggleRow {
                        active: root.isSoundActive
                        accent: root.green
                        icon: root.volIcon
                        label: "Sound"
                        sublabel: root.isMuted ? "Muted" : root.volPercent + "% volume"
                        onToggle: root.toggleSound
                    }

                }

                // ── Sliders ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: root.s(8)

                    SliderRow {
                        icon: root.volIcon
                        accent: root.isMuted ? root.overlay1 : root.sapphire
                        value: Math.min(100, parseInt(root.volPercent))
                        pctText: (root.isMuted ? 0 : Math.min(100, parseInt(root.volPercent))) + "%"
                        onSet: (p) => {
                            root.volPercent = p.toString();
                            volThrottle.targetPct = p;
                            if (!volThrottle.running)
                                volThrottle.start();
                        }
                        onCommit: () => {
                            audioPoller.running = true;
                        }
                    }

                    SliderRow {
                        icon: "󰃟"
                        accent: root.yellow
                        value: Math.min(100, Math.max(0, root.brightnessPct))
                        pctText: root.brightnessPct + "%"
                        onSet: (p) => {
                            root.brightnessPct = p;
                            brightThrottle.targetPct = p;
                            if (!brightThrottle.running)
                                brightThrottle.start();
                        }
                        onCommit: () => {
                            brightnessPoller.running = true;
                        }
                    }

                }

                Item {
                    Layout.fillHeight: true
                }

            }

        }

    }

    // ------------------------------------------------------------------
    // ENTRANCE ANIMATION
    // ------------------------------------------------------------------
    ParallelAnimation {
        running: true

        NumberAnimation {
            target: root
            property: "introMain"
            from: 0
            to: 1
            duration: 480
            easing.type: Easing.OutExpo
        }

    }

}
