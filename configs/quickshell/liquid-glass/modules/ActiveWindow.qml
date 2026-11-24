import QtQuick
import Quickshell.Wayland
import "../components"

// Focused window title (borderless, lives inside the Left Liquid Glass island).
Item {
    id: root
    required property var theme
    property int maxWidth: 260
    property bool active: true

    readonly property var toplevel: ToplevelManager.activeToplevel
    readonly property string titleText: {
        if (!toplevel)
            return "";
        return toplevel.title || toplevel.appId || "";
    }
    readonly property bool hasWindow: titleText.length > 0
    readonly property bool shown: hasWindow && maxWidth >= 48

    visible: shown
    implicitWidth: shown ? theme.evenPx(Math.min(maxWidth, Math.ceil(label.contentWidth) + 12)) : 0
    implicitHeight: theme.pillHeight

    MarqueeText {
        id: label
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            right: parent.right
            leftMargin: 6
            rightMargin: 6
        }
        text: root.titleText
        color: root.theme.textSecondary
        fontFamily: root.theme.fontUi
        fontPixelSize: root.theme.fontSizeSm
        fontWeight: Font.Medium
        active: root.active && root.shown
    }
}
