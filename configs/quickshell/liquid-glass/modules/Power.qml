import QtQuick

// Power menu trigger button for the rightmost side of the right island.
Item {
    id: root
    required property var theme
    property bool menuOpen: false
    property bool keyboardSelected: false

    signal clicked()

    implicitWidth: theme.evenPx(iconText.implicitWidth + 16)
    implicitHeight: theme.pillHeight

    Rectangle {
        anchors.fill: parent
        radius: root.theme.pillRadius
        antialiasing: true
        color: (root.menuOpen || root.keyboardSelected)
            ? root.theme.glassPillActive
            : (mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent")

        Behavior on color {
            ColorAnimation {
                duration: root.theme.animFast
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        visible: root.keyboardSelected
        anchors {
            bottom: parent.bottom
            bottomMargin: 2
            horizontalCenter: parent.horizontalCenter
        }
        width: Math.max(12, parent.width - 12)
        height: 2
        radius: 1
        color: root.theme.accent
    }

    Text {
        id: iconText
        anchors.centerIn: parent
        text: "󰐥"
        color: (root.menuOpen || root.keyboardSelected)
            ? root.theme.accent
            : (mouseArea.containsMouse ? root.theme.warn : root.theme.textPrimary)
        font.family: root.theme.fontMono
        font.pixelSize: 16
        renderType: Text.NativeRendering

        Behavior on color {
            ColorAnimation {
                duration: root.theme.animFast
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
