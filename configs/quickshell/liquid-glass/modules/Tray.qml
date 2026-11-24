import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// Compact SystemTray pill (auto-hides when empty). Acts as a single button to open TrayMenu.
Item {
    id: root
    required property var theme
    property bool menuOpen: false
    property bool keyboardSelected: false

    signal menuToggleRequested()

    readonly property int totalCount: SystemTray.items.values.length
    readonly property bool hasOverflow: totalCount > 3
    readonly property int visibleCount: hasOverflow ? 2 : totalCount
    readonly property bool hasItems: totalCount > 0

    visible: hasItems
    implicitWidth: hasItems ? theme.evenPx(row.implicitWidth + 16) : 0
    implicitHeight: theme.pillHeight

    Rectangle {
        anchors.fill: parent
        radius: root.theme.pillRadius
        antialiasing: true
        color: (root.menuOpen || root.keyboardSelected)
            ? root.theme.glassPillActive
            : (trayMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))

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
        width: 16
        height: 2
        radius: 1
        color: root.theme.accent
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: SystemTray.items

            delegate: Item {
                required property SystemTrayItem modelData
                required property int index
                visible: index < root.visibleCount
                width: 18
                height: 18

                IconImage {
                    anchors.centerIn: parent
                    width: 15
                    height: 15
                    source: modelData.icon
                    opacity: (trayMouse.containsMouse || root.menuOpen || root.keyboardSelected) ? 1.0 : 0.88

                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.theme.animFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        Text {
            visible: root.hasOverflow
            anchors.verticalCenter: parent.verticalCenter
            text: "󰇘"
            color: (root.menuOpen || trayMouse.containsMouse) ? root.theme.accent : root.theme.textSecondary
            font.family: root.theme.fontMono
            font.pixelSize: root.theme.fontSizeMd
            renderType: Text.NativeRendering

            Behavior on color {
                ColorAnimation {
                    duration: root.theme.animFast
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    MouseArea {
        id: trayMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.menuToggleRequested()
    }
}
