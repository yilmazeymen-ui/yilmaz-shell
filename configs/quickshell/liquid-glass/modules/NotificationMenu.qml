import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Bar-integrated Notification Center rendered inside centerIsland's GlassSurface.
Item {
    id: root
    required property var theme
    property bool open: false
    property bool openedByKeyboard: false
    property var notifications: []
    property bool dndEnabled: false

    signal closeRequested()
    signal dismissRequested(int uid)
    signal clearAllRequested()
    signal toggleDndRequested()

    property int currentIndex: 0
    property bool keyboardNavActive: false
    property double nowMs: Date.now()

    function formatRelativeTime(ts) {
        const diffSec = Math.max(0, Math.floor((root.nowMs - ts) / 1000));
        if (diffSec < 60)
            return "şimdi";
        const diffMin = Math.floor(diffSec / 60);
        if (diffMin < 60)
            return diffMin + " dk";
        const diffHr = Math.floor(diffMin / 60);
        if (diffHr < 24)
            return diffHr + " sa";
        const diffDay = Math.floor(diffHr / 24);
        return diffDay + " gün";
    }

    function resolveIconSource(item) {
        if (!item)
            return "";
        if (item.image && item.image.length > 0) {
            if (item.image.startsWith("/") || item.image.startsWith("file://") || item.image.startsWith("image://"))
                return item.image.startsWith("/") ? ("file://" + item.image) : item.image;
        }
        if (item.appIcon && item.appIcon.length > 0) {
            if (item.appIcon.startsWith("/"))
                return "file://" + item.appIcon;
            return Quickshell.iconPath(item.appIcon, true);
        }
        return "";
    }

    function moveSelection(delta) {
        const len = root.notifications.length;
        if (len === 0)
            return;
        root.keyboardNavActive = true;
        root.currentIndex = Math.max(0, Math.min(len - 1, root.currentIndex + delta));
        notifList.positionViewAtIndex(root.currentIndex, ListView.Contain);
    }

    function invokeSelectedAction() {
        if (root.currentIndex < 0 || root.currentIndex >= root.notifications.length)
            return;
        const item = root.notifications[root.currentIndex];
        if (item && item.actions && item.actions.length > 0) {
            try {
                item.actions[0].invoke();
            } catch (e) {}
            root.closeRequested();
        }
    }

    function dismissSelected() {
        if (root.currentIndex < 0 || root.currentIndex >= root.notifications.length)
            return;
        const item = root.notifications[root.currentIndex];
        if (item)
            root.dismissRequested(item.uid);
    }

    onNotificationsChanged: {
        if (notifications.length === 0)
            currentIndex = 0;
        else if (currentIndex >= notifications.length)
            currentIndex = notifications.length - 1;
    }

    onOpenChanged: {
        if (open) {
            nowMs = Date.now();
            keyboardNavActive = openedByKeyboard;
            currentIndex = 0;
            focusTimer.restart();
        } else {
            keyboardNavActive = false;
        }
    }

    Timer {
        interval: 30000
        running: root.open
        repeat: true
        onTriggered: root.nowMs = Date.now()
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
            if (event.key === Qt.Key_Escape) {
                root.closeRequested();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                root.moveSelection(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                root.moveSelection(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.invokeSelectedAction();
                event.accepted = true;
            } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                root.dismissSelected();
                event.accepted = true;
            } else if (event.key === Qt.Key_D) {
                root.toggleDndRequested();
                event.accepted = true;
            } else if (event.key === Qt.Key_C && root.notifications.length > 0) {
                root.clearAllRequested();
                event.accepted = true;
            }
        }
    }

    // Header bar
    Item {
        id: headerBar
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 30

        Row {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰂚"
                color: root.dndEnabled ? root.theme.warn : root.theme.accent
                font.family: root.theme.fontUi
                font.pixelSize: root.theme.fontSizeLg
                renderType: Text.NativeRendering
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Bildirimler"
                color: root.theme.textPrimary
                font.family: root.theme.fontUi
                font.pixelSize: root.theme.fontSizeLg
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }

            Rectangle {
                visible: root.notifications.length > 0
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(20, countText.implicitWidth + 12)
                height: 18
                radius: 9
                antialiasing: true
                color: root.theme.glassPill

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: String(root.notifications.length)
                    color: root.theme.textSecondary
                    font.family: root.theme.fontMono
                    font.pixelSize: 11
                    font.features: { "tnum": 1 }
                    renderType: Text.NativeRendering
                }
            }
        }

        Row {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: 6

            // DND toggle pill
            Item {
                width: dndRow.implicitWidth + 16
                height: 26

                Rectangle {
                    anchors.fill: parent
                    radius: 13
                    antialiasing: true
                    color: root.dndEnabled
                        ? Qt.rgba(root.theme.warn.r, root.theme.warn.g, root.theme.warn.b, dndMouse.containsMouse ? 0.28 : 0.18)
                        : (dndMouse.containsMouse ? root.theme.glassPillHover : root.theme.glassPill)

                    Behavior on color {
                        ColorAnimation {
                            duration: root.theme.animFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Row {
                    id: dndRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.dndEnabled ? "󰂛" : "󰂚"
                        color: root.dndEnabled ? root.theme.warn : root.theme.textSecondary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeSm
                        renderType: Text.NativeRendering
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.dndEnabled ? "Rahatsız Etme" : "Sessiz"
                        color: root.dndEnabled ? root.theme.warn : root.theme.textSecondary
                        font.family: root.theme.fontUi
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }
                }

                MouseArea {
                    id: dndMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleDndRequested()
                }
            }

            // Clear all button
            Item {
                visible: root.notifications.length > 0
                width: clearRow.implicitWidth + 16
                height: 26

                Rectangle {
                    anchors.fill: parent
                    radius: 13
                    antialiasing: true
                    color: clearMouse.containsMouse ? root.theme.glassPillHover : root.theme.glassPill

                    Behavior on color {
                        ColorAnimation {
                            duration: root.theme.animFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Row {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰎟"
                        color: clearMouse.containsMouse ? root.theme.textPrimary : root.theme.textSecondary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeSm
                        renderType: Text.NativeRendering
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Temizle"
                        color: clearMouse.containsMouse ? root.theme.textPrimary : root.theme.textSecondary
                        font.family: root.theme.fontUi
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearAllRequested()
                }
            }
        }
    }

    Rectangle {
        id: headerDivider
        anchors {
            top: headerBar.bottom
            topMargin: 8
            left: parent.left
            right: parent.right
        }
        height: 1
        color: Qt.rgba(1, 1, 1, 0.10)
    }

    // Empty state
    Column {
        visible: root.notifications.length === 0
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 14
        spacing: 8

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.dndEnabled ? "󰂛" : "󰂚"
            color: root.dndEnabled ? root.theme.warn : root.theme.textMuted
            font.family: root.theme.fontUi
            font.pixelSize: 28
            renderType: Text.NativeRendering
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.dndEnabled ? "Rahatsız Etme modu açık" : "Bildirim yok"
            color: root.theme.textSecondary
            font.family: root.theme.fontUi
            font.pixelSize: root.theme.fontSizeMd
            font.weight: Font.Medium
            renderType: Text.NativeRendering
        }
    }

    // Notification list
    ListView {
        id: notifList
        visible: root.notifications.length > 0
        anchors {
            top: headerDivider.bottom
            topMargin: 8
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        clip: true
        spacing: 6
        model: root.notifications
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: card
            required property var modelData
            required property int index

            readonly property bool isSelected: root.keyboardNavActive && root.currentIndex === index
            readonly property bool isCritical: modelData.urgency === NotificationUrgency.Critical
            readonly property string iconSrc: root.resolveIconSource(modelData)

            width: notifList.width
            height: cardCol.implicitHeight + 18

            Rectangle {
                anchors.fill: parent
                radius: 12
                antialiasing: true
                color: card.isSelected
                    ? root.theme.glassPillActive
                    : (cardMouse.containsMouse ? root.theme.glassPillHover : root.theme.glassPill)

                Behavior on color {
                    ColorAnimation {
                        duration: root.theme.animFast
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // Critical urgency accent bar
            Rectangle {
                visible: card.isCritical
                anchors {
                    left: parent.left
                    leftMargin: 4
                    top: parent.top
                    topMargin: 8
                    bottom: parent.bottom
                    bottomMargin: 8
                }
                width: 3
                radius: 1.5
                color: root.theme.warn
            }

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                    root.keyboardNavActive = false;
                    root.currentIndex = card.index;
                }
            }

            Column {
                id: cardCol
                anchors {
                    left: parent.left
                    leftMargin: card.isCritical ? 14 : 12
                    right: parent.right
                    rightMargin: 10
                    top: parent.top
                    topMargin: 9
                }
                spacing: 4

                // App name + time + dismiss
                Item {
                    width: parent.width
                    height: 18

                    Row {
                        anchors {
                            left: parent.left
                            right: metaRight.left
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 6

                        Image {
                            visible: card.iconSrc.length > 0 && status === Image.Ready
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            height: 14
                            source: card.iconSrc
                            sourceSize: Qt.size(28, 28)
                            smooth: true
                            asynchronous: true
                        }

                        Text {
                            visible: card.iconSrc.length === 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.isCritical ? "󰀨" : "󰂚"
                            color: card.isCritical ? root.theme.warn : root.theme.accent
                            font.family: root.theme.fontUi
                            font.pixelSize: 12
                            renderType: Text.NativeRendering
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, parent.width - 22)
                            text: card.modelData.appName || "Bildirim"
                            elide: Text.ElideRight
                            color: root.theme.textSecondary
                            font.family: root.theme.fontUi
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                        }
                    }

                    Row {
                        id: metaRight
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.formatRelativeTime(card.modelData.timestamp)
                            color: root.theme.textMuted
                            font.family: root.theme.fontUi
                            font.pixelSize: 11
                            renderType: Text.NativeRendering
                        }

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18

                            Rectangle {
                                anchors.fill: parent
                                radius: 9
                                antialiasing: true
                                color: dismissMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: dismissMouse.containsMouse ? root.theme.textPrimary : root.theme.textSecondary
                                font.family: root.theme.fontUi
                                font.pixelSize: 13
                                renderType: Text.NativeRendering
                            }

                            MouseArea {
                                id: dismissMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.dismissRequested(card.modelData.uid)
                            }
                        }
                    }
                }

                // Summary
                Text {
                    visible: text.length > 0
                    width: parent.width
                    text: card.modelData.summary || ""
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: root.theme.textPrimary
                    font.family: root.theme.fontUi
                    font.pixelSize: root.theme.fontSizeMd
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }

                // Body
                Text {
                    visible: text.length > 0
                    width: parent.width
                    text: card.modelData.body || ""
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    color: root.theme.textSecondary
                    font.family: root.theme.fontUi
                    font.pixelSize: root.theme.fontSizeSm
                    renderType: Text.NativeRendering
                }

                // Actions
                Flow {
                    visible: card.modelData.actions && card.modelData.actions.length > 0
                    width: parent.width
                    spacing: 6
                    topPadding: 2

                    Repeater {
                        model: card.modelData.actions || []

                        delegate: Item {
                            required property var modelData
                            width: actionLabel.implicitWidth + 16
                            height: 22

                            Rectangle {
                                anchors.fill: parent
                                radius: 11
                                antialiasing: true
                                color: actionMouse.containsMouse ? root.theme.glassPillActive : Qt.rgba(1, 1, 1, 0.08)

                                Behavior on color {
                                    ColorAnimation {
                                        duration: root.theme.animFast
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            Text {
                                id: actionLabel
                                anchors.centerIn: parent
                                text: modelData.text || "Aç"
                                color: actionMouse.containsMouse ? root.theme.accent : root.theme.textPrimary
                                font.family: root.theme.fontUi
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                renderType: Text.NativeRendering
                            }

                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    try {
                                        modelData.invoke();
                                    } catch (e) {}
                                    root.closeRequested();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
