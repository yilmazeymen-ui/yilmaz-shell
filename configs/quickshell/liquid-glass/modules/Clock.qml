import QtQuick
import Quickshell

// Tabular clock & date (lives inside the Center Liquid Glass island). Click to toggle seconds.
Item {
    id: root
    required property var theme
    property bool showSeconds: false
    property bool keyboardSelected: false
    property int unreadCount: 0
    property bool dndEnabled: false
    readonly property bool hovered: mouseArea.containsMouse
    readonly property var shortMonths: [
        "Oca", "Şub", "Mar", "Nis", "May", "Haz",
        "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"
    ]

    signal themeMenuRequested()
    signal calendarMenuRequested()
    signal notificationsMenuRequested()

    function toggleSeconds() {
        showSeconds = !showSeconds;
    }

    implicitWidth: theme.evenPx(row.implicitWidth + 24)
    implicitHeight: theme.pillHeight

    Rectangle {
        anchors.fill: parent
        radius: root.theme.pillRadius
        antialiasing: true
        color: root.keyboardSelected ? root.theme.glassPillActive : "transparent"

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
        width: Math.max(20, parent.width - 24)
        height: 2
        radius: 1
        color: root.theme.accent
    }

    SystemClock {
        id: clock
        precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, root.showSeconds ? "HH:mm:ss" : "HH:mm")
            color: root.theme.textPrimary
            font.family: root.theme.fontMono
            font.pixelSize: root.theme.fontSizeMd
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            renderType: Text.NativeRendering
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "·"
            color: root.theme.textMuted
            font.family: root.theme.fontUi
            font.pixelSize: root.theme.fontSizeMd
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: String(clock.date.getDate()).padStart(2, "0") + " " + root.shortMonths[clock.date.getMonth()]
            color: root.theme.textSecondary
            font.family: root.theme.fontUi
            font.pixelSize: root.theme.fontSizeMd
            font.weight: Font.Medium
            renderType: Text.NativeRendering
        }

        Text {
            visible: root.dndEnabled
            anchors.verticalCenter: parent.verticalCenter
            text: "󰂛"
            color: root.theme.warn
            font.family: root.theme.fontUi
            font.pixelSize: root.theme.fontSizeSm
            renderType: Text.NativeRendering
        }

        Rectangle {
            visible: !root.dndEnabled && root.unreadCount > 0
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            radius: 3
            antialiasing: true
            color: root.theme.accent
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.calendarMenuRequested();
            else if (mouse.button === Qt.MiddleButton)
                root.notificationsMenuRequested();
            else
                root.themeMenuRequested();
        }
    }
}
