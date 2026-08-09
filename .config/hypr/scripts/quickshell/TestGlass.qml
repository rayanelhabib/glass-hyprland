import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win
    screen: Quickshell.screens[0]

    WlrLayershell.namespace: "qs-glass-test"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors { top: true; left: true }
    width: 400
    height: 400
    margins { top: 100; left: 100 }

    Rectangle {
        id: cover
        anchors.fill: parent
        color: "#313244"
        radius: 12
        clip: true

        Rectangle {
            id: glassPanel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.bottomMargin: 16
            height: 160
            radius: 22
            border.color: Qt.rgba(1, 1, 1, 0.3)
            border.width: 1
            clip: true

            // A) frost image (dark 1x1 placeholder)
            Image {
                id: frost
                anchors.fill: parent
                source: "file:///run/user/1000/quickshell/music/covers/placeholder_blank.png"
                fillMode: Image.PreserveAspectCrop
                opacity: 0.9
            }

            // B) tint
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.35)
            }

            // C) sheen
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: parent.height * 0.5
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.16) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                }
            }

            // marker row so we know the panel bounds
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 2
                color: "#00FF00"
            }
        }
    }
}
