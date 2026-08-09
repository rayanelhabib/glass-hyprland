import QtQuick
import Quickshell
import Quickshell.Wayland
import "./music"

PanelWindow {
    id: win
    screen: Quickshell.screens[0]

    WlrLayershell.namespace: "qs-music-test"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        left: true
    }
    width: 520
    height: 135
    margins {
        top: 150
        left: 300
    }

    Rectangle {
        anchors.fill: parent
        color: "#0000FF"
        z: -1
    }

    MusicPopup {
        id: popup
        width: 520
        height: 135

        Connections {
            target: popup
            function onMusicDataChanged() {
                console.log("MUSIC: status=" + popup.musicData.status + " blur=" + popup.musicData.blur + " art=" + popup.musicData.artUrl);
            }
        }
    }
}
