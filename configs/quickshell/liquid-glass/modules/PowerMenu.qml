import QtQuick
import Quickshell

// Bar-integrated horizontal icon-only Power Menu rendered inside rightIsland.
Item {
    id: root
    required property var theme
    property bool open: false
    property bool openedByKeyboard: false
    property bool keyboardNavActive: false

    signal closeRequested()

    property int selectedIndex: 4
    property string pendingConfirmId: ""

    implicitWidth: row.implicitWidth
    implicitHeight: theme.pillHeight

    readonly property var actions: [
        {
            id: "lock",
            icon: "󰌾",
            destructive: false,
            needsConfirm: false,
            command: ["quickshell", "-c", "liquid-glass", "ipc", "call", "lock", "lock"]
        },
        {
            id: "suspend",
            icon: "󰤄",
            destructive: false,
            needsConfirm: false,
            command: ["systemctl", "suspend"]
        },
        {
            id: "logout",
            icon: "󰍃",
            destructive: true,
            needsConfirm: true,
            command: ["hyprctl", "dispatch", "exit"]
        },
        {
            id: "reboot",
            icon: "󰜉",
            destructive: true,
            needsConfirm: true,
            command: ["systemctl", "reboot"]
        },
        {
            id: "poweroff",
            icon: "󰐥",
            destructive: true,
            needsConfirm: true,
            command: ["systemctl", "poweroff"]
        }
    ]

    function triggerAction(act) {
        if (!act)
            return;
        if (act.needsConfirm && root.pendingConfirmId !== act.id) {
            root.pendingConfirmId = act.id;
            confirmResetTimer.restart();
            return;
        }
        root.pendingConfirmId = "";
        confirmResetTimer.stop();
        root.closeRequested();
        Quickshell.execDetached(act.command);
    }

    onOpenChanged: {
        if (open) {
            selectedIndex = root.actions.length - 1;
            keyboardNavActive = openedByKeyboard;
            pendingConfirmId = "";
            confirmResetTimer.stop();
            focusTimer.restart();
        } else {
            keyboardNavActive = false;
            pendingConfirmId = "";
            confirmResetTimer.stop();
        }
    }

    Timer {
        id: confirmResetTimer
        interval: 4000
        onTriggered: root.pendingConfirmId = ""
    }

    Timer {
        id: focusTimer
        interval: 20
        onTriggered: {
            if (root.open)
                keyScope.forceActiveFocus();
        }
    }

    Item {
        id: keyScope
        focus: root.open

        Keys.onPressed: event => {
            if (!root.open)
                return;
            if (event.key === Qt.Key_Left) {
                root.keyboardNavActive = true;
                root.selectedIndex = (root.selectedIndex - 1 + root.actions.length) % root.actions.length;
                root.pendingConfirmId = "";
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.keyboardNavActive = true;
                root.selectedIndex = (root.selectedIndex + 1) % root.actions.length;
                root.pendingConfirmId = "";
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.keyboardNavActive)
                    root.triggerAction(root.actions[root.selectedIndex]);
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                if (root.pendingConfirmId !== "") {
                    root.pendingConfirmId = "";
                } else {
                    root.closeRequested();
                }
                event.accepted = true;
            }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.actions

            delegate: Item {
                id: actionPill
                required property var modelData
                required property int index

                readonly property bool isConfirming: root.pendingConfirmId === modelData.id
                readonly property bool isHighlighted: pillMouse.containsMouse || (root.keyboardNavActive && root.selectedIndex === index)

                width: 32
                height: root.theme.pillHeight

                Rectangle {
                    anchors.fill: parent
                    radius: root.theme.pillRadius
                    antialiasing: true
                    color: actionPill.isConfirming
                        ? root.theme.tint(root.theme.warn, 0.28)
                        : (actionPill.isHighlighted ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))

                    Behavior on color {
                        ColorAnimation {
                            duration: root.theme.animFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: actionPill.modelData.icon
                    color: actionPill.isConfirming
                        ? root.theme.warn
                        : (actionPill.modelData.destructive
                            ? (actionPill.isHighlighted ? root.theme.warn : root.theme.textPrimary)
                            : (actionPill.isHighlighted ? root.theme.accent : root.theme.textPrimary))
                    font.family: root.theme.fontMono
                    font.pixelSize: 17
                    renderType: Text.NativeRendering

                    Behavior on color {
                        ColorAnimation {
                            duration: root.theme.animFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                MouseArea {
                    id: pillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = actionPill.index
                    onClicked: root.triggerAction(actionPill.modelData)
                }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 14
            color: Qt.rgba(1, 1, 1, 0.14)
        }

        Item {
            width: 30
            height: root.theme.pillHeight

            Rectangle {
                anchors.fill: parent
                radius: root.theme.pillRadius
                antialiasing: true
                color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: root.theme.animFast
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: "󰅖"
                color: closeMouse.containsMouse ? root.theme.textPrimary : root.theme.textSecondary
                font.family: root.theme.fontMono
                font.pixelSize: 15
                renderType: Text.NativeRendering
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }
        }
    }
}
