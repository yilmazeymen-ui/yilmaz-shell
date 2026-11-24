import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Wayland session lock controller for Liquid Glass.
// Trigger via IPC: quickshell -c liquid-glass ipc call lock lock
Scope {
    id: root

    required property var theme
    property alias locked: lock.locked
    property bool autoLockEnabled: true
    property bool unlocking: false

    readonly property var bgSize: {
        const s = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
        return s ? Qt.size(s.width, s.height) : Qt.size(1920, 1080);
    }

    // Pre-decode current wallpaper into QQuickPixmapCache so locking has no gray flash
    Image {
        visible: false
        source: root.theme.wallpaperPath !== "" ? "file://" + root.theme.wallpaperPath : ""
        sourceSize: root.bgSize
        asynchronous: true
    }

    function lockNow() {
        if (lock.locked)
            return;
        root.unlocking = false;
        lockContext.reset();
        lock.locked = true;
    }

    function idleLock() {
        if (root.autoLockEnabled)
            lockNow();
    }

    LockContext {
        id: lockContext
        onUnlocked: {
            if (root.unlocking)
                return;
            root.unlocking = true;
            unlockTimer.restart();
        }
    }

    Timer {
        id: unlockTimer
        interval: 480
        repeat: false
        onTriggered: {
            if (lock.locked)
                lock.locked = false;
            lockContext.reset();
            root.unlocking = false;
        }
    }

    WlSessionLock {
        id: lock
        locked: false

        WlSessionLockSurface {
            LockSurface {
                anchors.fill: parent
                context: lockContext
                theme: root.theme
                wallpaperPath: root.theme.wallpaperPath
                bgSize: root.bgSize
                unlocking: root.unlocking
            }
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lockNow();
        }

        function idleLock(): void {
            root.idleLock();
        }

        function isLocked(): bool {
            return lock.locked;
        }
    }
}
