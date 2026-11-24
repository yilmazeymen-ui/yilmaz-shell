import QtQuick
import Quickshell.Services.Mpris
import "../components"

// Compact MPRIS now-playing control (lives inside the Right Liquid Glass island).
Item {
    id: root
    required property var theme
    property int maxWidth: 200
    property bool keyboardSelected: false
    property bool active: true

    function togglePlaying() {
        if (root.player)
            root.player.togglePlaying();
    }

    function nextTrack() {
        if (root.player)
            root.player.next();
    }

    function previousTrack() {
        if (root.player)
            root.player.previous();
    }

    readonly property var player: {
        const list = Mpris.players.values;
        if (!list || list.length === 0)
            return null;
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].isPlaying)
                return list[i];
        }
        return list[0] ?? null;
    }

    readonly property bool hasPlayer: player !== null && (player.trackTitle || "") !== ""
    readonly property bool playing: player ? player.isPlaying : false
    readonly property bool shown: hasPlayer && maxWidth >= 48

    visible: shown
    implicitWidth: shown ? theme.evenPx(Math.min(maxWidth, row.implicitWidth + 20)) : 0
    implicitHeight: theme.pillHeight

    Rectangle {
        anchors.fill: parent
        radius: root.theme.pillRadius
        antialiasing: true
        color: root.keyboardSelected
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
        width: Math.max(16, parent.width - 20)
        height: 2
        radius: 1
        color: root.theme.accent
    }

    Row {
        id: row
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            right: parent.right
            leftMargin: 10
            rightMargin: 10
        }
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.playing ? "󰎈" : "󰏤"
            color: root.playing ? root.theme.accent : root.theme.textSecondary
            font.family: root.theme.fontMono
            font.pixelSize: root.theme.fontSizeMd
            renderType: Text.NativeRendering
        }

        MarqueeText {
            id: titleLabel
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(Math.ceil(contentWidth), Math.max(0, root.maxWidth - 42))
            text: root.player ? (root.player.trackTitle || "") : ""
            color: root.theme.textPrimary
            fontFamily: root.theme.fontUi
            fontPixelSize: root.theme.fontSizeSm
            fontWeight: Font.Medium
            active: root.active && root.shown
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (!root.player)
                return;
            if (mouse.button === Qt.RightButton)
                root.player.next();
            else
                root.player.togglePlaying();
        }
        onWheel: wheel => {
            if (!root.player)
                return;
            if (wheel.angleDelta.y > 0)
                root.player.previous();
            else if (wheel.angleDelta.y < 0)
                root.player.next();
        }
    }
}
