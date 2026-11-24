import QtQuick
import Quickshell
import Quickshell.Hyprland

// Keyboard-first & mouse-friendly Hyprland workspace strip.
// Displays 1..5 (plus any active/occupied workspace > 5) with crisp numbers.
Item {
    id: root
    required property var theme
    property int keyboardSelectedId: -1

    implicitWidth: row.implicitWidth
    implicitHeight: theme.pillHeight

    readonly property int activeId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    function lookup(id) {
        return Hyprland.workspaces.values.find(w => w.id === id) ?? null;
    }

    function go(id) {
        if (id < 1)
            return;
        const ws = lookup(id);
        if (ws) {
            ws.activate();
        } else {
            // Hyprland Lua config uses hl.dsp.focus
            Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ workspace = ${id} })`]);
        }
    }

    readonly property var workspaceIds: {
        const ids = [1, 2, 3, 4, 5];
        const vals = Hyprland.workspaces.values;
        for (let i = 0; i < vals.length; i++) {
            const wid = vals[i].id;
            if (wid > 5 && wid <= 10 && ids.indexOf(wid) === -1)
                ids.push(wid);
        }
        ids.sort((a, b) => a - b);
        return ids;
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0)
                root.go(Math.max(1, root.activeId - 1));
            else if (wheel.angleDelta.y < 0)
                root.go(root.activeId + 1);
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.workspaceIds

            delegate: Item {
                id: cell
                required property int modelData
                readonly property var ws: root.lookup(modelData)
                readonly property bool isActive: root.activeId === modelData
                readonly property bool isKeyboardSelected: root.keyboardSelectedId === modelData
                readonly property bool occupied: ws && ws.toplevels ? (ws.toplevels.values.length > 0) : false

                width: isActive ? 32 : 24
                height: root.theme.pillHeight

                Behavior on width {
                    NumberAnimation {
                        duration: root.theme.animNormal
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: root.theme.pillRadius
                    antialiasing: true
                    color: {
                        if (cell.isKeyboardSelected)
                            return root.theme.glassPillActive;
                        if (cell.isActive)
                            return Qt.rgba(1, 1, 1, 0.18);
                        if (mouseArea.containsMouse)
                            return Qt.rgba(1, 1, 1, 0.09);
                        return "transparent";
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: root.theme.animFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: cell.modelData.toString()
                    color: {
                        if (cell.isKeyboardSelected)
                            return root.theme.accent;
                        if (cell.isActive)
                            return root.theme.textPrimary;
                        if (cell.occupied)
                            return root.theme.textSecondary;
                        return root.theme.textMuted;
                    }
                    font.family: root.theme.fontMono
                    font.pixelSize: root.theme.fontSizeSm
                    font.weight: (cell.isActive || cell.isKeyboardSelected) ? Font.DemiBold : Font.Medium
                    renderType: Text.NativeRendering

                    Behavior on color {
                        ColorAnimation {
                            duration: root.theme.animFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                // Keyboard focus bar or subtle occupied indicator
                Rectangle {
                    visible: cell.isKeyboardSelected || (!cell.isActive && cell.occupied)
                    anchors {
                        bottom: parent.bottom
                        bottomMargin: 2
                        horizontalCenter: parent.horizontalCenter
                    }
                    width: cell.isKeyboardSelected ? Math.max(12, parent.width - 10) : 8
                    height: 2
                    radius: 1
                    color: root.theme.accent
                    opacity: cell.isKeyboardSelected ? 1.0 : 0.85

                    Behavior on width {
                        NumberAnimation {
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
                    onClicked: root.go(cell.modelData)
                }
            }
        }
    }
}
