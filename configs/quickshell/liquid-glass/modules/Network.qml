import QtQuick
import Quickshell.Io
import "../components"

// Lightweight NetworkManager status indicator. Left-click opens NetworkMenu, right-click refreshes.
Item {
    id: root
    required property var theme
    property bool menuOpen: false
    property bool keyboardSelected: false
    property int maxTextWidth: 96
    property bool active: true

    signal clicked()

    function refresh() {
        if (!nmProc.running)
            nmProc.running = true;
    }

    property string connType: "none"   // "wifi", "ethernet", "none"
    property string connName: ""
    property bool ethConnected: false
    property string ethName: ""
    property bool wifiConnected: false
    property string wifiName: ""

    readonly property bool showWifiName: false
    readonly property int baseWidth: theme.evenPx(
        ((ethConnected || connType === "none") ? Math.ceil(ethIcon.implicitWidth) : 0)
        + (wifiConnected ? Math.ceil(wifiIcon.implicitWidth) : 0)
        + ((ethConnected && wifiConnected) ? row.spacing : 0)
        + 18
    )

    implicitWidth: theme.evenPx(row.implicitWidth + 18)
    implicitHeight: theme.pillHeight

    Process {
        id: nmProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "dev"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let hasEth = false;
                let eName = "";
                let hasWifi = false;
                let wName = "";
                const lines = this.text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split(":");
                    if (parts.length < 3)
                        continue;
                    const type = parts[0];
                    const state = parts[1];
                    const conn = parts.slice(2).join(":");
                    if (state === "connected") {
                        if (type === "ethernet" && !hasEth) {
                            hasEth = true;
                            eName = conn;
                        } else if (type === "wifi" && !hasWifi) {
                            hasWifi = true;
                            wName = conn;
                        }
                    }
                }
                root.ethConnected = hasEth;
                root.ethName = eName;
                root.wifiConnected = hasWifi;
                root.wifiName = wName;
                if (hasEth) {
                    root.connType = "ethernet";
                    root.connName = eName;
                } else if (hasWifi) {
                    root.connType = "wifi";
                    root.connName = wName;
                } else {
                    root.connType = "none";
                    root.connName = "";
                }
            }
        }
    }

    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: {
            if (!nmProc.running)
                nmProc.running = true;
        }
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
        width: Math.max(12, parent.width - 14)
        height: 2
        radius: 1
        color: root.theme.accent
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            id: ethIcon
            visible: root.ethConnected || root.connType === "none"
            anchors.verticalCenter: parent.verticalCenter
            text: root.ethConnected ? "󰈀" : "󰤭"
            color: root.connType === "none" ? root.theme.warn : root.theme.accent
            font.family: root.theme.fontMono
            font.pixelSize: root.theme.fontSizeLg
            renderType: Text.NativeRendering
        }

        Text {
            id: wifiIcon
            visible: root.wifiConnected
            anchors.verticalCenter: parent.verticalCenter
            text: "󰤨"
            color: root.theme.accent
            font.family: root.theme.fontMono
            font.pixelSize: root.theme.fontSizeLg
            renderType: Text.NativeRendering
        }

        MarqueeText {
            id: wifiLabel
            visible: root.showWifiName
            anchors.verticalCenter: parent.verticalCenter
            width: root.showWifiName ? Math.min(Math.ceil(contentWidth), root.maxTextWidth) : 0
            text: root.wifiName
            color: root.theme.textSecondary
            fontFamily: root.theme.fontUi
            fontPixelSize: root.theme.fontSizeSm
            fontWeight: Font.Medium
            active: root.active && root.showWifiName
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (!nmProc.running)
                    nmProc.running = true;
            } else {
                root.clicked();
            }
        }
    }
}
