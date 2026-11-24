//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "./modules/lock"

// Liquid Glass Shell entry point.
// Test standalone: quickshell -c liquid-glass
// Toggle bar via IPC: quickshell -c liquid-glass ipc call bar toggle
ShellRoot {
    id: root
    property bool barVisible: true
    property string activeMenu: ""
    property bool menuOpenedByKeyboard: false
    property string focusIsland: ""
    property int focusSeq: 0

    // Notification Center & inline preview state (shared across all screens)
    property var notifications: []
    property int unreadCount: 0
    property bool dndEnabled: false
    property var previewNotification: null
    property bool previewActive: false
    property bool previewHovered: false
    property int _nextNotifUid: 1

    function _recalcUnread() {
        let count = 0;
        for (let i = 0; i < notifications.length; i++) {
            if (!notifications[i].read)
                count++;
        }
        unreadCount = count;
    }

    function _stripMarkup(text) {
        if (!text)
            return "";
        return String(text).replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
    }

    function addNotification(n) {
        if (!n)
            return;
        n.tracked = true;
        const uid = _nextNotifUid++;
        const entry = {
            uid: uid,
            id: n.id,
            appName: n.appName || "Bildirim",
            summary: n.summary || "",
            body: _stripMarkup(n.body),
            appIcon: n.appIcon || "",
            image: n.image || "",
            urgency: n.urgency,
            timestamp: Date.now(),
            actions: n.actions || [],
            read: activeMenu === "notifications",
            raw: n
        };

        n.closed.connect(() => {
            removeNotificationByUid(uid);
        });

        const next = [entry];
        for (let i = 0; i < notifications.length; i++)
            next.push(notifications[i]);
        if (next.length > 50)
            next.length = 50;

        notifications = next;
        _recalcUnread();

        if (!dndEnabled && activeMenu !== "notifications" && barVisible) {
            previewNotification = entry;
            previewActive = true;
            previewTimer.restart();
        }
    }

    function removeNotificationByUid(uid) {
        const next = [];
        for (let i = 0; i < notifications.length; i++) {
            if (notifications[i].uid !== uid)
                next.push(notifications[i]);
        }
        if (next.length !== notifications.length) {
            notifications = next;
            _recalcUnread();
        }
        if (previewNotification && previewNotification.uid === uid) {
            previewActive = false;
            previewNotification = null;
        }
    }

    function dismissNotification(uid) {
        for (let i = 0; i < notifications.length; i++) {
            if (notifications[i].uid === uid) {
                const raw = notifications[i].raw;
                removeNotificationByUid(uid);
                if (raw) {
                    try {
                        raw.dismiss();
                    } catch (e) {}
                }
                return;
            }
        }
    }

    function clearAllNotifications() {
        const list = notifications;
        notifications = [];
        unreadCount = 0;
        previewActive = false;
        previewNotification = null;
        for (let i = 0; i < list.length; i++) {
            const raw = list[i].raw;
            if (raw) {
                try {
                    raw.dismiss();
                } catch (e) {}
            }
        }
    }

    function markAllRead() {
        let changed = false;
        const next = [];
        for (let i = 0; i < notifications.length; i++) {
            const item = notifications[i];
            if (!item.read) {
                changed = true;
                next.push({
                    uid: item.uid,
                    id: item.id,
                    appName: item.appName,
                    summary: item.summary,
                    body: item.body,
                    appIcon: item.appIcon,
                    image: item.image,
                    urgency: item.urgency,
                    timestamp: item.timestamp,
                    actions: item.actions,
                    read: true,
                    raw: item.raw
                });
            } else {
                next.push(item);
            }
        }
        if (changed) {
            notifications = next;
            unreadCount = 0;
        }
    }

    function toggleDnd() {
        dndEnabled = !dndEnabled;
        if (dndEnabled)
            previewActive = false;
    }

    function dismissPreview() {
        previewActive = false;
    }

    NotificationServer {
        id: notificationServer
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        onNotification: notification => root.addNotification(notification)
    }

    Timer {
        id: previewTimer
        interval: 3000
        running: root.previewActive && !root.previewHovered && root.activeMenu === ""
        onTriggered: root.previewActive = false
    }

    function toggleMenu(name, byKeyboard) {
        if (!barVisible)
            barVisible = true;
        focusIsland = "";
        if (activeMenu === name) {
            activeMenu = "";
            menuOpenedByKeyboard = false;
        } else {
            if (name === "notifications") {
                previewActive = false;
                markAllRead();
            }
            menuOpenedByKeyboard = !!byKeyboard;
            activeMenu = name;
        }
    }

    function closeMenu() {
        activeMenu = "";
        menuOpenedByKeyboard = false;
    }

    function focusBar(island) {
        if (island !== "left" && island !== "center" && island !== "right")
            return;
        if (!barVisible)
            barVisible = true;
        if (activeMenu !== "") {
            activeMenu = "";
            focusIsland = island;
            focusSeq++;
            return;
        }
        if (focusIsland === island) {
            focusIsland = "";
        } else {
            focusIsland = island;
            focusSeq++;
        }
    }

    function closeBarFocus() {
        focusIsland = "";
        activeMenu = "";
    }

    Theme {
        id: appTheme
    }

    Lock {
        id: sessionLock
        theme: appTheme
        onLockedChanged: {
            if (locked) {
                root.activeMenu = "";
                root.menuOpenedByKeyboard = false;
                root.focusIsland = "";
                root.previewActive = false;
            }
        }
    }

    IpcHandler {
        target: "bar"

        function toggle(): void {
            root.barVisible = !root.barVisible;
            if (!root.barVisible) {
                root.activeMenu = "";
                root.focusIsland = "";
            }
        }

        function show(): void {
            root.barVisible = true;
        }

        function hide(): void {
            root.barVisible = false;
            root.activeMenu = "";
            root.focusIsland = "";
        }

        function toggleMenu(name: string): void {
            root.toggleMenu(name, true);
        }

        function toggleApps(): void {
            root.toggleMenu("apps", true);
        }

        function toggleClipboard(): void {
            root.toggleMenu("clipboard", true);
        }

        function toggleTheme(): void {
            root.toggleMenu("theme", true);
        }

        function toggleCalendar(): void {
            root.toggleMenu("calendar", true);
        }

        function toggleNotifications(): void {
            root.toggleMenu("notifications", true);
        }

        function toggleAudio(): void {
            root.toggleMenu("audio", true);
        }

        function toggleNetwork(): void {
            root.toggleMenu("network", true);
        }

        function togglePower(): void {
            root.toggleMenu("power", true);
        }

        function toggleTray(): void {
            root.toggleMenu("tray", true);
        }

        function closeMenu(): void {
            root.closeMenu();
        }

        function focusLeft(): void {
            root.focusBar("left");
        }

        function focusCenter(): void {
            root.focusBar("center");
        }

        function focusRight(): void {
            root.focusBar("right");
        }

        function focusIsland(name: string): void {
            root.focusBar(name);
        }

        function closeFocus(): void {
            root.closeBarFocus();
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: TopBar {
            theme: appTheme
            barVisible: root.barVisible
            activeMenu: root.activeMenu
            menuOpenedByKeyboard: root.menuOpenedByKeyboard
            focusIsland: root.focusIsland
            focusSeq: root.focusSeq
            notifications: root.notifications
            unreadCount: root.unreadCount
            dndEnabled: root.dndEnabled
            previewNotification: root.previewNotification
            previewActive: root.previewActive
            onRequestMenuToggle: (name, byKeyboard) => root.toggleMenu(name, byKeyboard)
            onRequestMenuClose: root.closeMenu()
            onRequestFocusClose: root.focusIsland = ""
            onRequestDismissNotification: uid => root.dismissNotification(uid)
            onRequestClearNotifications: root.clearAllNotifications()
            onRequestToggleDnd: root.toggleDnd()
            onRequestDismissPreview: root.dismissPreview()
            onRequestPreviewHovered: hovered => { root.previewHovered = hovered; }
        }
    }
}
