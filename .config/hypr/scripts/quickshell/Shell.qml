//@ pragma UseQApplication
import QtQuick
import Quickshell

ShellRoot {
    id: shellRoot

    // Shared screen-space rect of the top-bar music pill, kept live by TopBar.
    // Main uses it to anchor/aim the music popup morph.
    property QtObject musicAnchor: QtObject {
        property real x: 0
        property real y: 0
        property real w: 0
        property real h: 0
    }

    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    Main { musicAnchor: shellRoot.musicAnchor }
    TopBar { musicAnchor: shellRoot.musicAnchor }
    Floating {}
    Dock {}
}

