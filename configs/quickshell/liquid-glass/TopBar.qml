import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "./components"
import "./modules"

// 3-island floating Liquid Glass Top Bar with real SDF optical refraction
// and bar-integrated morphing menus.
PanelWindow {
    id: win
    required property var modelData
    required property var theme
    property bool barVisible: true
    property string activeMenu: ""
    property bool menuOpenedByKeyboard: false
    property string focusIsland: ""
    property int focusSeq: 0
    property var notifications: []
    property int unreadCount: 0
    property bool dndEnabled: false
    property var previewNotification: null
    property bool previewActive: false

    signal requestMenuToggle(string name, bool byKeyboard)
    signal requestMenuClose()
    signal requestFocusClose()
    signal requestDismissNotification(int uid)
    signal requestClearNotifications()
    signal requestToggleDnd()
    signal requestDismissPreview()
    signal requestPreviewHovered(bool hovered)

    readonly property bool hasOpenMenu: activeMenu !== ""
    readonly property bool hasBarFocus: focusIsland !== "" && !hasOpenMenu
    readonly property bool isInteractive: hasOpenMenu || hasBarFocus
    readonly property bool isAppsOpen: activeMenu === "apps"
    readonly property bool isClipboardOpen: activeMenu === "clipboard"
    readonly property bool isThemeOpen: activeMenu === "theme"
    readonly property bool isCalendarOpen: activeMenu === "calendar"
    readonly property bool isNotificationsOpen: activeMenu === "notifications"
    readonly property bool isAudioOpen: activeMenu === "audio"
    readonly property bool isNetworkOpen: activeMenu === "network"
    readonly property bool isTrayOpen: activeMenu === "tray"
    readonly property bool isPowerOpen: activeMenu === "power"
    readonly property bool isCenterMenuOpen: isClipboardOpen || isThemeOpen || isCalendarOpen || isNotificationsOpen
    readonly property bool isPreviewOpen: !isCenterMenuOpen && previewActive && previewNotification !== null
    readonly property bool isRightMenuOpen: isAudioOpen || isNetworkOpen || isTrayOpen || isPowerOpen

    property int selectedFocusIndex: 0

    readonly property var focusItems: {
        const list = [];
        list.push({ island: "left", type: "launcher" });
        const wsIds = workspacesMod ? workspacesMod.workspaceIds : [];
        for (let i = 0; i < wsIds.length; i++)
            list.push({ island: "left", type: "ws", wsId: wsIds[i] });
        list.push({ island: "center", type: "clock" });
        if (mediaMod && mediaMod.hasPlayer)
            list.push({ island: "right", type: "media" });
        list.push({ island: "right", type: "network" });
        list.push({ island: "right", type: "volume" });
        if (trayMod && trayMod.hasItems)
            list.push({ island: "right", type: "tray" });
        list.push({ island: "right", type: "power" });
        return list;
    }

    readonly property var currentFocusItem: {
        if (!hasBarFocus || focusItems.length === 0)
            return null;
        const idx = Math.max(0, Math.min(selectedFocusIndex, focusItems.length - 1));
        return focusItems[idx];
    }

    readonly property string currentFocusIsland: currentFocusItem ? currentFocusItem.island : ""

    function selectFirstInIsland(island) {
        for (let i = 0; i < focusItems.length; i++) {
            if (focusItems[i].island === island) {
                selectedFocusIndex = i;
                return;
            }
        }
        selectedFocusIndex = 0;
    }

    function stepFocus(delta) {
        const len = focusItems.length;
        if (len === 0)
            return;
        selectedFocusIndex = (selectedFocusIndex + delta + len) % len;
    }

    function triggerFocusedItem(secondary) {
        const item = currentFocusItem;
        if (!item)
            return;
        if (item.type === "launcher") {
            win.requestMenuToggle("apps", true);
        } else if (item.type === "ws") {
            workspacesMod.go(item.wsId);
            win.requestFocusClose();
        } else if (item.type === "clock") {
            if (secondary)
                win.requestMenuToggle("calendar", true);
            else
                win.requestMenuToggle("theme", true);
        } else if (item.type === "media") {
            if (secondary)
                mediaMod.nextTrack();
            else
                mediaMod.togglePlaying();
        } else if (item.type === "network") {
            if (secondary)
                networkMod.refresh();
            else
                win.requestMenuToggle("network", true);
        } else if (item.type === "volume") {
            if (secondary)
                volumeMod.toggleMute();
            else
                win.requestMenuToggle("audio", true);
        } else if (item.type === "tray") {
            win.requestMenuToggle("tray", true);
        } else if (item.type === "power") {
            win.requestMenuToggle("power", true);
        }
    }

    function adjustFocusedItem(dir) {
        const item = currentFocusItem;
        if (!item)
            return;
        if (item.type === "volume") {
            volumeMod.setVolume(volumeMod.level + (dir > 0 ? 0.05 : -0.05));
        } else if (item.type === "media") {
            if (dir > 0)
                mediaMod.previousTrack();
            else
                mediaMod.nextTrack();
        } else if (item.type === "ws") {
            workspacesMod.go(Math.max(1, workspacesMod.activeId + (dir > 0 ? -1 : 1)));
        } else if (item.type === "clock") {
            centerClock.toggleSeconds();
        }
    }

    onFocusIslandChanged: {
        if (hasBarFocus) {
            selectFirstInIsland(focusIsland);
            barFocusTimer.restart();
        }
    }

    onFocusSeqChanged: {
        if (hasBarFocus) {
            selectFirstInIsland(focusIsland);
            barFocusTimer.restart();
        }
    }

    onFocusItemsChanged: {
        if (focusItems.length > 0 && selectedFocusIndex >= focusItems.length)
            selectedFocusIndex = focusItems.length - 1;
    }

    screen: modelData
    visible: barVisible

    WlrLayershell.namespace: "quickshell:liquid-glass"

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: theme.topMargin + 460 + 8
    exclusiveZone: barVisible ? (theme.topMargin + theme.barHeight + theme.windowGap) : 0
    color: "transparent"
    focusable: isInteractive

    mask: Region {
        item: win.isInteractive ? fullMask : barStripMask
    }

    readonly property real screenW: win.screen ? win.screen.width : 1920
    readonly property real screenH: win.screen ? win.screen.height : 1080

    readonly property int centerMenuWidth: Math.min(680, Math.floor(Math.max(360, win.width - 2 * win.theme.sideMargin) / 2) * 2)
    readonly property int maxSideIslandWidth: {
        const avail = Math.floor((win.width - centerIsland.width) / 2) - win.theme.sideMargin - win.theme.islandGap;
        return Math.max(0, Math.floor(avail / 2) * 2);
    }

    readonly property int activeWinBudget: Math.max(0, Math.floor(win.maxSideIslandWidth - (workspacesMod.implicitWidth + 76)))
    readonly property int leftClosedWidth: win.theme.evenPx(Math.min(win.maxSideIslandWidth, leftRow.implicitWidth + 16))

    readonly property int rightCoreWidth: 16
        + networkMod.baseWidth
        + 4 + volumeMod.implicitWidth
        + (trayMod.hasItems ? (9 + trayMod.implicitWidth) : 0)
        + 9 + powerMod.implicitWidth
    readonly property int rightFlexBudget: Math.max(0, Math.floor(win.maxSideIslandWidth - rightCoreWidth))
    readonly property int networkTextBudget: {
        if (!networkMod.wifiConnected || networkMod.wifiName === "")
            return 0;
        const avail = Math.max(0, win.rightFlexBudget - 5);
        return avail >= 24 ? Math.min(96, avail) : 0;
    }
    readonly property int rightNonMediaWidth: 16
        + networkMod.implicitWidth
        + 4 + volumeMod.implicitWidth
        + (trayMod.hasItems ? (9 + trayMod.implicitWidth) : 0)
        + 9 + powerMod.implicitWidth
    readonly property int mediaBudget: Math.max(0, Math.floor(win.maxSideIslandWidth - rightNonMediaWidth - 9))
    readonly property int rightClosedWidth: win.theme.evenPx(Math.min(win.maxSideIslandWidth, rightRow.implicitWidth + 16))

    Timer {
        id: barFocusTimer
        interval: 20
        onTriggered: {
            if (win.hasBarFocus)
                barKeyScope.forceActiveFocus();
        }
    }

    Item {
        id: barKeyScope
        focus: win.hasBarFocus

        Keys.onPressed: event => {
            if (!win.hasBarFocus)
                return;
            const item = win.currentFocusItem;
            const shift = (event.modifiers & Qt.ShiftModifier) !== 0;

            if (event.key === Qt.Key_Escape) {
                win.requestFocusClose();
                event.accepted = true;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Backtab) {
                win.stepFocus(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Tab) {
                win.stepFocus(shift ? -1 : 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                win.triggerFocusedItem(shift);
                event.accepted = true;
            } else if (event.key === Qt.Key_Menu) {
                win.triggerFocusedItem(true);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                win.adjustFocusedItem(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                win.adjustFocusedItem(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_M && item && item.type === "volume") {
                volumeMod.toggleMute();
                event.accepted = true;
            } else if (event.key === Qt.Key_C && item && item.type === "clock") {
                win.requestMenuToggle("clipboard", true);
                event.accepted = true;
            } else if (event.key === Qt.Key_N && item && item.type === "clock") {
                win.requestMenuToggle("notifications", true);
                event.accepted = true;
            } else if (event.key === Qt.Key_S && item && item.type === "clock") {
                centerClock.toggleSeconds();
                event.accepted = true;
            } else if (event.key === Qt.Key_R && item && item.type === "network") {
                networkMod.refresh();
                event.accepted = true;
            } else if (event.key === Qt.Key_N && item && item.type === "media") {
                mediaMod.nextTrack();
                event.accepted = true;
            } else if (event.key === Qt.Key_P && item && item.type === "media") {
                mediaMod.previousTrack();
                event.accepted = true;
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                const wsNum = event.key - Qt.Key_0;
                workspacesMod.go(wsNum);
                win.requestFocusClose();
                event.accepted = true;
            }
        }
    }

    Item {
        id: barStripMask
        x: 0
        y: 0
        width: win.width
        height: win.theme.topMargin + win.theme.barHeight
    }

    Item {
        id: fullMask
        anchors.fill: parent
    }

    HyprlandFocusGrab {
        windows: [win]
        active: win.isInteractive
        onCleared: {
            win.requestMenuClose();
            win.requestFocusClose();
        }
    }

    // Dismiss open menu or bar focus when clicking outside the islands
    MouseArea {
        visible: win.isInteractive
        anchors.fill: parent
        onClicked: {
            win.requestMenuClose();
            win.requestFocusClose();
        }
    }

    // Shared wallpaper texture baked to exact screen aspect ratio for optical refraction
    Image {
        id: wpImg
        width: win.screenW
        height: win.screenH
        source: win.theme.wallpaperUrl
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: true
        visible: false
        onStatusChanged: {
            if (status === Image.Ready)
                wpTex.scheduleUpdate();
        }
    }

    ShaderEffectSource {
        id: wpTex
        sourceItem: wpImg
        textureSize: Qt.size(win.screenW, win.screenH)
        live: false
        hideSource: true
        smooth: true
        visible: false
    }

    // ------------------------------------------------------------------
    // Left Island: Launcher + Workspaces + Active Window (morphs into AppMenu)
    // ------------------------------------------------------------------
    Item {
        id: leftIsland
        x: win.theme.sideMargin
        y: win.theme.topMargin
        width: win.leftClosedWidth
        height: win.theme.barHeight
        clip: true
        state: win.isAppsOpen ? "apps" : "closed"

        states: [
            State {
                name: "closed"
                PropertyChanges {
                    target: leftIsland
                    width: win.leftClosedWidth
                    height: win.theme.barHeight
                }
            },
            State {
                name: "apps"
                PropertyChanges {
                    target: leftIsland
                    width: 380
                    height: 460
                }
            }
        ]

        transitions: [
            Transition {
                from: "closed"
                to: "apps"
                NumberAnimation {
                    properties: "width,height"
                    duration: win.theme.animNormal
                    easing.type: Easing.OutCubic
                }
            },
            Transition {
                from: "apps"
                to: "closed"
                NumberAnimation {
                    properties: "width,height"
                    duration: win.theme.animNormal
                    easing.type: Easing.OutCubic
                }
            }
        ]

        // Absorb clicks inside the island so the backdrop MouseArea doesn't dismiss it
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        HoverHandler {
            id: leftIslandHover
        }

        GlassSurface {
            anchors.fill: parent
            theme: win.theme
            wallpaperTex: wpTex
            screenWidth: win.screenW
            screenHeight: win.screenH
            islandX: leftIsland.x
            islandY: leftIsland.y
            radius: win.theme.barRadius
            hovered: win.hasBarFocus && win.currentFocusIsland === "left"
            innerAlpha: win.isAppsOpen ? 0.32 : 0.36
            wallpaperMix: 0.0
        }

        Row {
            id: leftRow
            anchors {
                left: parent.left
                leftMargin: 8
                top: parent.top
                topMargin: Math.round((win.theme.barHeight - height) / 2)
            }
            spacing: 8
            opacity: win.isAppsOpen ? 0.0 : 1.0
            visible: opacity > 0.01
            enabled: !win.isAppsOpen

            Behavior on opacity {
                NumberAnimation {
                    duration: 70
                    easing.type: Easing.OutCubic
                }
            }

            // App Launcher button at the far left
            Item {
                id: launcherBtn
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: win.theme.pillHeight
                readonly property bool keyboardSelected: win.currentFocusItem !== null && win.currentFocusItem.type === "launcher"

                Rectangle {
                    anchors.fill: parent
                    radius: win.theme.pillRadius
                    antialiasing: true
                    color: launcherBtn.keyboardSelected
                        ? win.theme.glassPillActive
                        : (launcherMouse.containsMouse ? win.theme.glassPillHover : "transparent")

                    Behavior on color {
                        ColorAnimation {
                            duration: win.theme.animFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Rectangle {
                    visible: launcherBtn.keyboardSelected
                    anchors {
                        bottom: parent.bottom
                        bottomMargin: 2
                        horizontalCenter: parent.horizontalCenter
                    }
                    width: 14
                    height: 2
                    radius: 1
                    color: win.theme.accent
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰀻"
                    color: (launcherMouse.containsMouse || launcherBtn.keyboardSelected) ? win.theme.accent : win.theme.textPrimary
                    font.family: win.theme.fontUi
                    font.pixelSize: win.theme.fontSizeLg
                    renderType: Text.NativeRendering

                    Behavior on color {
                        ColorAnimation {
                            duration: win.theme.animFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                MouseArea {
                    id: launcherMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.requestMenuToggle("apps", false)
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 14
                color: Qt.rgba(1, 1, 1, 0.14)
            }

            Workspaces {
                id: workspacesMod
                anchors.verticalCenter: parent.verticalCenter
                theme: win.theme
                keyboardSelectedId: (win.currentFocusItem && win.currentFocusItem.type === "ws") ? win.currentFocusItem.wsId : -1
            }

            Rectangle {
                visible: activeWin.visible
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 14
                color: Qt.rgba(1, 1, 1, 0.14)
            }

            ActiveWindow {
                id: activeWin
                anchors.verticalCenter: parent.verticalCenter
                theme: win.theme
                maxWidth: win.activeWinBudget >= 48 ? Math.min(300, win.activeWinBudget) : 0
                active: win.barVisible && !win.isAppsOpen && leftIslandHover.hovered
            }
        }

        AppMenu {
            id: appMenu
            anchors {
                fill: parent
                margins: 12
            }
            theme: win.theme
            open: win.isAppsOpen
            openedByKeyboard: win.menuOpenedByKeyboard
            opacity: win.isAppsOpen ? 1.0 : 0.0
            visible: opacity > 0.01
            onCloseRequested: win.requestMenuClose()

            Behavior on opacity {
                NumberAnimation {
                    duration: win.theme.animFast
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Center Island: Clock & Date (morphs into Preview / ClipboardMenu / ThemeMenu / CalendarMenu / NotificationMenu)
    // ------------------------------------------------------------------
    Item {
        id: centerIsland
        x: Math.round((win.width - width) / 2)
        y: win.theme.topMargin
        width: win.theme.evenPx(centerClock.implicitWidth + 8)
        height: win.theme.barHeight
        clip: true
        state: win.isClipboardOpen ? "clipboard"
            : (win.isThemeOpen ? "theme"
            : (win.isCalendarOpen ? "calendar"
            : (win.isNotificationsOpen ? "notifications"
            : (win.isPreviewOpen ? "preview" : "closed"))))

        readonly property int previewClosedWidth: win.theme.evenPx(Math.min(380, Math.max(centerClock.implicitWidth + 48, previewBox.desiredWidth + 24)))

        states: [
            State {
                name: "closed"
                PropertyChanges {
                    target: centerIsland
                    width: win.theme.evenPx(centerClock.implicitWidth + 8)
                    height: win.theme.barHeight
                }
            },
            State {
                name: "preview"
                PropertyChanges {
                    target: centerIsland
                    width: centerIsland.previewClosedWidth
                    height: win.theme.barHeight
                }
            },
            State {
                name: "clipboard"
                PropertyChanges {
                    target: centerIsland
                    width: win.centerMenuWidth
                    height: 460
                }
            },
            State {
                name: "theme"
                PropertyChanges {
                    target: centerIsland
                    width: win.centerMenuWidth
                    height: 300
                }
            },
            State {
                name: "calendar"
                PropertyChanges {
                    target: centerIsland
                    width: win.theme.evenPx(340)
                    height: 356
                }
            },
            State {
                name: "notifications"
                PropertyChanges {
                    target: centerIsland
                    width: win.theme.evenPx(Math.min(420, win.width - 2 * win.theme.sideMargin))
                    height: 440
                }
            }
        ]

        transitions: [
            Transition {
                from: "closed,preview"
                to: "clipboard,theme,calendar,notifications,preview,closed"
                NumberAnimation {
                    properties: "width,height"
                    duration: win.theme.animNormal
                    easing.type: Easing.OutCubic
                }
            },
            Transition {
                from: "clipboard,theme,calendar,notifications"
                to: "closed,preview"
                NumberAnimation {
                    properties: "width,height"
                    duration: win.theme.animNormal
                    easing.type: Easing.OutCubic
                }
            }
        ]

        // Absorb clicks inside the island so the backdrop MouseArea doesn't dismiss it
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        GlassSurface {
            anchors.fill: parent
            theme: win.theme
            wallpaperTex: wpTex
            screenWidth: win.screenW
            screenHeight: win.screenH
            islandX: centerIsland.x
            islandY: centerIsland.y
            radius: win.theme.barRadius
            hovered: !win.isCenterMenuOpen && (centerClock.hovered || (win.hasBarFocus && win.currentFocusIsland === "center"))
            innerAlpha: win.isCenterMenuOpen ? 0.32 : 0.36
            wallpaperMix: 0.0
        }

        Clock {
            id: centerClock
            anchors {
                top: parent.top
                topMargin: Math.round((win.theme.barHeight - height) / 2)
                horizontalCenter: parent.horizontalCenter
            }
            theme: win.theme
            keyboardSelected: win.currentFocusItem !== null && win.currentFocusItem.type === "clock"
            unreadCount: win.unreadCount
            dndEnabled: win.dndEnabled
            opacity: (win.isCenterMenuOpen || win.isPreviewOpen) ? 0.0 : 1.0
            visible: opacity > 0.01
            enabled: !win.isCenterMenuOpen && !win.isPreviewOpen
            onThemeMenuRequested: win.requestMenuToggle("theme", false)
            onCalendarMenuRequested: win.requestMenuToggle("calendar", false)
            onNotificationsMenuRequested: win.requestMenuToggle("notifications", false)

            Behavior on opacity {
                NumberAnimation {
                    duration: 70
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Inline Notification Preview (replaces clock & expands centerIsland slightly on arrival)
        Item {
            id: previewBox
            readonly property string previewTitle: {
                if (!win.previewNotification)
                    return "";
                if (win.previewNotification.summary && win.previewNotification.summary.length > 0)
                    return win.previewNotification.summary;
                return win.previewNotification.appName || "Bildirim";
            }
            readonly property string previewBody: win.previewNotification && win.previewNotification.body
                ? win.previewNotification.body
                : ""
            readonly property string previewLabel: previewBody.length > 0
                ? (previewTitle + " · " + previewBody)
                : previewTitle
            readonly property int desiredWidth: Math.min(340, Math.max(140, previewMetrics.advanceWidth + 48))

            anchors {
                left: parent.left
                leftMargin: 12
                right: parent.right
                rightMargin: 8
                top: parent.top
                topMargin: Math.round((win.theme.barHeight - height) / 2)
            }
            height: win.theme.pillHeight
            opacity: win.isPreviewOpen ? 1.0 : 0.0
            visible: opacity > 0.01
            enabled: win.isPreviewOpen

            Behavior on opacity {
                NumberAnimation {
                    duration: win.theme.animFast
                    easing.type: Easing.OutCubic
                }
            }

            TextMetrics {
                id: previewMetrics
                font.family: win.theme.fontUi
                font.pixelSize: win.theme.fontSizeSm
                font.weight: Font.Medium
                text: previewBox.previewLabel
            }

            HoverHandler {
                id: previewHover
                onHoveredChanged: win.requestPreviewHovered(hovered)
            }

            MouseArea {
                anchors {
                    left: parent.left
                    right: previewCloseBtn.left
                    rightMargin: 6
                    top: parent.top
                    bottom: parent.bottom
                }
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        win.requestDismissPreview();
                    else
                        win.requestMenuToggle("notifications", false);
                }

                Row {
                    anchors.fill: parent
                    spacing: 7

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰂚"
                        color: win.theme.accent
                        font.family: win.theme.fontUi
                        font.pixelSize: win.theme.fontSizeSm
                        renderType: Text.NativeRendering
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, parent.width - 21)
                        text: previewBox.previewLabel
                        elide: Text.ElideRight
                        color: win.theme.textPrimary
                        font.family: win.theme.fontUi
                        font.pixelSize: win.theme.fontSizeSm
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }
                }
            }

            Item {
                id: previewCloseBtn
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                width: 18
                height: 18

                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    antialiasing: true
                    color: previewCloseMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: previewCloseMouse.containsMouse ? win.theme.textPrimary : win.theme.textSecondary
                    font.family: win.theme.fontUi
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    id: previewCloseMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.requestDismissPreview()
                }
            }
        }

        ClipboardMenu {
            id: clipboardMenu
            anchors {
                fill: parent
                margins: 12
            }
            theme: win.theme
            open: win.isClipboardOpen
            openedByKeyboard: win.menuOpenedByKeyboard
            opacity: win.isClipboardOpen ? 1.0 : 0.0
            visible: opacity > 0.01
            onCloseRequested: win.requestMenuClose()

            Behavior on opacity {
                NumberAnimation {
                    duration: win.theme.animFast
                    easing.type: Easing.OutCubic
                }
            }
        }

        ThemeMenu {
            id: themeMenu
            anchors {
                fill: parent
                margins: 12
            }
            theme: win.theme
            open: win.isThemeOpen
            openedByKeyboard: win.menuOpenedByKeyboard
            opacity: win.isThemeOpen ? 1.0 : 0.0
            visible: opacity > 0.01
            onCloseRequested: win.requestMenuClose()

            Behavior on opacity {
                NumberAnimation {
                    duration: win.theme.animFast
                    easing.type: Easing.OutCubic
                }
            }
        }

        CalendarMenu {
            id: calendarMenu
            anchors {
                fill: parent
                margins: 12
            }
            theme: win.theme
            open: win.isCalendarOpen
            openedByKeyboard: win.menuOpenedByKeyboard
            opacity: win.isCalendarOpen ? 1.0 : 0.0
            visible: opacity > 0.01
            onCloseRequested: win.requestMenuClose()

            Behavior on opacity {
                NumberAnimation {
                    duration: win.theme.animFast
                    easing.type: Easing.OutCubic
                }
            }
        }

        NotificationMenu {
            id: notificationMenu
            anchors {
                fill: parent
                margins: 12
            }
            theme: win.theme
            open: win.isNotificationsOpen
            openedByKeyboard: win.menuOpenedByKeyboard
            notifications: win.notifications
            dndEnabled: win.dndEnabled
            opacity: win.isNotificationsOpen ? 1.0 : 0.0
            visible: opacity > 0.01
            onCloseRequested: win.requestMenuClose()
            onDismissRequested: uid => win.requestDismissNotification(uid)
            onClearAllRequested: win.requestClearNotifications()
            onToggleDndRequested: win.requestToggleDnd()

            Behavior on opacity {
                NumberAnimation {
                    duration: win.theme.animFast
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Right Island: Media, Network, Volume, System Tray, Power (morphs into AudioMenu / NetworkMenu / TrayMenu / PowerMenu)
    // ------------------------------------------------------------------
    Item {
        id: rightIsland
        x: win.width - win.theme.sideMargin - width
        y: win.theme.topMargin
        width: win.rightClosedWidth
        height: win.theme.barHeight
        clip: true
        state: win.isAudioOpen ? "audio" : (win.isNetworkOpen ? "network" : (win.isTrayOpen ? "tray" : (win.isPowerOpen ? "power" : "closed")))

        states: [
            State {
                name: "closed"
                PropertyChanges {
                    target: rightIsland
                    width: win.rightClosedWidth
                    height: win.theme.barHeight
                }
            },
            State {
                name: "audio"
                PropertyChanges {
                    target: rightIsland
                    width: 380
                    height: 460
                }
            },
            State {
                name: "network"
                PropertyChanges {
                    target: rightIsland
                    width: 380
                    height: 460
                }
            },
            State {
                name: "tray"
                PropertyChanges {
                    target: rightIsland
                    width: 380
                    height: 460
                }
            },
            State {
                name: "power"
                PropertyChanges {
                    target: rightIsland
                    width: win.theme.evenPx(powerMenu.implicitWidth + 16)
                    height: win.theme.barHeight
                }
            }
        ]

        transitions: [
            Transition {
                from: "closed"
                to: "audio,network,tray,power"
                NumberAnimation {
                    properties: "width,height"
                    duration: win.theme.animNormal
                    easing.type: Easing.OutCubic
                }
            },
            Transition {
                from: "audio,network,tray,power"
                to: "closed"
                NumberAnimation {
                    properties: "width,height"
                    duration: win.theme.animNormal
                    easing.type: Easing.OutCubic
                }
            }
        ]

        // Absorb clicks inside the island so the backdrop MouseArea doesn't dismiss it
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        HoverHandler {
            id: rightIslandHover
        }

        GlassSurface {
            anchors.fill: parent
            theme: win.theme
            wallpaperTex: wpTex
            screenWidth: win.screenW
            screenHeight: win.screenH
            islandX: rightIsland.x
            islandY: rightIsland.y
            radius: win.theme.barRadius
            hovered: win.hasBarFocus && win.currentFocusIsland === "right"
            innerAlpha: win.isTrayOpen
                ? 0.46
                : ((win.isAudioOpen || win.isNetworkOpen) ? 0.32 : 0.36)
            wallpaperMix: 0.0
        }

        Row {
            id: rightRow
            anchors {
                right: parent.right
                rightMargin: 8
                top: parent.top
                topMargin: Math.round((win.theme.barHeight - height) / 2)
            }
            spacing: 4
            opacity: win.isRightMenuOpen ? 0.0 : 1.0
            visible: opacity > 0.01
            enabled: !win.isRightMenuOpen

            Behavior on opacity {
                NumberAnimation {
                    duration: 70
                    easing.type: Easing.OutCubic
                }
            }

            Media {
                id: mediaMod
                anchors.verticalCenter: parent.verticalCenter
                theme: win.theme
                maxWidth: win.mediaBudget >= 48 ? Math.min(240, win.mediaBudget) : 0
                active: win.barVisible && !win.isRightMenuOpen && rightIslandHover.hovered
                keyboardSelected: win.currentFocusItem !== null && win.currentFocusItem.type === "media"
            }

            Rectangle {
                visible: mediaMod.visible
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 14
                color: Qt.rgba(1, 1, 1, 0.14)
            }

            Network {
                id: networkMod
                anchors.verticalCenter: parent.verticalCenter
                theme: win.theme
                maxTextWidth: win.networkTextBudget
                active: win.barVisible && !win.isRightMenuOpen && rightIslandHover.hovered
                menuOpen: win.isNetworkOpen
                keyboardSelected: win.currentFocusItem !== null && win.currentFocusItem.type === "network"
                onClicked: win.requestMenuToggle("network", false)
            }

            Volume {
                id: volumeMod
                anchors.verticalCenter: parent.verticalCenter
                theme: win.theme
                menuOpen: win.isAudioOpen
                keyboardSelected: win.currentFocusItem !== null && win.currentFocusItem.type === "volume"
                onClicked: win.requestMenuToggle("audio", false)
            }

            Rectangle {
                visible: trayMod.hasItems
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 14
                color: Qt.rgba(1, 1, 1, 0.14)
            }

            Tray {
                id: trayMod
                anchors.verticalCenter: parent.verticalCenter
                theme: win.theme
                menuOpen: win.isTrayOpen
                keyboardSelected: win.currentFocusItem !== null && win.currentFocusItem.type === "tray"
                onMenuToggleRequested: win.requestMenuToggle("tray", false)
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 14
                color: Qt.rgba(1, 1, 1, 0.14)
            }

            Power {
                id: powerMod
                anchors.verticalCenter: parent.verticalCenter
                theme: win.theme
                menuOpen: win.isPowerOpen
                keyboardSelected: win.currentFocusItem !== null && win.currentFocusItem.type === "power"
                onClicked: win.requestMenuToggle("power", false)
            }
        }

        AudioMenu {
            id: audioMenu
            anchors {
                fill: parent
                margins: 12
            }
            theme: win.theme
            open: win.isAudioOpen
            openedByKeyboard: win.menuOpenedByKeyboard
            opacity: win.isAudioOpen ? 1.0 : 0.0
            visible: opacity > 0.01
            onCloseRequested: win.requestMenuClose()

            Behavior on opacity {
                NumberAnimation {
                    duration: win.theme.animFast
                    easing.type: Easing.OutCubic
                }
            }
        }

        NetworkMenu {
            id: networkMenu
            anchors {
                fill: parent
                margins: 12
            }
            theme: win.theme
            open: win.isNetworkOpen
            openedByKeyboard: win.menuOpenedByKeyboard
            opacity: win.isNetworkOpen ? 1.0 : 0.0
            visible: opacity > 0.01
            onCloseRequested: win.requestMenuClose()

            Behavior on opacity {
                NumberAnimation {
                    duration: win.theme.animFast
                    easing.type: Easing.OutCubic
                }
            }
        }

        TrayMenu {
            id: trayMenu
            anchors {
                fill: parent
                margins: 12
            }
            theme: win.theme
            anchorWindow: win
            open: win.isTrayOpen
            openedByKeyboard: win.menuOpenedByKeyboard
            opacity: win.isTrayOpen ? 1.0 : 0.0
            visible: opacity > 0.01
            onCloseRequested: win.requestMenuClose()

            Behavior on opacity {
                NumberAnimation {
                    duration: win.theme.animFast
                    easing.type: Easing.OutCubic
                }
            }
        }

        PowerMenu {
            id: powerMenu
            anchors {
                right: parent.right
                rightMargin: 8
                top: parent.top
                topMargin: Math.round((win.theme.barHeight - height) / 2)
            }
            theme: win.theme
            open: win.isPowerOpen
            openedByKeyboard: win.menuOpenedByKeyboard
            opacity: win.isPowerOpen ? 1.0 : 0.0
            visible: opacity > 0.01
            onCloseRequested: win.requestMenuClose()

            Behavior on opacity {
                NumberAnimation {
                    duration: 70
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
