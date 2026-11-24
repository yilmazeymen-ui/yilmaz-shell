import QtQuick

// Smooth, continuous-loop marquee text that only animates when active (e.g. hovered) and overflowing.
Item {
    id: root

    property string text: ""
    property color color: "#ECF3F6"
    property string fontFamily: "Hurmit Nerd Font"
    property int fontPixelSize: 12
    property int fontWeight: Font.Medium
    property int gap: 36
    property real speed: 38
    property int pauseMs: 350
    property bool active: false

    readonly property real contentWidth: metrics.advanceWidth
    readonly property bool overflowing: width > 0 && contentWidth > width + 1
    readonly property bool shouldRun: active && visible && overflowing
    readonly property real loopDistance: contentWidth + gap
    readonly property int scrollDuration: Math.max(400, Math.round((loopDistance / Math.max(10, speed)) * 1000))

    property real scrollX: 0

    implicitWidth: Math.ceil(contentWidth)
    implicitHeight: Math.ceil(primaryText.implicitHeight)
    clip: true

    function syncAnimation() {
        marqueeAnim.stop();
        scrollX = 0;
        if (root.shouldRun)
            marqueeAnim.start();
    }

    onTextChanged: Qt.callLater(syncAnimation)
    onShouldRunChanged: syncAnimation()
    Component.onCompleted: syncAnimation()

    TextMetrics {
        id: metrics
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: root.fontWeight
        text: root.text
    }

    Text {
        id: primaryText
        x: root.shouldRun ? -root.scrollX : 0
        width: root.shouldRun ? Math.ceil(root.contentWidth) : root.width
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        elide: root.shouldRun ? Text.ElideNone : Text.ElideRight
        maximumLineCount: 1
        color: root.color
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: root.fontWeight
        renderType: Text.NativeRendering
    }

    Text {
        id: secondaryText
        visible: root.shouldRun
        x: root.loopDistance - root.scrollX
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.color
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: root.fontWeight
        renderType: Text.NativeRendering
    }

    SequentialAnimation {
        id: marqueeAnim
        loops: Animation.Infinite

        PropertyAction {
            target: root
            property: "scrollX"
            value: 0
        }
        PauseAnimation {
            duration: root.pauseMs
        }
        NumberAnimation {
            target: root
            property: "scrollX"
            from: 0
            to: root.loopDistance
            duration: root.scrollDuration
            easing.type: Easing.Linear
        }
    }
}
