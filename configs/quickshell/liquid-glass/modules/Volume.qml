import QtQuick
import Quickshell.Services.Pipewire

// PipeWire volume indicator. Scroll to adjust ±5%, left-click to open AudioMenu, right-click to mute.
Item {
    id: root
    required property var theme
    property bool menuOpen: false
    property bool keyboardSelected: false

    signal clicked()

    implicitWidth: theme.evenPx(row.implicitWidth + 18)
    implicitHeight: theme.pillHeight

    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    readonly property real level: {
        const s = Pipewire.defaultAudioSink;
        if (!s || !s.audio || isNaN(s.audio.volume))
            return 0;
        return Math.max(0, Math.min(1, s.audio.volume));
    }

    readonly property bool muted: {
        const s = Pipewire.defaultAudioSink;
        return s && s.audio ? s.audio.muted : false;
    }

    function setVolume(v) {
        const s = Pipewire.defaultAudioSink;
        if (!s || !s.audio)
            return;
        s.audio.volume = Math.max(0, Math.min(1, v));
        if (s.audio.muted)
            s.audio.muted = false;
    }

    function toggleMute() {
        const s = Pipewire.defaultAudioSink;
        if (!s || !s.audio)
            return;
        s.audio.muted = !s.audio.muted;
    }

    function icon() {
        if (muted || level <= 0.001)
            return "";
        if (level < 0.5)
            return "";
        return "";
    }

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
        width: Math.max(16, parent.width - 16)
        height: 2
        radius: 1
        color: root.theme.accent
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon()
            color: root.muted ? root.theme.warn : root.theme.accent
            font.family: root.theme.fontMono
            font.pixelSize: root.theme.fontSizeMd
            renderType: Text.NativeRendering
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: `${Math.round(root.level * 100)}%`
            color: root.muted ? root.theme.textMuted : root.theme.textPrimary
            font.family: root.theme.fontMono
            font.pixelSize: root.theme.fontSizeSm
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.toggleMute();
            else
                root.clicked();
        }
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0)
                root.setVolume(root.level + 0.05);
            else if (wheel.angleDelta.y < 0)
                root.setVolume(root.level - 0.05);
        }
    }
}
