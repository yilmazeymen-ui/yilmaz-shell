import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// Bar-integrated Background Applications (System Tray) menu rendered inside rightIsland's GlassSurface.
// Supports listing background apps, stopping them (SIGTERM), and browsing each app's DBusMenu
// using QsMenuOpener with full Liquid Glass theming.
Item {
    id: root
    required property var theme
    required property var anchorWindow
    property bool open: false
    property bool openedByKeyboard: false
    property bool keyboardNavActive: false

    signal closeRequested()

    property int currentIndex: 0
    property int menuEntryIndex: 0
    property var pidById: ({})
    property var pidByTitle: ({})

    // In-panel DBusMenu navigation stack: [{ title, icon, handle }]
    property var menuStack: []
    readonly property bool inAppMenu: menuStack.length > 0
    readonly property var currentMenuFrame: inAppMenu ? menuStack[menuStack.length - 1] : null

    readonly property int itemCount: SystemTray.items.values.length

    QsMenuOpener {
        id: menuOpener
        menu: root.currentMenuFrame ? root.currentMenuFrame.handle : null
    }

    function displayName(item) {
        if (!item)
            return "";
        return (item.title || item.tooltipTitle || item.id || "Uygulama").replace(/[\r\n]+/g, " ").trim();
    }

    function resolvePid(item) {
        if (!item)
            return 0;
        if (item.id && root.pidById[item.id] > 0)
            return root.pidById[item.id];
        if (item.title && root.pidByTitle[item.title] > 0)
            return root.pidByTitle[item.title];
        return 0;
    }

    function openAppMenu(item) {
        if (!item)
            return;
        if (item.hasMenu && item.menu) {
            root.menuStack = [{
                title: root.displayName(item),
                icon: item.icon,
                handle: item.menu
            }];
            root.menuEntryIndex = 0;
            appMenuList.positionViewAtBeginning();
        } else {
            item.activate();
        }
    }

    function pushSubmenu(entry) {
        if (!entry || !entry.hasChildren)
            return;
        const next = root.menuStack.slice();
        next.push({
            title: (entry.text || "Alt Menü").replace(/&/g, ""),
            icon: entry.icon || (root.currentMenuFrame ? root.currentMenuFrame.icon : ""),
            handle: entry
        });
        root.menuStack = next;
        root.menuEntryIndex = 0;
        appMenuList.positionViewAtBeginning();
    }

    function popMenu() {
        if (root.menuStack.length <= 1) {
            root.menuStack = [];
            return;
        }
        const next = root.menuStack.slice(0, root.menuStack.length - 1);
        root.menuStack = next;
        root.menuEntryIndex = 0;
        appMenuList.positionViewAtBeginning();
    }

    function triggerMenuEntry(entry) {
        if (!entry || entry.isSeparator || !entry.enabled)
            return;
        if (entry.hasChildren) {
            root.pushSubmenu(entry);
            return;
        }
        entry.triggered();
        root.menuStack = [];
        root.closeRequested();
    }

    function stopApp(pid) {
        if (!pid || pid <= 0)
            return;
        Quickshell.execDetached(["kill", "-TERM", String(pid)]);
        refreshDelayTimer.restart();
    }

    function refreshPids() {
        if (!pidProc.running)
            pidProc.running = true;
    }

    onOpenChanged: {
        if (open) {
            menuStack = [];
            currentIndex = 0;
            menuEntryIndex = 0;
            keyboardNavActive = openedByKeyboard;
            trayList.positionViewAtBeginning();
            refreshPids();
            focusTimer.restart();
        } else {
            keyboardNavActive = false;
            menuStack = [];
        }
    }

    onItemCountChanged: {
        if (currentIndex >= itemCount)
            currentIndex = Math.max(0, itemCount - 1);
        if (open)
            refreshDelayTimer.restart();
    }

    Timer {
        id: refreshDelayTimer
        interval: 300
        onTriggered: {
            if (root.open)
                root.refreshPids();
        }
    }

    Timer {
        id: focusTimer
        interval: 20
        onTriggered: {
            if (root.open)
                keyScope.forceActiveFocus();
        }
    }

    Process {
        id: pidProc
        command: [
            "python3", "-c",
            "import json, subprocess\n"
            + "def busctl(args):\n"
            + "    p = subprocess.run(['busctl', '--user', '--json=short'] + args, capture_output=True, text=True, timeout=2)\n"
            + "    return json.loads(p.stdout) if p.returncode == 0 else None\n"
            + "res = busctl(['get-property', 'org.kde.StatusNotifierWatcher', '/StatusNotifierWatcher', 'org.kde.StatusNotifierWatcher', 'RegisteredStatusNotifierItems'])\n"
            + "out = []\n"
            + "for entry in (res or {}).get('data', []):\n"
            + "    idx = entry.find('/')\n"
            + "    if idx <= 0: continue\n"
            + "    svc, path = entry[:idx], entry[idx:]\n"
            + "    pr = busctl(['call', 'org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'GetConnectionUnixProcessID', 's', svc])\n"
            + "    pid = (pr or {}).get('data', [0])[0]\n"
            + "    sid, stitle = '', ''\n"
            + "    for iface in ('org.kde.StatusNotifierItem', 'org.freedesktop.StatusNotifierItem'):\n"
            + "        if not sid:\n"
            + "            r = busctl(['get-property', svc, path, iface, 'Id'])\n"
            + "            if r and isinstance(r.get('data'), str): sid = r['data']\n"
            + "        if not stitle:\n"
            + "            r = busctl(['get-property', svc, path, iface, 'Title'])\n"
            + "            if r and isinstance(r.get('data'), str): stitle = r['data']\n"
            + "    out.append({'pid': pid, 'id': sid, 'title': stitle})\n"
            + "print(json.dumps(out, ensure_ascii=False))\n"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim();
                if (!raw)
                    return;
                try {
                    const arr = JSON.parse(raw);
                    const byId = {};
                    const byTitle = {};
                    for (let i = 0; i < arr.length; i++) {
                        const row = arr[i];
                        if (row.pid > 0) {
                            if (row.id)
                                byId[row.id] = row.pid;
                            if (row.title)
                                byTitle[row.title] = row.pid;
                        }
                    }
                    root.pidById = byId;
                    root.pidByTitle = byTitle;
                } catch (e) {
                }
            }
        }
    }

    Item {
        id: keyScope
        focus: root.open

        Keys.onPressed: event => {
            if (!root.open)
                return;

            if (event.key === Qt.Key_Escape) {
                if (root.inAppMenu)
                    root.popMenu();
                else
                    root.closeRequested();
                event.accepted = true;
                return;
            }

            if (root.inAppMenu) {
                const cnt = menuOpener.children.values.length;
                if (event.key === Qt.Key_Left || event.key === Qt.Key_Backspace) {
                    root.popMenu();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    if (cnt > 0) {
                        root.keyboardNavActive = true;
                        root.menuEntryIndex = (root.menuEntryIndex - 1 + cnt) % cnt;
                        appMenuList.positionViewAtIndex(root.menuEntryIndex, ListView.Contain);
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    if (cnt > 0) {
                        root.keyboardNavActive = true;
                        root.menuEntryIndex = (root.menuEntryIndex + 1) % cnt;
                        appMenuList.positionViewAtIndex(root.menuEntryIndex, ListView.Contain);
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Right) {
                    if (cnt > 0 && root.menuEntryIndex >= 0 && root.menuEntryIndex < cnt)
                        root.triggerMenuEntry(menuOpener.children.values[root.menuEntryIndex]);
                    event.accepted = true;
                }
                return;
            }

            if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                if (root.itemCount > 0) {
                    root.keyboardNavActive = true;
                    root.currentIndex = (root.currentIndex - 1 + root.itemCount) % root.itemCount;
                    trayList.positionViewAtIndex(root.currentIndex, ListView.Contain);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                if (root.itemCount > 0) {
                    root.keyboardNavActive = true;
                    root.currentIndex = (root.currentIndex + 1) % root.itemCount;
                    trayList.positionViewAtIndex(root.currentIndex, ListView.Contain);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Right) {
                if (root.itemCount > 0) {
                    const item = SystemTray.items.values[root.currentIndex];
                    if (item)
                        root.openAppMenu(item);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_X) {
                if (root.itemCount > 0) {
                    const item = SystemTray.items.values[root.currentIndex];
                    const pid = root.resolvePid(item);
                    if (pid > 0)
                        root.stopApp(pid);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                root.refreshPids();
                event.accepted = true;
            }
        }
    }

    // ------------------------------------------------------------------
    // Header (switches between App List header and App Menu breadcrumb)
    // ------------------------------------------------------------------
    Item {
        id: headerBox
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 34

        Rectangle {
            anchors.fill: parent
            radius: root.theme.pillRadius
            antialiasing: true
            color: root.theme.glassPill
        }

        // App List Header
        Row {
            visible: !root.inAppMenu
            anchors {
                left: parent.left
                leftMargin: 12
                verticalCenter: parent.verticalCenter
            }
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰀻"
                color: root.theme.accent
                font.family: root.theme.fontMono
                font.pixelSize: root.theme.fontSizeMd
                renderType: Text.NativeRendering
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Arka Plan Uygulamaları"
                color: root.theme.textPrimary
                font.family: root.theme.fontUi
                font.pixelSize: root.theme.fontSizeMd
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(20, countText.implicitWidth + 10)
                height: 18
                radius: 9
                antialiasing: true
                color: root.theme.glassPillActive

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: String(root.itemCount)
                    color: root.theme.accent
                    font.family: root.theme.fontMono
                    font.pixelSize: 11
                    font.features: ({ "tnum": 1 })
                    renderType: Text.NativeRendering
                }
            }
        }

        // Refresh PIDs button (only on App List view)
        Item {
            id: refreshBtn
            visible: !root.inAppMenu
            anchors {
                right: parent.right
                rightMargin: 6
                verticalCenter: parent.verticalCenter
            }
            width: 24
            height: 24

            Rectangle {
                anchors.fill: parent
                radius: 8
                antialiasing: true
                color: refreshMouse.containsMouse ? root.theme.glassPillHover : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: root.theme.animFast
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: "󰑐"
                color: refreshMouse.containsMouse ? root.theme.accent : root.theme.textSecondary
                font.family: root.theme.fontMono
                font.pixelSize: root.theme.fontSizeMd
                renderType: Text.NativeRendering
            }

            MouseArea {
                id: refreshMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.refreshPids()
            }
        }

        // App Menu Breadcrumb Header
        Item {
            visible: root.inAppMenu
            anchors.fill: parent

            Item {
                id: backBtn
                anchors {
                    left: parent.left
                    leftMargin: 6
                    verticalCenter: parent.verticalCenter
                }
                width: 26
                height: 24

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    antialiasing: true
                    color: backMouse.containsMouse ? root.theme.glassPillHover : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: root.theme.animFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰅁"
                    color: backMouse.containsMouse ? root.theme.accent : root.theme.textPrimary
                    font.family: root.theme.fontMono
                    font.pixelSize: root.theme.fontSizeLg
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.popMenu()
                }
            }

            IconImage {
                id: menuHeaderIcon
                visible: !!(root.currentMenuFrame && root.currentMenuFrame.icon)
                anchors {
                    left: backBtn.right
                    leftMargin: 6
                    verticalCenter: parent.verticalCenter
                }
                width: 16
                height: 16
                source: root.currentMenuFrame ? root.currentMenuFrame.icon : ""
            }

            Text {
                anchors {
                    left: menuHeaderIcon.visible ? menuHeaderIcon.right : backBtn.right
                    leftMargin: 8
                    right: parent.right
                    rightMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                text: root.currentMenuFrame ? root.currentMenuFrame.title : ""
                color: root.theme.textPrimary
                font.family: root.theme.fontUi
                font.pixelSize: root.theme.fontSizeMd
                font.weight: Font.DemiBold
                maximumLineCount: 1
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
        }
    }

    // ------------------------------------------------------------------
    // View 1: Background Applications List
    // ------------------------------------------------------------------
    ListView {
        id: trayList
        visible: !root.inAppMenu
        anchors {
            top: headerBox.bottom
            topMargin: 8
            left: parent.left
            right: parent.right
            bottom: footerHint.top
            bottomMargin: 6
        }
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: SystemTray.items

        delegate: Item {
            id: rowItem
            required property SystemTrayItem modelData
            required property int index

            readonly property int appPid: root.resolvePid(modelData)
            readonly property bool isSelected: (root.keyboardNavActive && root.currentIndex === index) || rowMouse.containsMouse || stopMouse.containsMouse

            width: trayList.width
            height: 50
            clip: true

            Rectangle {
                anchors.fill: parent
                radius: root.theme.pillRadius
                antialiasing: true
                color: (root.keyboardNavActive && root.currentIndex === index)
                    ? root.theme.glassPillActive
                    : (rowItem.isSelected ? root.theme.glassPillHover : root.theme.glassPill)

                Behavior on color {
                    ColorAnimation {
                        duration: root.theme.animFast
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                id: rowMouse
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.left
                    right: stopBtn.left
                    rightMargin: 4
                }
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onEntered: {
                    if (root.keyboardNavActive)
                        root.currentIndex = rowItem.index;
                }
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton || mouse.button === Qt.RightButton) {
                        root.openAppMenu(rowItem.modelData);
                    } else if (mouse.button === Qt.MiddleButton) {
                        rowItem.modelData.secondaryActivate();
                    }
                }
            }

            Item {
                id: rowContent
                anchors {
                    left: parent.left
                    leftMargin: 10
                    right: stopBtn.left
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                height: 34

                Rectangle {
                    id: iconBadge
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    width: 30
                    height: 30
                    radius: 8
                    antialiasing: true
                    color: Qt.rgba(1, 1, 1, 0.08)

                    IconImage {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: rowItem.modelData.icon
                    }
                }

                Column {
                    anchors {
                        left: iconBadge.right
                        leftMargin: 10
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    Text {
                        width: parent.width
                        text: root.displayName(rowItem.modelData)
                        color: root.theme.textPrimary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeMd
                        font.weight: Font.DemiBold
                        maximumLineCount: 1
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        width: parent.width
                        text: {
                            const parts = [];
                            if (rowItem.appPid > 0)
                                parts.push("PID " + rowItem.appPid);
                            const desc = (rowItem.modelData.tooltipDescription || "").replace(/[\r\n]+/g, " • ").trim();
                            if (desc.length > 0)
                                parts.push(desc);
                            return parts.join(" • ");
                        }
                        visible: text.length > 0
                        color: root.theme.textSecondary
                        font.family: root.theme.fontUi
                        font.pixelSize: 11
                        font.features: ({ "tnum": 1 })
                        maximumLineCount: 1
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }
            }

            // Stop background application button
            Item {
                id: stopBtn
                anchors {
                    right: parent.right
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                width: 28
                height: 28
                enabled: rowItem.appPid > 0
                opacity: enabled ? 1.0 : 0.35

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    antialiasing: true
                    color: stopMouse.containsMouse
                        ? Qt.rgba(root.theme.warn.r, root.theme.warn.g, root.theme.warn.b, 0.22)
                        : Qt.rgba(1, 1, 1, 0.06)

                    Behavior on color {
                        ColorAnimation {
                            duration: root.theme.animFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰓛"
                    color: stopMouse.containsMouse ? root.theme.warn : root.theme.textSecondary
                    font.family: root.theme.fontMono
                    font.pixelSize: root.theme.fontSizeMd
                    renderType: Text.NativeRendering

                    Behavior on color {
                        ColorAnimation {
                            duration: root.theme.animFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                MouseArea {
                    id: stopMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: rowItem.appPid > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.stopApp(rowItem.appPid)
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.itemCount === 0
            text: "Arka planda çalışan uygulama yok"
            color: root.theme.textMuted
            font.family: root.theme.fontUi
            font.pixelSize: root.theme.fontSizeSm
            renderType: Text.NativeRendering
        }
    }

    // ------------------------------------------------------------------
    // View 2: App's Own DBusMenu rendered in Liquid Glass Theme
    // ------------------------------------------------------------------
    ListView {
        id: appMenuList
        visible: root.inAppMenu
        anchors {
            top: headerBox.bottom
            topMargin: 8
            left: parent.left
            right: parent.right
            bottom: footerHint.top
            bottomMargin: 6
        }
        clip: true
        spacing: 3
        boundsBehavior: Flickable.StopAtBounds
        model: menuOpener.children

        delegate: Item {
            id: entryItem
            required property QsMenuEntry modelData
            required property int index

            readonly property bool isSep: modelData.isSeparator
            readonly property bool isEnabled: modelData.enabled && !isSep
            readonly property bool isHighlighted: isEnabled && ((root.keyboardNavActive && root.menuEntryIndex === index) || entryMouse.containsMouse)

            width: appMenuList.width
            height: isSep ? 9 : 34
            clip: true

            // Separator line
            Rectangle {
                visible: entryItem.isSep
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 8
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                height: 1
                color: Qt.rgba(1, 1, 1, 0.12)
            }

            // Regular menu entry pill
            Rectangle {
                visible: !entryItem.isSep
                anchors.fill: parent
                radius: 10
                antialiasing: true
                color: (root.keyboardNavActive && root.menuEntryIndex === index && entryItem.isEnabled)
                    ? root.theme.glassPillActive
                    : (entryItem.isHighlighted ? root.theme.glassPillHover : root.theme.glassPill)

                Behavior on color {
                    ColorAnimation {
                        duration: root.theme.animFast
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Row {
                visible: !entryItem.isSep
                anchors {
                    left: parent.left
                    leftMargin: 10
                    right: submenuChevron.visible ? submenuChevron.left : parent.right
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                spacing: 8
                opacity: entryItem.isEnabled ? 1.0 : 0.42

                // Checkbox / Radio indicator
                Text {
                    visible: entryItem.modelData.buttonType !== QsMenuButtonType.None
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        const checked = entryItem.modelData.checkState === Qt.Checked;
                        if (entryItem.modelData.buttonType === QsMenuButtonType.RadioButton)
                            return checked ? "󰄯" : "󰄰";
                        return checked ? "󰄲" : "󰄱";
                    }
                    color: entryItem.modelData.checkState === Qt.Checked ? root.theme.accent : root.theme.textSecondary
                    font.family: root.theme.fontMono
                    font.pixelSize: root.theme.fontSizeMd
                    renderType: Text.NativeRendering
                }

                // Entry icon
                IconImage {
                    visible: !!(entryItem.modelData.icon && entryItem.modelData.icon.length > 0)
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    source: entryItem.modelData.icon
                }

                // Entry label
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - x)
                    text: (entryItem.modelData.text || "").replace(/&/g, "")
                    color: entryItem.isHighlighted ? root.theme.textPrimary : root.theme.textPrimary
                    font.family: root.theme.fontUi
                    font.pixelSize: root.theme.fontSizeSm
                    maximumLineCount: 1
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }
            }

            Text {
                id: submenuChevron
                visible: !entryItem.isSep && entryItem.modelData.hasChildren
                anchors {
                    right: parent.right
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                text: "󰅂"
                color: entryItem.isHighlighted ? root.theme.accent : root.theme.textSecondary
                font.family: root.theme.fontMono
                font.pixelSize: root.theme.fontSizeMd
                renderType: Text.NativeRendering
            }

            MouseArea {
                id: entryMouse
                visible: !entryItem.isSep
                anchors.fill: parent
                hoverEnabled: true
                enabled: entryItem.isEnabled
                cursorShape: entryItem.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onEntered: {
                    if (root.keyboardNavActive)
                        root.menuEntryIndex = entryItem.index;
                }
                onClicked: root.triggerMenuEntry(entryItem.modelData)
            }
        }
    }

    // ------------------------------------------------------------------
    // Subtle footer hint
    // ------------------------------------------------------------------
    Text {
        id: footerHint
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        horizontalAlignment: Text.AlignHCenter
        text: root.inAppMenu ? "Tıkla: Seç  •  󰅁 / Esc: Geri" : "Tıkla: Uygulama Menüsü  •  󰓛: Durdur"
        color: root.theme.textMuted
        font.family: root.theme.fontUi
        font.pixelSize: 11
        elide: Text.ElideRight
        renderType: Text.NativeRendering
    }
}
