import QtQuick

// LiquidGlass — macOS 26 "liquid glass" material for full surfaces.
//
// This component is intentionally a clean, mask-only carrier: the hyprglass
// compositor plugin paints the actual liquid glass (sharp backdrop, Snell
// refraction, chromatic fringing, specular gloss) on this layer's surface.
// All the QML does is provide a rounded region with alpha > 0 so the plugin's
// mask covers the whole pane — plus an optional, very subtle cursor-following
// specular glare (macOS liquid glass interaction), off by default.
Rectangle {
    id: root

    // Theme tint used only as the invisible alpha carrier (see bodyOpacity).
    property color tint: "#ffffff"

    // 0..1 — alpha of the surface. Kept just above 0 so the plugin's glass
    // mask covers the whole pane; it must stay low or it reads as grey.
    property real bodyOpacity: 0.04

    property real cornerRadius: 16

    // Liquid interaction — a soft elliptical glare that trails the cursor.
    // Enable it and feed cursorX/cursorY + sheenGlow from a hover MouseArea.
    property bool cursorSheen: false
    property real cursorX: 0
    property real cursorY: 0
    property real sheenGlow: 0.0

    radius: root.cornerRadius
    clip: true
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, root.bodyOpacity)
    }

    // Soft elliptical glare that trails the cursor — the specular catch of
    // real liquid glass. Subtle by design (max ~10% white), it reads as a
    // light bending over the surface, not a painted object.
    Canvas {
        id: sheen
        anchors.fill: parent
        visible: root.cursorSheen
        opacity: root.sheenGlow
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: root
            function onCursorXChanged() { sheen.requestPaint(); }
            function onCursorYChanged() { sheen.requestPaint(); }
        }

        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var r = Math.min(width, height) * 0.42;
            ctx.save();
            ctx.translate(root.cursorX, root.cursorY);
            ctx.scale(1.8, 0.55);
            var g = ctx.createRadialGradient(0, 0, 0, 0, 0, r);
            g.addColorStop(0, "rgba(255,255,255,0.55)");
            g.addColorStop(0.5, "rgba(255,255,255,0.18)");
            g.addColorStop(1, "rgba(255,255,255,0)");
            ctx.fillStyle = g;
            ctx.beginPath();
            ctx.arc(0, 0, r, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();
        }
    }
}
