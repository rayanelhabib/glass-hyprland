import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray

Variants {
    id: topBarVariants
    model: Quickshell.screens

    property var musicAnchor: null

    delegate: Component {
        PanelWindow {
            id: barWindow
            property bool pendingReload: false

            property var musicAnchor: topBarVariants.musicAnchor
            
	    Caching { id: paths }

	    Component.onCompleted: {
 	        console.log("runDir:", paths.runDir)
 	        console.log("manual path:", paths.runDir + "/workspaces")
 	        console.log("env test:", Quickshell.env("QS_RUN_WORKSPACES"))
 	        console.log("wsPath:", paths.getRunDir("workspaces"))
	    }	     	
        
            IpcHandler {
                target: "topbar"
                function forceReload() {
                    Quickshell.reload(true) 
                }
                function queueReload() {
                    if (!barWindow.isSettingsOpen) {
                        Quickshell.reload(true)
                    } else {
                        barWindow.pendingReload = true
                    }
                }
                function toggleUpdate() {
                    barWindow.forceUpdateShow = !barWindow.forceUpdateShow
                }
            }

            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "qs-topbar"

            anchors {
                top: true
                left: true
                right: true
            }

            Scaler {
                id: scaler
                currentWidth: barWindow.width
            }

            property real baseScale: scaler.baseScale

            function s(val) { 
                return scaler.s(val); 
            }

            function toRoman(num) {
                var vals = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
                var rom = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"];
                var result = "";
                for (var i = 0; i < vals.length; i++) {
                    while (num >= vals[i]) {
                        result += rom[i];
                        num -= vals[i];
                    }
                }
                return result;
            }

            property int barHeight: s(30)


            height: barHeight
            margins { top: 0; bottom: 0; left: 0; right: 0 }
            exclusiveZone: barHeight 
            color: "transparent"

            MatugenColors {
                id: mocha
            }

            property bool showHelpIcon: true
            property bool isRecording: false
            
            property bool updateAvailable: false
            property bool forceUpdateShow: false
            property bool isUpdateVisible: updateAvailable || forceUpdateShow
            
            property int workspaceCount: 8
            
            property string activeWidget: "" 
            property bool isSettingsOpen: activeWidget === "settings"

            property real settingsSlideProgress: isSettingsOpen ? 1.0 : 0.0
            Behavior on settingsSlideProgress { 
                enabled: barWindow.startupCascadeFinished
                NumberAnimation { duration: 600; easing.type: Easing.OutExpo } 
            }

            onIsSettingsOpenChanged: {
                if (!barWindow.isSettingsOpen && barWindow.pendingReload) {
                    barWindow.pendingReload = false;
                    Quickshell.reload(true);
                }
            }

            Process {
                id: widgetPoller
                command: ["bash", "-c", "cat " + paths.runDir + "/current_widget 2>/dev/null || echo ''"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (barWindow.activeWidget !== txt) barWindow.activeWidget = txt;
                    }
                }
            }

            Process {
                id: widgetWatcher
                command: ["bash", "-c", "while [ ! -f " + paths.runDir + "/current_widget ]; do sleep 1; done; inotifywait -qq -e modify,close_write " + paths.runDir + "/current_widget"]
                running: true
                onExited: {
                    widgetPoller.running = false;
                    widgetPoller.running = true;
                    running = false;
                    running = true;
                }
            }
            
            Process {
                id: recPoller
                command: ["bash", "-c", "if [ -s " + paths.getCacheDir("recording") + "/rec_pid ] && kill -0 $(cat " + paths.getCacheDir("recording") + "/rec_pid) 2>/dev/null; then echo '1'; else echo '0'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.isRecording = (this.text.trim() === "1");
                    }
                }
            }

            Process {
 	    	id: recWatcher
 		running: true
 		command: ["bash", "-c", "inotifywait -qq -e create,delete,modify,close_write " + paths.getCacheDir("recording") + "/ 2>/dev/null || sleep 2"]
 	        onExited: {
 	        	recPoller.running = false;
 	         	recPoller.running = true;
 	         	running = false;
 	         	running = true;
 	        }
	    }	  
            Process {
	        id: updatePoller
	        command: ["bash", "-c", "if [ -f " + paths.getCacheDir("updater") + "/update_pending ]; then echo '1'; else echo '0'; fi"]
	        running: true
	        stdout: StdioCollector {
	            onStreamFinished: {
	                barWindow.updateAvailable = (this.text.trim() === "1");
	            }
	        }
	    }
	    
	    Process {
	        id: updateWatcher
	        running: true
	        command: ["bash", "-c", "inotifywait -qq -e create,delete,close_write " + paths.getCacheDir("updater") + "/ 2>/dev/null || sleep 5"]
	        onExited: {
	            updatePoller.running = false;
	            updatePoller.running = true;
	            running = false;
	            running = true;
	        }
	    }
	                
            Process {
                id: settingsReader
                command: ["bash", "-c", "cat ~/.config/hypr/settings.json 2>/dev/null || echo '{}'"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            if (this.text && this.text.trim().length > 0 && this.text.trim() !== "{}") {
                                let parsed = JSON.parse(this.text);
                                
                                if (parsed.topbarHelpIcon !== undefined && barWindow.showHelpIcon !== parsed.topbarHelpIcon) {
                                    barWindow.showHelpIcon = parsed.topbarHelpIcon;
                                }
                                
                                if (parsed.workspaceCount !== undefined && barWindow.workspaceCount !== parsed.workspaceCount) {
                                    barWindow.workspaceCount = parsed.workspaceCount;
                                    wsDaemon.running = false;
                                    wsDaemon.running = true;
                                }
                            }
                        } catch (e) {}
                    }
                }
            }

            Process {
                id: settingsWatcher
                command: ["bash", "-c", "while [ ! -f ~/.config/hypr/settings.json ]; do sleep 1; done; inotifywait -qq -e modify,close_write ~/.config/hypr/settings.json"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        settingsReader.running = false;
                        settingsReader.running = true;
                        
                        settingsWatcher.running = false;
                        settingsWatcher.running = true;
                    }
                }
            }
            
            property bool isDesktop: false
            property string ethStatus: "Ethernet"

            Process {
                id: chassisDetector
                running: true
                command: ["bash", "-c", "if ls /sys/class/power_supply/BAT* 1> /dev/null 2>&1; then echo 'laptop'; else echo 'desktop'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.isDesktop = (this.text.trim() === "desktop");
                    }
                }
            }

            property bool isStartupReady: false
            Timer { interval: 10; running: true; onTriggered: barWindow.isStartupReady = true }
            
            property bool startupCascadeFinished: false
            Timer { interval: 1000; running: true; onTriggered: barWindow.startupCascadeFinished = true }
            
            property bool fastPollerLoaded: false
            property bool isDataReady: fastPollerLoaded
            Timer { interval: 600; running: true; onTriggered: barWindow.isDataReady = true }
            
            property string timeStr: ""
            property string fullDateStr: ""
            property int typeInIndex: 0
            property string dateStr: fullDateStr.substring(0, typeInIndex)
            property string timeShort: timeStr.length >= 5 ? timeStr.substring(0, 5) : timeStr
            property string dateShort: fullDateStr

            property string weatherIcon: ""
            property string weatherTemp: "--°"
            property string weatherHex: mocha.yellow
            
            property string wifiStatus: "Off"
            property string wifiIcon: "󰤮"
            property string wifiSsid: ""
            
            property string btStatus: "Off"
            property string btIcon: "󰂲"
            property string btDevice: ""
            
            property string volPercent: "0%"
            property string volIcon: "󰕾"
            property bool isMuted: false
            
            property string batPercent: "100%"
            property string batIcon: "󰁹"
            property string batStatus: "Unknown"
            
            property string kbLayout: "us"
            
            ListModel { 
                id: workspacesModel 
                property int activeIndex: 0
            }
            
            property var musicData: { "status": "Stopped", "title": "", "artUrl": "", "timeStr": "" }

            property string displayTitle: ""
            property string displayTime: ""
            property string displayArtUrl: ""

            onMusicDataChanged: {
                if (musicData && musicData.status !== "Stopped" && musicData.title !== "") {
                    displayTitle = musicData.title;
                    displayTime = musicData.timeStr;
                    displayArtUrl = musicData.artUrl;
                }
            }

            property bool isMediaActive: barWindow.musicData.status !== "Stopped" && barWindow.musicData.title !== ""
            property bool isWifiOn: barWindow.wifiStatus.toLowerCase() === "enabled" || barWindow.wifiStatus.toLowerCase() === "on"
            property bool isBtOn: barWindow.btStatus.toLowerCase() === "enabled" || barWindow.btStatus.toLowerCase() === "on"
            property bool showEthernet: barWindow.ethStatus === "Connected" || (barWindow.isDesktop && !barWindow.isWifiOn)
            
            property bool isSoundActive: !barWindow.isMuted && parseInt(barWindow.volPercent) > 0
            property int batCap: parseInt(barWindow.batPercent) || 0
            property bool isCharging: barWindow.batStatus === "Charging" || barWindow.batStatus === "Full"
            
            property color batDynamicColor: {
                if (isCharging) return mocha.green;
                if (batCap <= 20) return mocha.red;
                return mocha.text; 
            }

            Process {
                id: wsDaemon
                command: ["bash", "-c", "~/.config/hypr/scripts/workspaces.sh"]
                running: true
            }

            Process {
		id: wsReader
		running: true
                command: ["cat", paths.getRunDir("workspaces") + "/workspaces.json"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try { 
                                let newData = JSON.parse(txt);
                                
                                while (workspacesModel.count < newData.length) {
                                    workspacesModel.append({ "wsId": "", "wsState": "" });
                                }
                                
                                while (workspacesModel.count > newData.length) {
                                    workspacesModel.remove(workspacesModel.count - 1);
                                }
                                
                                let newActive = -1;

                                for (let i = 0; i < newData.length; i++) {
                                    if (newData[i].state === "active") newActive = i;

                                    if (workspacesModel.get(i).wsState !== newData[i].state) {
                                        workspacesModel.setProperty(i, "wsState", newData[i].state);
                                    }
                                    if (workspacesModel.get(i).wsId !== newData[i].id.toString()) {
                                        workspacesModel.setProperty(i, "wsId", newData[i].id.toString());
                                    }
                                }

                                if (newActive !== -1 && workspacesModel.activeIndex !== newActive) {
                                    workspacesModel.activeIndex = newActive;
                                }

                            } catch(e) {}
                        }
                    }
                }
            }

            Process {
                id: wsWatcher
                running: true
                command: ["bash", "-c", "inotifywait -qq -e close_write,modify " + paths.getRunDir("workspaces") + "/workspaces.json"]
                onExited: {
                    wsReader.running = false;
                    wsReader.running = true;
                    running = false;
                    running = true;
                }
            }

            Process {
                id: musicForceRefresh
                running: true
                command: ["bash", "-c", "bash ~/.config/hypr/scripts/quickshell/music/music_info.sh | tee " + paths.getRunDir("music") + "/music_info.json"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try { barWindow.musicData = JSON.parse(txt); } catch(e) {}
                        }
                    }
                }
            }

            Timer {
                interval: 1000
                running: barWindow.musicData !== null && barWindow.musicData.status === "Playing"
                repeat: true
                onTriggered: {
                    if (!barWindow.musicData || barWindow.musicData.status !== "Playing") return;
                    if (!barWindow.musicData.timeStr || barWindow.musicData.timeStr === "") return;

                    let parts = barWindow.musicData.timeStr.split(" / ");
                    if (parts.length !== 2) return;

                    let posParts = parts[0].split(":").map(Number);
                    let lenParts = parts[1].split(":").map(Number);

                    let posSecs = (posParts.length === 3) 
                        ? (posParts[0] * 3600 + posParts[1] * 60 + posParts[2]) 
                        : (posParts[0] * 60 + posParts[1]);

                    let lenSecs = (lenParts.length === 3) 
                        ? (lenParts[0] * 3600 + lenParts[1] * 60 + lenParts[2]) 
                        : (lenParts[0] * 60 + lenParts[1]);

                    if (isNaN(posSecs) || isNaN(lenSecs)) return;

                    posSecs++;
                    if (posSecs > lenSecs) posSecs = lenSecs;

                    let newPosStr = "";
                    if (posParts.length === 3) {
                        let h = Math.floor(posSecs / 3600);
                        let m = Math.floor((posSecs % 3600) / 60);
                        let s = posSecs % 60;
                        newPosStr = h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                    } else {
                        let m = Math.floor(posSecs / 60);
                        let s = posSecs % 60;
                        newPosStr = (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                    }

                    let newData = Object.assign({}, barWindow.musicData);
                    newData.timeStr = newPosStr + " / " + parts[1];
                    newData.positionStr = newPosStr;
                    if (lenSecs > 0) newData.percent = (posSecs / lenSecs) * 100;
                    
                    barWindow.musicData = newData;
                }
            }

            Process {
                id: mprisWatcher
                running: true
                command: ["bash", "-c", "dbus-monitor --session \"type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.mpris.MediaPlayer2.Player'\" \"type='signal',interface='org.mpris.MediaPlayer2.Player',member='Seeked'\" 2>/dev/null | grep -m 1 'member=' > /dev/null || sleep 2"]
                onExited: {
                    musicForceRefresh.running = false;
                    musicForceRefresh.running = true;
                    running = false;
                    running = true;
                }
            }

            Timer {
                id: artRetryTimer
                interval: 500
                repeat: true
                running: barWindow.displayArtUrl && barWindow.displayArtUrl.indexOf("placeholder_blank.png") !== -1
                onTriggered: {
                    musicForceRefresh.running = false;
                    musicForceRefresh.running = true;
                }
            }

            Process {
                id: kbPoller; running: true
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/kb_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "" && barWindow.kbLayout !== txt) barWindow.kbLayout = txt;
                        kbWaiter.running = false;
                        kbWaiter.running = true;
                        barWindow.fastPollerLoaded = true; 
                    }
                }
            }
            Process { id: kbWaiter; command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/kb_wait.sh"]; onExited: { kbPoller.running = false; kbPoller.running = true; } }

            Process {
                id: audioPoller; running: true
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/audio_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                let newVol = data.volume.toString() + "%";
                                if (barWindow.volPercent !== newVol) barWindow.volPercent = newVol;
                                if (barWindow.volIcon !== data.icon) barWindow.volIcon = data.icon;
                                let newMuted = (data.is_muted === "true");
                                if (barWindow.isMuted !== newMuted) barWindow.isMuted = newMuted;
                            } catch(e) {}
                        }
                        audioWaiter.running = false;
                        audioWaiter.running = true;
                    }
                }
            }
            Process { id: audioWaiter; command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/audio_wait.sh"]; onExited: { audioPoller.running = false; audioPoller.running = true; } }

            Process {
                id: networkPoller; running: true
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/network_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                if (barWindow.wifiStatus !== data.status) barWindow.wifiStatus = data.status;
                                if (barWindow.wifiIcon !== data.icon) barWindow.wifiIcon = data.icon;
                                if (barWindow.wifiSsid !== data.ssid) barWindow.wifiSsid = data.ssid;
                                if (barWindow.ethStatus !== data.eth_status) barWindow.ethStatus = data.eth_status;
                            } catch(e) {}
                        }
                        networkWaiter.running = false;
                        networkWaiter.running = true;
                    }
                }
            }
            Process { id: networkWaiter; command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/network_wait.sh"]; onExited: { networkPoller.running = false; networkPoller.running = true; } }

            Process {
                id: btPoller; running: true
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/bt_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                if (barWindow.btStatus !== data.status) barWindow.btStatus = data.status;
                                if (barWindow.btIcon !== data.icon) barWindow.btIcon = data.icon;
                                if (barWindow.btDevice !== data.connected) barWindow.btDevice = data.connected;
                            } catch(e) {}
                        }
                        btWaiter.running = false;
                        btWaiter.running = true;
                    }
                }
            }
            Process { id: btWaiter; command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/bt_wait.sh"]; onExited: { btPoller.running = false; btPoller.running = true; } }

            Process {
                id: batteryPoller; running: true
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/battery_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                let newBat = data.percent.toString() + "%";
                                if (barWindow.batPercent !== newBat) barWindow.batPercent = newBat;
                                if (barWindow.batIcon !== data.icon) barWindow.batIcon = data.icon;
                                if (barWindow.batStatus !== data.status) barWindow.batStatus = data.status;
                            } catch(e) {}
                        }
                        batteryWaiter.running = false;
                        batteryWaiter.running = true;
                    }
                }
            }
            Process { id: batteryWaiter; command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/battery_wait.sh"]; onExited: { batteryPoller.running = false; batteryPoller.running = true; } }

            Process {
                id: weatherPoller
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/calendar/weather.sh --current-all"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let lines = this.text.trim().split("\n");
                        if (lines.length >= 3) {
                            barWindow.weatherIcon = lines[0];
                            barWindow.weatherTemp = lines[1];
                            barWindow.weatherHex = lines[2] || mocha.yellow;
                        }
                    }
                }
            }
            Timer { interval: 150000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { weatherPoller.running = false; weatherPoller.running = true; } }


            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    let d = new Date();
                    barWindow.timeStr = Qt.formatDateTime(d, "HH:mm:ss");
                    barWindow.fullDateStr = Qt.formatDateTime(d, "dddd, MMMM dd");
                    if (barWindow.typeInIndex >= barWindow.fullDateStr.length) {
                        barWindow.typeInIndex = barWindow.fullDateStr.length;
                    }
                }
            }

            Timer {
                id: typewriterTimer
                interval: 40
                running: barWindow.isStartupReady && barWindow.typeInIndex < barWindow.fullDateStr.length
                repeat: true
                onTriggered: barWindow.typeInIndex += 1
            }
            Item {
                anchors.fill: parent

                // ------------------------------------------------------------------
                // Reusable flat icon button (macOS menu-bar style: no per-button
                // glass, just a subtle hover highlight on the glass bar).
                // ------------------------------------------------------------------
                component GlyphButton: Item {
                    id: gb
                    signal clicked()
                    property string glyph: ""
                    property color activeColor: mocha.text
                    property color hoverColor: mocha.blue
                    property real glyphSize: barWindow.s(15)
                    property bool dimmed: false
                    property bool visibleIf: true

                    visible: visibleIf
                    width: barWindow.s(30)
                    height: barWindow.barHeight

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - barWindow.s(6)
                        height: parent.height - barWindow.s(12)
                        radius: barWindow.s(8)
                        color: gbHover.containsMouse ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.12) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: gb.glyph
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: gb.glyphSize
                        color: gbHover.containsMouse ? gb.hoverColor : (gb.dimmed ? mocha.overlay0 : gb.activeColor)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        scale: gbHover.containsMouse ? 1.12 : 1.0
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    }
                    MouseArea {
                        id: gbHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: gb.clicked()
                    }
                }

                component PillDivider: Item {
                    width: 1
                    height: barWindow.barHeight
                    Rectangle {
                        anchors.centerIn: parent
                        width: 1
                        height: barWindow.s(18)
                        radius: 1
                        color: Qt.rgba(1, 1, 1, 0.12)
                    }
                }

                // ------------------------------------------------------------------
                //  THE BAR — a single compact liquid-glass bar spanning the full
                //  width of the screen (macOS menu-bar style, slim height).
                // ------------------------------------------------------------------
                Item {
                    id: barWrap

                    property bool shown: false
                    opacity: shown ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    transform: Translate {
                        y: barWrap.shown ? 0 : barWindow.s(-14)
                        Behavior on y { NumberAnimation { duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    }

                    Timer {
                        running: barWindow.isStartupReady
                        interval: 200
                        onTriggered: barWrap.shown = true
                    }

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: barWindow.barHeight

                    // ── Liquid glass surface (painted by hyprglass) ──
                    Rectangle {
                        anchors.fill: parent
                        radius: 0
                        color: "transparent"
                        clip: true

                        LiquidGlass {
                            anchors.fill: parent
                            tint: mocha.base
                            cornerRadius: 0
                            bodyOpacity: 0.06
                        }

                        // Subtle bottom hairline
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.10)
                        }
                    }

                    // ── LEFT group: utilities + workspaces ──
                    Row {
                        id: leftRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: barWindow.s(6)
                        spacing: barWindow.s(2)

                        GlyphButton {
                            id: helpBtn
                            visibleIf: barWindow.showHelpIcon
                            glyph: "󰋗"
                            activeColor: mocha.text
                            hoverColor: mocha.teal
                            onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle guide"])
                        }

                        GlyphButton {
                            glyph: "󰍉"
                            activeColor: mocha.text
                            hoverColor: mocha.blue
                            onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle applauncher"])
                        }

                        GlyphButton {
                            glyph: ""
                            activeColor: mocha.text
                            hoverColor: mocha.blue
                            onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle settings"])
                        }

                        GlyphButton {
                            id: updateBtn
                            visibleIf: barWindow.isUpdateVisible
                            glyph: "󰚰"
                            activeColor: mocha.green
                            hoverColor: mocha.text
                            onClicked: {
                                barWindow.updateAvailable = false;
                                barWindow.forceUpdateShow = false;
                                Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle updater"]);
                            }
                        }

                        // ============ WORKSPACES ============
                        Item {
                            id: wsBox
                            width: wsRow.implicitWidth
                            height: barWindow.barHeight

                            // ── Continuous Sliding Active Pill with Elastic Spring ──
                            Rectangle {
                                id: activePill
                                z: 0
                                property int activeIdx: workspacesModel.activeIndex >= 0 ? workspacesModel.activeIndex : 0
                                property Item activeItem: (wsRepeater.count > activeIdx && activeIdx >= 0) ? wsRepeater.itemAt(activeIdx) : null

                                visible: activeItem !== null && workspacesModel.count > 0 && activeItem.width > 0
                                x: activeItem ? (wsRow.x + activeItem.x + barWindow.s(2)) : 0
                                y: activeItem ? (wsRow.y + activeItem.y + barWindow.s(3)) : 0
                                width: activeItem ? (activeItem.width - barWindow.s(4)) : 0
                                height: activeItem ? (activeItem.height - barWindow.s(6)) : 0
                                radius: barWindow.s(6)
                                color: mocha.mauve

                                Behavior on x {
                                    NumberAnimation {
                                        duration: 320
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.25
                                    }
                                }
                                Behavior on y {
                                    NumberAnimation {
                                        duration: 320
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.25
                                    }
                                }
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 260
                                        easing.type: Easing.OutQuint
                                    }
                                }
                                Behavior on height {
                                    NumberAnimation {
                                        duration: 260
                                        easing.type: Easing.OutQuint
                                    }
                                }
                            }

                            Row {
                                id: wsRow
                                anchors.centerIn: parent
                                spacing: barWindow.s(3)

                                Repeater {
                                    id: wsRepeater
                                    model: workspacesModel
                                    delegate: Item {
                                        id: wsDelegate
                                        property string wsLabel: barWindow.toRoman(parseInt(model.wsId) || 0)
                                        property bool isActive: model.wsState === "active"
                                        property bool isOccupied: model.wsState === "occupied"
                                        width: Math.max(barWindow.s(24), barWindow.s(10) + wsLabel.length * barWindow.s(8))
                                        height: barWindow.barHeight

                                        Rectangle {
                                            id: wsBg
                                            anchors.fill: parent
                                            anchors.margins: barWindow.s(3)
                                            radius: barWindow.s(6)
                                            color: !isActive && isOccupied
                                                ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, wsHover.containsMouse ? 0.20 : 0.12)
                                                : (wsHover.containsMouse ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08) : "transparent")
                                            Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutQuad } }
                                            scale: wsHover.pressed ? 0.88 : (wsHover.containsMouse ? 1.08 : 1.0)
                                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: wsLabel
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: barWindow.s(12)
                                            font.weight: isActive ? Font.Black : (isOccupied ? Font.Bold : Font.Medium)
                                            color: isActive
                                                ? mocha.crust
                                                : (wsHover.containsMouse ? mocha.text : (isOccupied ? mocha.text : mocha.overlay0))
                                            Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutQuint } }
                                            scale: isActive ? 1.06 : (wsHover.containsMouse ? 1.08 : 1.0)
                                            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                                        }

                                        MouseArea {
                                            id: wsHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh " + model.wsId])
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── RIGHT group: weather, music, controls, clock ──
                    Row {
                        id: rightRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: barWindow.s(6)
                        spacing: barWindow.s(2)

                        // ============ WEATHER ============
                        Item {
                            width: (barWindow.weatherTemp && barWindow.weatherTemp !== "--°") ? barWindow.s(58) : 0
                            height: barWindow.barHeight
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                            visible: width > 0

                            Row {
                                anchors.centerIn: parent
                                spacing: barWindow.s(4)
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: barWindow.weatherIcon
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: barWindow.s(15)
                                    color: barWindow.weatherHex
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: barWindow.weatherTemp
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: barWindow.s(12)
                                    font.weight: Font.Bold
                                    color: mocha.peach
                                }
                            }
                        }

                        // ============ MUSIC ============
                        Item {
                            id: musicPill
                            width: musicRow.implicitWidth + barWindow.s(10)
                            height: barWindow.barHeight

                            Row {
                                id: musicRow
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: barWindow.s(4)
                                spacing: barWindow.s(6)

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: barWindow.isMediaActive ? "󰓇" : "󰎆"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: barWindow.s(15)
                                    color: musicHover.containsMouse ? mocha.text : (barWindow.isMediaActive ? mocha.mauve : mocha.overlay2)
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: barWindow.isMediaActive
                                    text: barWindow.displayTitle
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: barWindow.s(12)
                                    font.weight: Font.Bold
                                    color: musicHover.containsMouse ? mocha.text : mocha.subtext0
                                    width: Math.min(implicitWidth, barWindow.s(110))
                                    elide: Text.ElideRight
                                }
                                Item {
                                    visible: barWindow.musicData.status === "Playing"
                                    width: barWindow.s(6); height: barWindow.s(6)
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: mocha.mauve
                                        SequentialAnimation on scale {
                                            running: barWindow.musicData.status === "Playing"
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 1.4; duration: 600; easing.type: Easing.InOutQuad }
                                            NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                                        }
                                    }
                                }
                            }
                            MouseArea {
                                id: musicHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle music"])
                            }
                        }

                        // Keep the shared musicAnchor in sync with the pill's screen rect
                        Timer {
                            interval: 200
                            repeat: true
                            running: barWindow.musicAnchor !== null
                            onTriggered: {
                                let a = barWindow.musicAnchor;
                                if (!a) return;
                                let g = musicPill.mapToGlobal(0, 0);
                                a.x = g.x; a.y = g.y; a.w = musicPill.width; a.h = musicPill.height;
                            }
                        }

                        PillDivider {}

                        // ============ SYSTEM TRAY ============
                        Item {
                            id: trayModule
                            width: trayRepeater.count > 0 ? trayRow.implicitWidth : 0
                            height: barWindow.barHeight
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                            visible: width > 0

                            Row {
                                id: trayRow
                                anchors.centerIn: parent
                                spacing: barWindow.s(8)
                                Repeater {
                                    id: trayRepeater
                                    model: SystemTray.items
                                    delegate: Image {
                                        id: trayIcon
                                        source: modelData.icon || ""
                                        fillMode: Image.PreserveAspectFit
                                        sourceSize: Qt.size(barWindow.s(15), barWindow.s(15))
                                        width: barWindow.s(15)
                                        height: barWindow.s(15)
                                        anchors.verticalCenter: parent.verticalCenter
                                        opacity: trayIconMouse.containsMouse ? 1.0 : 0.85
                                        Behavior on opacity { NumberAnimation { duration: 150 } }

                                        QsMenuAnchor {
                                            id: menuAnchor
                                            anchor.window: barWindow
                                            anchor.item: trayIcon
                                            menu: modelData.menu
                                        }
                                        MouseArea {
                                            id: trayIconMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                            onClicked: mouse => {
                                                if (mouse.button === Qt.LeftButton) {
                                                    if (modelData.isMenuOnly || modelData.onlyMenu) {
                                                        menuAnchor.open();
                                                    } else if (typeof modelData.activate === "function") {
                                                        modelData.activate();
                                                    }
                                                } else if (mouse.button === Qt.MiddleButton) {
                                                    if (typeof modelData.secondaryActivate === "function") {
                                                        modelData.secondaryActivate();
                                                    }
                                                } else if (mouse.button === Qt.RightButton) {
                                                    if (modelData.menu) {
                                                        menuAnchor.open();
                                                    } else if (typeof modelData.contextMenu === "function") {
                                                        modelData.contextMenu(mouse.x, mouse.y);
                                                    } else {
                                                        modelData.activate();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ============ LANGUAGE ============
                        Item {
                            width: kbText.implicitWidth + barWindow.s(26)
                            height: barWindow.barHeight
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - barWindow.s(4)
                                height: parent.height - barWindow.s(12)
                                radius: barWindow.s(8)
                                color: kbHover.containsMouse ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.12) : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            Row {
                                anchors.centerIn: parent
                                spacing: barWindow.s(4)
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰌌"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: barWindow.s(15)
                                    color: kbHover.containsMouse ? mocha.text : mocha.overlay2
                                }
                                Text {
                                    id: kbText
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: barWindow.kbLayout
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: barWindow.s(12)
                                    font.weight: Font.Black
                                    color: mocha.text
                                }
                            }
                            MouseArea {
                                id: kbHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", "next"])
                            }
                        }

                        // ============ WIFI ============
                        GlyphButton {
                            glyph: barWindow.showEthernet ? "󰈀" : barWindow.wifiIcon
                            activeColor: barWindow.showEthernet ? (barWindow.ethStatus === "Connected" ? mocha.blue : mocha.overlay0) : (barWindow.isWifiOn ? mocha.blue : mocha.overlay0)
                            hoverColor: mocha.blue
                            dimmed: !barWindow.showEthernet && !barWindow.isWifiOn
                            glyphSize: barWindow.s(15)
                            onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle controlcenter"])
                        }

                        // ============ BLUETOOTH ============
                        GlyphButton {
                            visibleIf: !barWindow.isDesktop
                            glyph: barWindow.btIcon
                            activeColor: barWindow.isBtOn ? mocha.mauve : mocha.overlay0
                            hoverColor: mocha.mauve
                            dimmed: !barWindow.isBtOn
                            glyphSize: barWindow.s(15)
                            onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle controlcenter"])
                        }

                        // ============ VOLUME ============
                        GlyphButton {
                            glyph: barWindow.volIcon
                            activeColor: barWindow.isSoundActive ? mocha.peach : mocha.overlay0
                            hoverColor: mocha.peach
                            dimmed: !barWindow.isSoundActive
                            glyphSize: barWindow.s(15)
                            onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle controlcenter"])
                        }

                        // ============ BATTERY ============
                        Item {
                            visible: !barWindow.isDesktop
                            width: batText.visible ? barWindow.s(52) : barWindow.s(30)
                            height: barWindow.barHeight
                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                            Row {
                                anchors.centerIn: parent
                                spacing: barWindow.s(4)
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: barWindow.batIcon
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: barWindow.s(15)
                                    color: barWindow.batDynamicColor
                                }
                                Text {
                                    id: batText
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: barWindow.batPercent
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: barWindow.s(11)
                                    font.weight: Font.Black
                                    color: barWindow.batDynamicColor
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle controlcenter"])
                            }
                        }

                        PillDivider {}

                        // ============ CONTROL CENTER ============
                        GlyphButton {
                            glyph: "󰘓"
                            activeColor: mocha.text
                            hoverColor: mocha.sapphire
                            glyphSize: barWindow.s(15)
                            onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle controlcenter"])
                        }

                        // ============ RECORDING ============
                        Item {
                            visible: barWindow.isRecording
                            width: barWindow.s(22)
                            height: barWindow.barHeight
                            Rectangle {
                                anchors.centerIn: parent
                                width: barWindow.s(8)
                                height: barWindow.s(8)
                                radius: width / 2
                                color: mocha.red
                                SequentialAnimation on opacity {
                                    running: barWindow.isRecording
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    barWindow.isRecording = false;
                                    Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/screenshot.sh"]);
                                }
                            }
                        }

                        // ============ CLOCK (far right) ============
                        Item {
                            width: clockRow.implicitWidth
                            height: barWindow.barHeight

                            Row {
                                id: clockRow
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: barWindow.s(8)

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: barWindow.dateShort
                                    font.family: "Inter"
                                    font.pixelSize: barWindow.s(10)
                                    font.weight: Font.Medium
                                    color: mocha.subtext0
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: barWindow.timeShort
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: barWindow.s(13)
                                    font.weight: Font.Bold
                                    color: mocha.text
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle calendar"])
                            }
                        }
                    }
                }
            }
        }
    }
}

