import QtQuick
import Quickshell
import Quickshell.Io

// Bar-integrated Network & Wi-Fi Control Menu rendered inside rightIsland's GlassSurface.
Item {
    id: root
    required property var theme
    property bool open: false
    property bool openedByKeyboard: false
    property bool keyboardNavActive: false

    signal closeRequested()

    property bool wifiEnabled: true
    property bool scanning: false
    property bool busy: false
    property string statusMessage: ""
    property bool statusError: false

    property string activeType: "none" // "wifi" | "ethernet" | "none"
    property string activeName: ""
    property string activeDevice: ""
    property string activeIp: ""

    property bool ethConnected: false
    property string ethName: ""
    property string ethDevice: ""
    property string ethIp: ""

    property bool wifiConnected: false
    property string wifiName: ""
    property string wifiDevice: ""
    property string wifiIp: ""

    property string activeTab: "wifi" // "wifi" | "hotspot"

    property bool hotspotActive: false
    property string hotspotConnName: ""
    property string hotspotSsid: "LiquidGlass-AP"
    property string hotspotPassword: ""
    property bool showHotspotPassword: false

    property var wifiList: []
    property var savedConnections: []
    property int selectedWifiIndex: 0

    onWifiListChanged: {
        if (wifiList.length === 0)
            selectedWifiIndex = 0;
        else if (selectedWifiIndex >= wifiList.length)
            selectedWifiIndex = wifiList.length - 1;
    }

    // Inline password prompt state
    property string promptSsid: ""
    property bool showPasswordPrompt: false

    function signalIcon(sig) {
        if (sig >= 75)
            return "󰤨";
        if (sig >= 50)
            return "󰤥";
        if (sig >= 25)
            return "󰤢";
        return "󰤟";
    }

    function isSaved(ssid) {
        return root.savedConnections.indexOf(ssid) !== -1;
    }

    function refreshAll(rescan) {
        if (!radioProc.running)
            radioProc.running = true;
        if (!devProc.running)
            devProc.running = true;
        if (!savedProc.running)
            savedProc.running = true;

        if (rescan) {
            root.scanning = true;
            if (wifiProc.running)
                wifiProc.running = false;
            wifiProc.command = ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "yes"];
            wifiProc.running = true;
        } else if (!wifiProc.running) {
            wifiProc.command = ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"];
            wifiProc.running = true;
        }
    }

    function toggleWifi() {
        if (actionProc.running)
            return;
        const next = root.wifiEnabled ? "off" : "on";
        root.busy = true;
        root.statusError = false;
        root.statusMessage = next === "on" ? "Wi-Fi açılıyor..." : "Wi-Fi kapatılıyor...";
        actionProc.command = ["nmcli", "radio", "wifi", next];
        actionProc.running = true;
    }

    function disconnectDevice(dev) {
        if (actionProc.running || !dev || dev === "")
            return;
        root.busy = true;
        root.statusError = false;
        root.statusMessage = "Bağlantı kesiliyor...";
        actionProc.command = ["nmcli", "dev", "disconnect", dev];
        actionProc.running = true;
    }

    function disconnectActive() {
        disconnectDevice(root.activeDevice);
    }

    function connectToNetwork(item) {
        if (!item || actionProc.running)
            return;
        if (item.inUse) {
            disconnectActive();
            return;
        }

        const sec = (item.security || "").trim();
        const needsPass = sec !== "" && sec !== "--";

        if (isSaved(item.ssid) || !needsPass) {
            root.showPasswordPrompt = false;
            root.promptSsid = "";
            root.busy = true;
            root.statusError = false;
            root.statusMessage = `${item.ssid} ağına bağlanılıyor...`;
            if (isSaved(item.ssid))
                actionProc.command = ["nmcli", "con", "up", "id", item.ssid];
            else
                actionProc.command = ["nmcli", "dev", "wifi", "connect", item.ssid];
            actionProc.running = true;
        } else {
            root.promptSsid = item.ssid;
            root.showPasswordPrompt = true;
            passInput.text = "";
            passFocusTimer.restart();
        }
    }

    function submitPassword() {
        if (actionProc.running || root.promptSsid === "")
            return;
        const pwd = passInput.text;
        if (pwd.length === 0)
            return;
        root.showPasswordPrompt = false;
        root.busy = true;
        root.statusError = false;
        root.statusMessage = `${root.promptSsid} ağına bağlanılıyor...`;
        actionProc.command = ["nmcli", "dev", "wifi", "connect", root.promptSsid, "password", pwd];
        actionProc.running = true;
        passInput.text = "";
    }

    function toggleHotspot() {
        if (actionProc.running)
            return;
        if (root.hotspotActive) {
            const target = root.hotspotConnName !== "" ? root.hotspotConnName : "Hotspot";
            root.busy = true;
            root.statusError = false;
            root.statusMessage = "Hotspot kapatılıyor...";
            actionProc.command = ["nmcli", "connection", "down", "id", target];
            actionProc.running = true;
            return;
        }

        const ssid = root.hotspotSsid.trim();
        const pwd = root.hotspotPassword;
        if (ssid.length === 0) {
            root.statusError = true;
            root.statusMessage = "Hotspot adı boş olamaz";
            return;
        }
        if (pwd.length > 0 && pwd.length < 8) {
            root.statusError = true;
            root.statusMessage = "Hotspot şifresi en az 8 karakter olmalı";
            return;
        }

        root.busy = true;
        root.statusError = false;
        root.statusMessage = "Hotspot başlatılıyor...";
        if (pwd.length >= 8)
            actionProc.command = ["nmcli", "dev", "wifi", "hotspot", "ssid", ssid, "password", pwd];
        else
            actionProc.command = ["nmcli", "dev", "wifi", "hotspot", "ssid", ssid];
        actionProc.running = true;
    }

    onOpenChanged: {
        if (open) {
            showPasswordPrompt = false;
            promptSsid = "";
            statusMessage = "";
            statusError = false;
            selectedWifiIndex = 0;
            keyboardNavActive = openedByKeyboard;
            refreshAll(false);
            focusTimer.restart();
        } else {
            keyboardNavActive = false;
        }
    }

    Timer {
        id: focusTimer
        interval: 20
        onTriggered: {
            if (root.open && !root.showPasswordPrompt)
                keyScope.forceActiveFocus();
        }
    }

    Timer {
        id: passFocusTimer
        interval: 20
        onTriggered: {
            if (root.open && root.showPasswordPrompt)
                passInput.forceActiveFocus();
        }
    }

    Timer {
        interval: 6000
        running: root.open
        repeat: true
        onTriggered: root.refreshAll(false)
    }

    Item {
        id: keyScope
        focus: root.open && !root.showPasswordPrompt && !hotspotSsidInput.activeFocus && !hotspotPassInput.activeFocus

        Keys.onPressed: event => {
            if (!root.open || root.showPasswordPrompt || hotspotSsidInput.activeFocus || hotspotPassInput.activeFocus)
                return;

            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                root.closeRequested();
            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab
                       || event.key === Qt.Key_Left || event.key === Qt.Key_Right
                       || event.key === Qt.Key_H || event.key === Qt.Key_L) {
                root.keyboardNavActive = true;
                root.activeTab = (root.activeTab === "wifi") ? "hotspot" : "wifi";
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                root.keyboardNavActive = true;
                if (root.activeTab === "wifi" && root.wifiEnabled && root.wifiList.length > 0) {
                    root.selectedWifiIndex = (root.selectedWifiIndex - 1 + root.wifiList.length) % root.wifiList.length;
                    wifiListView.positionViewAtIndex(root.selectedWifiIndex, ListView.Contain);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                root.keyboardNavActive = true;
                if (root.activeTab === "wifi" && root.wifiEnabled && root.wifiList.length > 0) {
                    root.selectedWifiIndex = (root.selectedWifiIndex + 1) % root.wifiList.length;
                    wifiListView.positionViewAtIndex(root.selectedWifiIndex, ListView.Contain);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (root.activeTab === "wifi") {
                    if (root.wifiEnabled && root.selectedWifiIndex >= 0 && root.selectedWifiIndex < root.wifiList.length)
                        root.connectToNetwork(root.wifiList[root.selectedWifiIndex]);
                } else {
                    root.toggleHotspot();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_W) {
                root.toggleWifi();
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                root.refreshAll(true);
                event.accepted = true;
            } else if (event.key === Qt.Key_D) {
                root.disconnectActive();
                event.accepted = true;
            } else if (event.key === Qt.Key_E && root.activeTab === "hotspot" && !root.hotspotActive) {
                hotspotSsidInput.forceActiveFocus();
                event.accepted = true;
            }
        }
    }

    // ------------------------------------------------------------------
    // Processes
    // ------------------------------------------------------------------
    Process {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = this.text.trim() === "enabled";
            }
        }
    }

    Process {
        id: savedProc
        command: ["nmcli", "-t", "-f", "NAME", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                const list = [];
                for (let i = 0; i < lines.length; i++) {
                    const s = lines[i].trim();
                    if (s.length > 0)
                        list.push(s);
                }
                root.savedConnections = list;
            }
        }
    }

    Process {
        id: devProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION,DEVICE", "dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                let hasEth = false;
                let eName = "";
                let eDev = "";
                let hasWifi = false;
                let wName = "";
                let wDev = "";

                const lines = this.text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split(":");
                    if (parts.length < 4)
                        continue;
                    const type = parts[0];
                    const state = parts[1];
                    const dev = parts[parts.length - 1];
                    const conn = parts.slice(2, parts.length - 1).join(":");
                    if (state === "connected") {
                        if (type === "ethernet" && !hasEth) {
                            hasEth = true;
                            eName = conn;
                            eDev = dev;
                        } else if (type === "wifi" && !hasWifi) {
                            hasWifi = true;
                            wName = conn;
                            wDev = dev;
                        }
                    }
                }

                root.ethConnected = hasEth;
                root.ethName = eName;
                root.ethDevice = eDev;
                if (!hasEth)
                    root.ethIp = "";

                root.wifiConnected = hasWifi;
                root.wifiName = wName;
                root.wifiDevice = wDev;
                if (!hasWifi)
                    root.wifiIp = "";

                if (hasEth) {
                    root.activeType = "ethernet";
                    root.activeName = eName;
                    root.activeDevice = eDev;
                } else if (hasWifi) {
                    root.activeType = "wifi";
                    root.activeName = wName;
                    root.activeDevice = wDev;
                } else {
                    root.activeType = "none";
                    root.activeName = "";
                    root.activeDevice = "";
                }

                if (hasWifi && wName !== "" && !apCheckProc.running) {
                    apCheckProc.targetConn = wName;
                    apCheckProc.command = ["nmcli", "-g", "802-11-wireless.mode", "connection", "show", "id", wName];
                    apCheckProc.running = true;
                } else if (!hasWifi) {
                    root.hotspotActive = false;
                    root.hotspotConnName = "";
                }

                if (hasEth && !ethIpProc.running) {
                    ethIpProc.command = ["nmcli", "-t", "-f", "IP4.ADDRESS", "dev", "show", eDev];
                    ethIpProc.running = true;
                }
                if (hasWifi && !wifiIpProc.running) {
                    wifiIpProc.command = ["nmcli", "-t", "-f", "IP4.ADDRESS", "dev", "show", wDev];
                    wifiIpProc.running = true;
                }

                root.activeIp = hasEth ? root.ethIp : (hasWifi ? root.wifiIp : "");
            }
        }
    }

    Process {
        id: apCheckProc
        property string targetConn: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const isAp = this.text.trim() === "ap";
                root.hotspotActive = isAp;
                root.hotspotConnName = isAp ? apCheckProc.targetConn : "";
            }
        }
    }

    Process {
        id: ethIpProc
        stdout: StdioCollector {
            onStreamFinished: {
                const line = this.text.trim().split("\n")[0] || "";
                const idx = line.indexOf(":");
                const raw = idx >= 0 ? line.slice(idx + 1).trim() : line;
                const slash = raw.indexOf("/");
                root.ethIp = slash >= 0 ? raw.slice(0, slash) : raw;
                if (root.ethConnected)
                    root.activeIp = root.ethIp;
            }
        }
    }

    Process {
        id: wifiIpProc
        stdout: StdioCollector {
            onStreamFinished: {
                const line = this.text.trim().split("\n")[0] || "";
                const idx = line.indexOf(":");
                const raw = idx >= 0 ? line.slice(idx + 1).trim() : line;
                const slash = raw.indexOf("/");
                root.wifiIp = slash >= 0 ? raw.slice(0, slash) : raw;
                if (!root.ethConnected && root.wifiConnected)
                    root.activeIp = root.wifiIp;
            }
        }
    }

    Process {
        id: wifiProc
        onExited: root.scanning = false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                const bySsid = {};
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    if (!line)
                        continue;
                    // Format: IN-USE:SSID:SIGNAL:SECURITY (SSID may contain escaped \:)
                    const parts = line.split(":");
                    if (parts.length < 4)
                        continue;
                    const inUse = parts[0].trim() === "*";
                    const security = parts[parts.length - 1].trim();
                    const signal = parseInt(parts[parts.length - 2], 10) || 0;
                    const ssid = parts.slice(1, parts.length - 2).join(":").trim();
                    if (ssid.length === 0)
                        continue;

                    const existing = bySsid[ssid];
                    if (!existing || inUse || (!existing.inUse && signal > existing.signal)) {
                        bySsid[ssid] = {
                            ssid: ssid,
                            signal: signal,
                            security: security,
                            inUse: inUse
                        };
                    }
                }

                const result = Object.values(bySsid);
                result.sort((a, b) => {
                    if (a.inUse !== b.inUse)
                        return a.inUse ? -1 : 1;
                    return b.signal - a.signal;
                });
                root.wifiList = result;
            }
        }
    }

    Process {
        id: actionProc
        property string errBuf: ""
        stderr: StdioCollector {
            onStreamFinished: {
                actionProc.errBuf = this.text.trim();
            }
        }
        onExited: code => {
            root.busy = false;
            if (code !== 0) {
                root.statusError = true;
                root.statusMessage = actionProc.errBuf.length > 0 ? actionProc.errBuf : "İşlem başarısız oldu";
            } else {
                root.statusError = false;
                root.statusMessage = "";
            }
            actionProc.errBuf = "";
            root.refreshAll(false);
        }
    }

    // ------------------------------------------------------------------
    // Header
    // ------------------------------------------------------------------
    Row {
        id: headerRow
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 26
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.activeType === "ethernet" ? "󰈀" : (root.wifiEnabled ? "󰤨" : "󰤭")
            color: root.activeType === "none" ? root.theme.warn : root.theme.accent
            font.family: root.theme.fontMono
            font.pixelSize: root.theme.fontSizeLg
            renderType: Text.NativeRendering
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 134
            text: "Ağ ve İnternet"
            color: root.theme.textPrimary
            font.family: root.theme.fontUi
            font.pixelSize: root.theme.fontSizeLg
            font.weight: Font.Medium
            renderType: Text.NativeRendering
        }

        // Wi-Fi Toggle Pill
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            height: 22

            Rectangle {
                anchors.fill: parent
                radius: 11
                antialiasing: true
                color: root.wifiEnabled
                    ? root.theme.glassPillActive
                    : (wifiToggleMouse.containsMouse ? root.theme.glassPillHover : root.theme.glassPill)

                Behavior on color {
                    ColorAnimation {
                        duration: root.theme.animFast
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: root.wifiEnabled ? "Açık" : "Kapalı"
                color: root.wifiEnabled ? root.theme.accent : root.theme.textSecondary
                font.family: root.theme.fontUi
                font.pixelSize: 11
                font.weight: Font.Medium
                renderType: Text.NativeRendering
            }

            MouseArea {
                id: wifiToggleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleWifi()
            }
        }

        // Rescan Button
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24

            Rectangle {
                anchors.fill: parent
                radius: 12
                antialiasing: true
                color: scanMouse.containsMouse ? root.theme.glassPillHover : "transparent"
            }

            Text {
                anchors.centerIn: parent
                text: "󰑐"
                color: root.scanning ? root.theme.accent : (scanMouse.containsMouse ? root.theme.textPrimary : root.theme.textSecondary)
                font.family: root.theme.fontUi
                font.pixelSize: root.theme.fontSizeMd
                renderType: Text.NativeRendering
            }

            MouseArea {
                id: scanMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.refreshAll(true)
            }
        }

        // Close Button
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24

            Rectangle {
                anchors.fill: parent
                radius: 12
                antialiasing: true
                color: closeMouse.containsMouse ? root.theme.glassPillHover : "transparent"
            }

            Text {
                anchors.centerIn: parent
                text: "󰅖"
                color: closeMouse.containsMouse ? root.theme.textPrimary : root.theme.textSecondary
                font.family: root.theme.fontUi
                font.pixelSize: root.theme.fontSizeSm
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

    // ------------------------------------------------------------------
    // Active Connection Card(s)
    // ------------------------------------------------------------------
    Rectangle {
        id: activeCard
        anchors {
            top: headerRow.bottom
            topMargin: 10
            left: parent.left
            right: parent.right
        }
        height: (root.ethConnected && root.wifiConnected) ? 88 : 52
        radius: root.theme.pillRadius
        antialiasing: true
        color: root.theme.glassPill

        Column {
            anchors {
                fill: parent
                leftMargin: 12
                rightMargin: 10
                topMargin: 7
                bottomMargin: 7
            }
            spacing: 6

            // Empty state when neither Ethernet nor Wi-Fi is connected
            Row {
                visible: !root.ethConnected && !root.wifiConnected
                width: parent.width
                height: 38
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰤭"
                    color: root.theme.warn
                    font.family: root.theme.fontMono
                    font.pixelSize: 16
                    renderType: Text.NativeRendering
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 30
                    spacing: 2

                    Text {
                        width: parent.width
                        text: "Bağlı ağ yok"
                        color: root.theme.textPrimary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeMd
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }

                    Text {
                        width: parent.width
                        text: root.wifiEnabled ? "Aşağıdan bir Wi-Fi ağı seçin" : "Wi-Fi kapalı"
                        color: root.theme.textSecondary
                        font.family: root.theme.fontMono
                        font.pixelSize: 11
                        renderType: Text.NativeRendering
                    }
                }
            }

            // Ethernet row
            Row {
                visible: root.ethConnected
                width: parent.width
                height: 34
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰈀"
                    color: root.theme.accent
                    font.family: root.theme.fontMono
                    font.pixelSize: 16
                    renderType: Text.NativeRendering
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 104
                    spacing: 1

                    Text {
                        width: parent.width
                        text: root.ethName
                        color: root.theme.textPrimary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeSm
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        width: parent.width
                        text: root.ethIp !== "" ? `${root.ethDevice} • ${root.ethIp}` : root.ethDevice
                        color: root.theme.textSecondary
                        font.family: root.theme.fontMono
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 66
                    height: 24

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        antialiasing: true
                        color: ethDiscMouse.containsMouse ? root.theme.tint(root.theme.warn, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Kes"
                        color: root.theme.warn
                        font.family: root.theme.fontUi
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: ethDiscMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.disconnectDevice(root.ethDevice)
                    }
                }
            }

            // Wi-Fi row
            Row {
                visible: root.wifiConnected
                width: parent.width
                height: 34
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.hotspotActive ? "󰀂" : "󰤨"
                    color: root.theme.accent
                    font.family: root.theme.fontMono
                    font.pixelSize: 16
                    renderType: Text.NativeRendering
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 104
                    spacing: 1

                    Text {
                        width: parent.width
                        text: root.hotspotActive ? `${root.wifiName} (Hotspot)` : root.wifiName
                        color: root.theme.textPrimary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeSm
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        width: parent.width
                        text: root.wifiIp !== "" ? `${root.wifiDevice} • ${root.wifiIp}` : root.wifiDevice
                        color: root.theme.textSecondary
                        font.family: root.theme.fontMono
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 66
                    height: 24

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        antialiasing: true
                        color: wifiDiscMouse.containsMouse ? root.theme.tint(root.theme.warn, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Kes"
                        color: root.theme.warn
                        font.family: root.theme.fontUi
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: wifiDiscMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.disconnectDevice(root.wifiDevice)
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Status Banner / Inline Password Prompt
    // ------------------------------------------------------------------
    Rectangle {
        id: statusBanner
        visible: root.statusMessage !== "" && !root.showPasswordPrompt
        anchors {
            top: activeCard.bottom
            topMargin: visible ? 8 : 0
            left: parent.left
            right: parent.right
        }
        height: visible ? 28 : 0
        radius: root.theme.pillRadius
        antialiasing: true
        color: root.statusError
            ? root.theme.tint(root.theme.warn, 0.16)
            : root.theme.glassPillActive

        Text {
            anchors {
                fill: parent
                leftMargin: 10
                rightMargin: 10
            }
            verticalAlignment: Text.AlignVCenter
            text: root.statusMessage
            color: root.statusError ? root.theme.warn : root.theme.textPrimary
            font.family: root.theme.fontUi
            font.pixelSize: 11
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
    }

    Rectangle {
        id: passPrompt
        visible: root.showPasswordPrompt
        anchors {
            top: activeCard.bottom
            topMargin: visible ? 8 : 0
            left: parent.left
            right: parent.right
        }
        height: visible ? 72 : 0
        radius: root.theme.pillRadius
        antialiasing: true
        color: root.theme.glassPillActive

        Column {
            anchors {
                fill: parent
                margins: 8
            }
            spacing: 6

            Text {
                width: parent.width
                text: `${root.promptSsid} şifresi:`
                color: root.theme.textPrimary
                font.family: root.theme.fontUi
                font.pixelSize: 11
                font.weight: Font.Medium
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Row {
                width: parent.width
                height: 28
                spacing: 6

                Rectangle {
                    width: parent.width - 116
                    height: 28
                    radius: 10
                    antialiasing: true
                    color: Qt.rgba(0, 0, 0, 0.28)

                    TextInput {
                        id: passInput
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        color: root.theme.textPrimary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeSm
                        clip: true

                        Keys.onReturnPressed: event => {
                            event.accepted = true;
                            root.submitPassword();
                        }
                        Keys.onEnterPressed: event => {
                            event.accepted = true;
                            root.submitPassword();
                        }
                        Keys.onEscapePressed: event => {
                            event.accepted = true;
                            root.showPasswordPrompt = false;
                            root.promptSsid = "";
                            focusTimer.restart();
                        }
                    }
                }

                Item {
                    width: 56
                    height: 28

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        antialiasing: true
                        color: connBtnMouse.containsMouse ? root.theme.accent : root.theme.accentDeep
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Bağlan"
                        color: root.theme.textPrimary
                        font.family: root.theme.fontUi
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: connBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submitPassword()
                    }
                }

                Item {
                    width: 48
                    height: 28

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        antialiasing: true
                        color: cancelBtnMouse.containsMouse ? root.theme.glassPillHover : root.theme.glassPill
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "İptal"
                        color: root.theme.textSecondary
                        font.family: root.theme.fontUi
                        font.pixelSize: 11
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: cancelBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showPasswordPrompt = false;
                            root.promptSsid = "";
                            focusTimer.restart();
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Section Tabs: Wi-Fi | Hotspot
    // ------------------------------------------------------------------
    Rectangle {
        id: tabBar
        anchors {
            top: root.showPasswordPrompt ? passPrompt.bottom : (statusBanner.visible ? statusBanner.bottom : activeCard.bottom)
            topMargin: 8
            left: parent.left
            right: parent.right
        }
        height: 30
        radius: root.theme.pillRadius
        antialiasing: true
        color: root.theme.glassPill

        Row {
            anchors {
                fill: parent
                margins: 3
            }
            spacing: 4

            Repeater {
                model: [
                    { id: "wifi", label: "Wi-Fi Ağları" },
                    { id: "hotspot", label: root.hotspotActive ? "Hotspot • Açık" : "Hotspot" }
                ]

                delegate: Item {
                    required property var modelData
                    readonly property bool selected: root.activeTab === modelData.id

                    width: (tabBar.width - 10) / 2
                    height: tabBar.height - 6

                    Rectangle {
                        anchors.fill: parent
                        radius: root.theme.pillRadius - 2
                        antialiasing: true
                        color: parent.selected
                            ? root.theme.glassPillActive
                            : (netTabMouse.containsMouse ? root.theme.glassPillHover : "transparent")

                        Behavior on color {
                            ColorAnimation {
                                duration: root.theme.animFast
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: parent.selected ? root.theme.accent : root.theme.textSecondary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeSm
                        font.weight: parent.selected ? Font.Medium : Font.Normal
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: netTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = modelData.id
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Wi-Fi List
    // ------------------------------------------------------------------
    ListView {
        id: wifiListView
        visible: root.activeTab === "wifi"
        anchors {
            top: tabBar.bottom
            topMargin: 8
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: root.wifiEnabled ? root.wifiList : []

        delegate: Item {
            id: wifiRow
            required property var modelData
            required property int index
            readonly property bool isSecure: modelData.security !== "" && modelData.security !== "--"
            readonly property bool kbFocused: root.open && root.keyboardNavActive && root.activeTab === "wifi" && !root.showPasswordPrompt && root.selectedWifiIndex === index

            width: wifiListView.width
            height: 42

            Rectangle {
                anchors.fill: parent
                radius: root.theme.pillRadius
                antialiasing: true
                color: modelData.inUse
                    ? root.theme.glassPillActive
                    : ((wifiRowMouse.containsMouse || wifiRow.kbFocused) ? root.theme.glassPillHover : "transparent")

                Behavior on color {
                    ColorAnimation {
                        duration: root.theme.animFast
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Rectangle {
                visible: wifiRow.kbFocused
                anchors {
                    left: parent.left
                    leftMargin: 3
                    verticalCenter: parent.verticalCenter
                }
                width: 3
                height: 22
                radius: 1.5
                color: root.theme.accent
            }

            Row {
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.signalIcon(modelData.signal)
                    color: modelData.inUse ? root.theme.accent : root.theme.textSecondary
                    font.family: root.theme.fontMono
                    font.pixelSize: root.theme.fontSizeLg
                    renderType: Text.NativeRendering
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 78
                    spacing: 1

                    Text {
                        width: parent.width
                        text: modelData.ssid
                        color: modelData.inUse ? root.theme.textPrimary : root.theme.textSecondary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeSm
                        font.weight: modelData.inUse ? Font.Medium : Font.Normal
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        width: parent.width
                        text: modelData.inUse
                            ? "Bağlı • Kesmek için tıklayın"
                            : (wifiRow.isSecure ? (root.isSaved(modelData.ssid) ? `${modelData.security} • Kayıtlı` : modelData.security) : "Açık ağ")
                        color: modelData.inUse ? root.theme.accent : root.theme.textMuted
                        font.family: root.theme.fontUi
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: wifiRow.isSecure ? "󰌾" : ""
                    color: root.theme.textMuted
                    font.family: root.theme.fontUi
                    font.pixelSize: 11
                    visible: wifiRow.isSecure
                    renderType: Text.NativeRendering
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    horizontalAlignment: Text.AlignRight
                    text: `${modelData.signal}%`
                    color: modelData.inUse ? root.theme.textPrimary : root.theme.textMuted
                    font.family: root.theme.fontMono
                    font.pixelSize: 11
                    font.features: { "tnum": 1 }
                    renderType: Text.NativeRendering
                }
            }

            MouseArea {
                id: wifiRowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.connectToNetwork(modelData)
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !root.wifiEnabled || wifiListView.count === 0
            text: !root.wifiEnabled ? "Wi-Fi kapalı" : (root.scanning ? "Ağlar taranıyor..." : "Wi-Fi ağı bulunamadı")
            color: root.theme.textMuted
            font.family: root.theme.fontUi
            font.pixelSize: root.theme.fontSizeMd
            renderType: Text.NativeRendering
        }
    }

    // ------------------------------------------------------------------
    // Hotspot Panel
    // ------------------------------------------------------------------
    Item {
        id: hotspotPanel
        visible: root.activeTab === "hotspot"
        anchors {
            top: tabBar.bottom
            topMargin: 8
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        Column {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: 10

            // Hotspot Status & Toggle Card
            Rectangle {
                width: parent.width
                height: 54
                radius: root.theme.pillRadius
                antialiasing: true
                color: root.hotspotActive ? root.theme.glassPillActive : root.theme.glassPill

                Row {
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 10
                    }
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰀂"
                        color: root.hotspotActive ? root.theme.accent : root.theme.textSecondary
                        font.family: root.theme.fontMono
                        font.pixelSize: 18
                        renderType: Text.NativeRendering
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 114
                        spacing: 2

                        Text {
                            width: parent.width
                            text: root.hotspotActive ? "Hotspot Aktif" : "Kişisel Erişim Noktası"
                            color: root.theme.textPrimary
                            font.family: root.theme.fontUi
                            font.pixelSize: root.theme.fontSizeMd
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }

                        Text {
                            width: parent.width
                            text: root.hotspotActive
                                ? (root.activeIp !== "" ? `${root.activeName} • ${root.activeIp}` : root.activeName)
                                : "Wi-Fi üzerinden internet paylaşın"
                            color: root.hotspotActive ? root.theme.accent : root.theme.textSecondary
                            font.family: root.theme.fontUi
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }
                    }

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 74
                        height: 28

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            antialiasing: true
                            color: root.hotspotActive
                                ? (hsToggleMouse.containsMouse ? root.theme.tint(root.theme.warn, 0.28) : root.theme.tint(root.theme.warn, 0.16))
                                : (hsToggleMouse.containsMouse ? root.theme.accent : root.theme.accentDeep)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.hotspotActive ? "Durdur" : "Başlat"
                            color: root.hotspotActive ? root.theme.warn : root.theme.textPrimary
                            font.family: root.theme.fontUi
                            font.pixelSize: root.theme.fontSizeSm
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                        }

                        MouseArea {
                            id: hsToggleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleHotspot()
                        }
                    }
                }
            }

            // SSID Input
            Column {
                width: parent.width
                spacing: 4

                Text {
                    text: "Ağ Adı (SSID)"
                    color: root.theme.textSecondary
                    font.family: root.theme.fontUi
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: root.theme.pillRadius
                    antialiasing: true
                    color: root.theme.glassPill

                    TextInput {
                        id: hotspotSsidInput
                        anchors {
                            fill: parent
                            leftMargin: 12
                            rightMargin: 12
                        }
                        verticalAlignment: TextInput.AlignVCenter
                        text: root.hotspotSsid
                        enabled: !root.hotspotActive
                        color: root.hotspotActive ? root.theme.textMuted : root.theme.textPrimary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeSm
                        clip: true
                        onTextChanged: root.hotspotSsid = text
                        Keys.onTabPressed: event => {
                            event.accepted = true;
                            hotspotPassInput.forceActiveFocus();
                        }
                        Keys.onEscapePressed: event => {
                            event.accepted = true;
                            keyScope.forceActiveFocus();
                        }
                    }
                }
            }

            // Password Input
            Column {
                width: parent.width
                spacing: 4

                Text {
                    text: "Şifre (en az 8 karakter, boş bırakılırsa otomatik)"
                    color: root.theme.textSecondary
                    font.family: root.theme.fontUi
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: root.theme.pillRadius
                    antialiasing: true
                    color: root.theme.glassPill

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: 12
                            rightMargin: 8
                        }
                        spacing: 6

                        Item {
                            width: parent.width - 28
                            height: parent.height

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Şifre girin (isteğe bağlı)..."
                                color: root.theme.textMuted
                                font.family: root.theme.fontUi
                                font.pixelSize: root.theme.fontSizeSm
                                visible: hotspotPassInput.text.length === 0
                                renderType: Text.NativeRendering
                            }

                            TextInput {
                                id: hotspotPassInput
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: root.showHotspotPassword ? TextInput.Normal : TextInput.Password
                                enabled: !root.hotspotActive
                                color: root.hotspotActive ? root.theme.textMuted : root.theme.textPrimary
                                font.family: root.theme.fontUi
                                font.pixelSize: root.theme.fontSizeSm
                                clip: true
                                onTextChanged: root.hotspotPassword = text
                                Keys.onReturnPressed: event => {
                                    event.accepted = true;
                                    keyScope.forceActiveFocus();
                                    root.toggleHotspot();
                                }
                                Keys.onEnterPressed: event => {
                                    event.accepted = true;
                                    keyScope.forceActiveFocus();
                                    root.toggleHotspot();
                                }
                                Keys.onEscapePressed: event => {
                                    event.accepted = true;
                                    keyScope.forceActiveFocus();
                                }
                            }
                        }

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 22
                            height: 22

                            Text {
                                anchors.centerIn: parent
                                text: root.showHotspotPassword ? "󰈉" : "󰈈"
                                color: eyeMouse.containsMouse ? root.theme.textPrimary : root.theme.textSecondary
                                font.family: root.theme.fontUi
                                font.pixelSize: root.theme.fontSizeMd
                                renderType: Text.NativeRendering
                            }

                            MouseArea {
                                id: eyeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showHotspotPassword = !root.showHotspotPassword
                            }
                        }
                    }
                }
            }
        }
    }
}
