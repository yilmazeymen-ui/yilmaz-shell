import QtQuick
import Quickshell
import Quickshell.Widgets

// Bar-integrated Application Launcher list rendered directly inside leftIsland's GlassSurface.
Item {
    id: root
    required property var theme
    property bool open: false
    property bool openedByKeyboard: false
    property bool keyboardNavActive: false

    signal closeRequested()

    property string query: ""
    property int currentIndex: 0

    function isNormalName(name) {
        const s = (name || "").trim();
        if (s.length === 0)
            return false;
        if (!/^[0-9A-Za-zÇĞIİÖŞÜçğıöşü]/.test(s))
            return false;
        // Demote Latin-1/CP1251 mojibake names (e.g. Wine shortcuts) to the bottom
        if (/[×ÄÐÑØÞßà-æè-ëì-ïðñò-õøù-ûýþÿ]/.test(s))
            return false;
        return true;
    }

    // Filter & sort desktop entries reactively
    readonly property var filteredApps: {
        const q = root.query.trim().toLowerCase();
        const all = DesktopEntries.applications.values;
        const result = [];
        for (let i = 0; i < all.length; i++) {
            const app = all[i];
            if (!app || app.noDisplay)
                continue;
            if (q.length === 0) {
                result.push(app);
            } else {
                const name = (app.name || "").toLowerCase();
                const generic = (app.genericName || "").toLowerCase();
                const comment = (app.comment || "").toLowerCase();
                const idStr = (app.id || "").toLowerCase();
                if (name.indexOf(q) !== -1 || generic.indexOf(q) !== -1 || comment.indexOf(q) !== -1 || idStr.indexOf(q) !== -1)
                    result.push(app);
            }
        }
        result.sort((a, b) => {
            const na = a.name || "";
            const nb = b.name || "";
            const normA = root.isNormalName(na);
            const normB = root.isNormalName(nb);
            if (normA !== normB)
                return normA ? -1 : 1;
            return na.localeCompare(nb);
        });
        return result;
    }

    function launchApp(entry) {
        if (!entry)
            return;
        entry.execute();
        root.closeRequested();
    }

    onOpenChanged: {
        if (open) {
            query = "";
            searchInput.text = "";
            currentIndex = 0;
            keyboardNavActive = openedByKeyboard;
            appList.positionViewAtBeginning();
            focusTimer.restart();
        } else {
            keyboardNavActive = false;
        }
    }

    onFilteredAppsChanged: {
        if (currentIndex >= filteredApps.length)
            currentIndex = Math.max(0, filteredApps.length - 1);
    }

    Timer {
        id: focusTimer
        interval: 20
        onTriggered: {
            if (root.open)
                searchInput.forceActiveFocus();
        }
    }

    // ------------------------------------------------------------------
    // Search Header
    // ------------------------------------------------------------------
    Rectangle {
        id: searchBox
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 34
        radius: root.theme.pillRadius
        antialiasing: true
        color: root.theme.glassPill

        Row {
            anchors {
                fill: parent
                leftMargin: 12
                rightMargin: 10
            }
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍉"
                color: searchInput.activeFocus ? root.theme.accent : root.theme.textSecondary
                font.family: root.theme.fontUi
                font.pixelSize: root.theme.fontSizeLg
                renderType: Text.NativeRendering
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 24 - (clearBtn.visible ? 22 : 0)
                height: parent.height

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Uygulama ara..."
                    color: root.theme.textMuted
                    font.family: root.theme.fontUi
                    font.pixelSize: root.theme.fontSizeMd
                    renderType: Text.NativeRendering
                    visible: searchInput.text.length === 0
                }

                TextInput {
                    id: searchInput
                    anchors {
                        fill: parent
                        verticalCenter: parent.verticalCenter
                    }
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.theme.textPrimary
                    selectionColor: root.theme.glassPillActive
                    selectedTextColor: root.theme.textPrimary
                    font.family: root.theme.fontUi
                    font.pixelSize: root.theme.fontSizeMd
                    renderType: Text.NativeRendering
                    clip: true

                    onTextChanged: {
                        root.query = text;
                        root.currentIndex = 0;
                        if (text.length > 0)
                            root.keyboardNavActive = true;
                        appList.positionViewAtBeginning();
                    }

                    Keys.onEscapePressed: event => {
                        event.accepted = true;
                        root.closeRequested();
                    }

                    Keys.onUpPressed: event => {
                        event.accepted = true;
                        root.keyboardNavActive = true;
                        if (root.filteredApps.length > 0) {
                            root.currentIndex = Math.max(0, root.currentIndex - 1);
                            appList.positionViewAtIndex(root.currentIndex, ListView.Contain);
                        }
                    }

                    Keys.onDownPressed: event => {
                        event.accepted = true;
                        root.keyboardNavActive = true;
                        if (root.filteredApps.length > 0) {
                            root.currentIndex = Math.min(root.filteredApps.length - 1, root.currentIndex + 1);
                            appList.positionViewAtIndex(root.currentIndex, ListView.Contain);
                        }
                    }

                    Keys.onReturnPressed: event => {
                        event.accepted = true;
                        if (root.filteredApps.length > 0 && root.currentIndex >= 0 && root.currentIndex < root.filteredApps.length)
                            root.launchApp(root.filteredApps[root.currentIndex]);
                    }

                    Keys.onEnterPressed: event => {
                        event.accepted = true;
                        if (root.filteredApps.length > 0 && root.currentIndex >= 0 && root.currentIndex < root.filteredApps.length)
                            root.launchApp(root.filteredApps[root.currentIndex]);
                    }
                }
            }

            Text {
                id: clearBtn
                visible: searchInput.text.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: "󰅖"
                color: clearMouse.containsMouse ? root.theme.textPrimary : root.theme.textSecondary
                font.family: root.theme.fontUi
                font.pixelSize: root.theme.fontSizeSm
                renderType: Text.NativeRendering

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        searchInput.text = "";
                        searchInput.forceActiveFocus();
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Application List
    // ------------------------------------------------------------------
    ListView {
        id: appList
        anchors {
            top: searchBox.bottom
            topMargin: 8
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: root.filteredApps

        delegate: Item {
            id: rowItem
            required property var modelData
            required property int index

            readonly property bool isSelected: root.keyboardNavActive && index === root.currentIndex
            readonly property string subtitle: modelData.genericName || modelData.comment || ""

            width: appList.width
            height: 40

            Rectangle {
                anchors.fill: parent
                radius: root.theme.pillRadius
                antialiasing: true
                color: {
                    if (rowItem.isSelected)
                        return root.theme.glassPillActive;
                    if (rowMouse.containsMouse)
                        return root.theme.glassPillHover;
                    return "transparent";
                }

                Behavior on color {
                    ColorAnimation {
                        duration: root.theme.animFast
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Row {
                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                }
                spacing: 10

                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    source: Quickshell.iconPath(rowItem.modelData.icon, "application-x-executable")
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 34
                    spacing: 1

                    Text {
                        width: parent.width
                        text: rowItem.modelData.name || rowItem.modelData.id
                        color: root.theme.textPrimary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeMd
                        font.weight: rowItem.isSelected ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        visible: rowItem.subtitle.length > 0
                        width: parent.width
                        text: rowItem.subtitle
                        color: root.theme.textSecondary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeSm - 1
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.currentIndex = rowItem.index
                onClicked: root.launchApp(rowItem.modelData)
            }
        }
    }

    // Empty state
    Text {
        anchors.centerIn: appList
        visible: root.filteredApps.length === 0
        text: "Sonuç bulunamadı"
        color: root.theme.textMuted
        font.family: root.theme.fontUi
        font.pixelSize: root.theme.fontSizeMd
        renderType: Text.NativeRendering
    }
}
