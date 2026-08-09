import QtQuick

Rectangle {
    id: root

    property color tint: "white"
    property real tintOpacity: 0.14
    property real cornerRadius: 14
    property real borderOpacity: 0.40
    property real sheenStrength: 1.0

    property bool hovered: parent && parent.isHovered === true ? true : false

    property real tintOpacityHover: Math.min(tintOpacity + 0.05, 0.6)
    property real borderOpacityHover: Math.min(borderOpacity + 0.1, 0.7)
    property real sheenStrengthHover: sheenStrength + 0.3

    radius: root.cornerRadius
    clip: true
    color: "transparent"

    Rectangle {
        id: glassBase
        anchors.fill: parent
        radius: root.cornerRadius
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, (root.hovered ? root.tintOpacityHover : root.tintOpacity) * 0.35); Behavior on color { ColorAnimation { duration: 200 } } }
            GradientStop { position: 0.5; color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, (root.hovered ? root.tintOpacityHover : root.tintOpacity) * 0.65); Behavior on color { ColorAnimation { duration: 200 } } }
            GradientStop { position: 1.0; color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, (root.hovered ? root.tintOpacityHover : root.tintOpacity) * 1.15); Behavior on color { ColorAnimation { duration: 200 } } }
        }
    }

    Rectangle {
        id: sheen
        anchors.top: parent.top
        anchors.left: parent.left
        height: parent.height * 0.75
        width: parent.width * 2.4
        transform: Rotation { origin.x: 0; origin.y: 0; angle: -22 }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
            GradientStop { position: 0.18; color: Qt.rgba(1, 1, 1, 0.32 * (root.hovered ? root.sheenStrengthHover : root.sheenStrength)); Behavior on color { ColorAnimation { duration: 200 } } }
            GradientStop { position: 0.34; color: Qt.rgba(1, 1, 1, 0.0) }
            GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.10 * (root.hovered ? root.sheenStrengthHover : root.sheenStrength)); Behavior on color { ColorAnimation { duration: 200 } } }
            GradientStop { position: 0.72; color: Qt.rgba(1, 1, 1, 0.0) }
        }
    }
}
