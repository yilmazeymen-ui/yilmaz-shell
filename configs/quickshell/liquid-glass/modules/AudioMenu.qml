import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Bar-integrated Audio Control Menu rendered inside rightIsland's GlassSurface.
Item {
    id: root
    required property var theme
    property bool open: false
    property bool openedByKeyboard: false
    property bool keyboardNavActive: false

    signal closeRequested()

    property string activeTab: "sinks" // "streams" | "sinks" | "sources"
    property string focusSection: "masterOut" // "masterOut" | "masterIn" | "list"
    property int selectedListIndex: 0

    readonly property var tabOrder: ["sinks", "sources", "streams"]

    function currentListNodes() {
        if (activeTab === "sinks")
            return sinkNodes;
        if (activeTab === "sources")
            return sourceNodes;
        return streamNodes;
    }

    function currentListView() {
        if (activeTab === "sinks")
            return sinkList;
        if (activeTab === "sources")
            return sourceList;
        return streamList;
    }

    function cycleTab(delta) {
        const idx = tabOrder.indexOf(activeTab);
        const nextIdx = ((idx < 0 ? 0 : idx) + delta + tabOrder.length) % tabOrder.length;
        activeTab = tabOrder[nextIdx];
        selectedListIndex = 0;
        if (focusSection === "list" && currentListNodes().length === 0)
            focusSection = "masterOut";
    }

    function ensureVisible() {
        const lv = currentListView();
        if (lv && selectedListIndex >= 0 && selectedListIndex < lv.count)
            lv.positionViewAtIndex(selectedListIndex, ListView.Contain);
    }

    onActiveTabChanged: {
        selectedListIndex = 0;
    }

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    readonly property var sinkNodes: {
        const all = Pipewire.nodes.values;
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const n = all[i];
            if (n && !n.isStream && n.isSink && n.audio)
                out.push(n);
        }
        return out;
    }

    readonly property var sourceNodes: {
        const all = Pipewire.nodes.values;
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const n = all[i];
            if (!n || n.isStream || n.isSink || !n.audio)
                continue;
            const name = n.name || "";
            if (name.indexOf(".monitor") !== -1)
                continue;
            out.push(n);
        }
        return out;
    }

    readonly property var streamNodes: {
        const all = Pipewire.nodes.values;
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const n = all[i];
            if (n && n.isStream && n.isSink && n.audio)
                out.push(n);
        }
        return out;
    }

    function deviceLabel(node, fallback) {
        if (!node)
            return fallback;
        return node.description || node.nickname || (node.properties && node.properties["device.description"]) || node.name || fallback;
    }

    function streamLabel(node) {
        if (!node)
            return "Uygulama";
        const props = node.properties || {};
        return props["application.name"] || node.description || node.nickname || node.name || "Uygulama";
    }

    function streamSublabel(node) {
        if (!node || !node.properties)
            return "";
        const media = node.properties["media.name"] || "";
        const app = streamLabel(node);
        return (media.length > 0 && media !== app) ? media : "";
    }

    function sinkIcon(level, muted) {
        if (muted || level <= 0.001)
            return "";
        if (level < 0.5)
            return "";
        return "";
    }

    function sourceIcon(muted) {
        return muted ? "" : "";
    }

    function setNodeVolume(node, v) {
        if (!node || !node.audio)
            return;
        node.audio.volume = Math.max(0, Math.min(1, v));
        if (node.audio.muted)
            node.audio.muted = false;
    }

    function toggleNodeMute(node) {
        if (!node || !node.audio)
            return;
        node.audio.muted = !node.audio.muted;
    }

    onOpenChanged: {
        if (open) {
            if (streamNodes.length > 0 && activeTab !== "streams" && activeTab !== "sinks" && activeTab !== "sources")
                activeTab = "streams";
            focusSection = "masterOut";
            selectedListIndex = 0;
            keyboardNavActive = openedByKeyboard;
            focusTimer.restart();
        } else {
            keyboardNavActive = false;
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

    Item {
        id: keyScope
        focus: root.open

        Keys.onPressed: event => {
            if (!root.open)
                return;
            const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
            const nodes = root.currentListNodes();

            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                root.closeRequested();
            } else if (event.key === Qt.Key_Backtab) {
                root.keyboardNavActive = true;
                root.cycleTab(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                root.keyboardNavActive = true;
                root.cycleTab(shift ? -1 : 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                root.keyboardNavActive = true;
                if (root.focusSection === "list") {
                    if (root.selectedListIndex > 0) {
                        root.selectedListIndex--;
                        root.ensureVisible();
                    } else {
                        root.focusSection = "masterIn";
                    }
                } else if (root.focusSection === "masterIn") {
                    root.focusSection = "masterOut";
                } else if (nodes.length > 0) {
                    root.focusSection = "list";
                    root.selectedListIndex = nodes.length - 1;
                    root.ensureVisible();
                } else {
                    root.focusSection = "masterIn";
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                root.keyboardNavActive = true;
                if (root.focusSection === "masterOut") {
                    root.focusSection = "masterIn";
                } else if (root.focusSection === "masterIn") {
                    if (nodes.length > 0) {
                        root.focusSection = "list";
                        root.selectedListIndex = 0;
                        root.ensureVisible();
                    } else {
                        root.focusSection = "masterOut";
                    }
                } else {
                    if (root.selectedListIndex < nodes.length - 1) {
                        root.selectedListIndex++;
                        root.ensureVisible();
                    } else {
                        root.focusSection = "masterOut";
                    }
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                root.keyboardNavActive = true;
                const delta = (event.key === Qt.Key_Right || event.key === Qt.Key_L) ? 0.05 : -0.05;
                if (root.focusSection === "masterOut") {
                    const s = Pipewire.defaultAudioSink;
                    if (s && s.audio)
                        root.setNodeVolume(s, (isNaN(s.audio.volume) ? 0 : s.audio.volume) + delta);
                } else if (root.focusSection === "masterIn") {
                    const src = Pipewire.defaultAudioSource;
                    if (src && src.audio)
                        root.setNodeVolume(src, (isNaN(src.audio.volume) ? 0 : src.audio.volume) + delta);
                } else if (root.activeTab === "streams" && root.selectedListIndex >= 0 && root.selectedListIndex < nodes.length) {
                    const st = nodes[root.selectedListIndex];
                    if (st && st.audio)
                        root.setNodeVolume(st, (isNaN(st.audio.volume) ? 0 : st.audio.volume) + delta);
                } else {
                    root.cycleTab(delta > 0 ? 1 : -1);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (root.focusSection === "masterOut") {
                    root.toggleNodeMute(Pipewire.defaultAudioSink);
                } else if (root.focusSection === "masterIn") {
                    root.toggleNodeMute(Pipewire.defaultAudioSource);
                } else if (root.selectedListIndex >= 0 && root.selectedListIndex < nodes.length) {
                    const target = nodes[root.selectedListIndex];
                    if (root.activeTab === "sinks")
                        Pipewire.preferredDefaultAudioSink = target;
                    else if (root.activeTab === "sources")
                        Pipewire.preferredDefaultAudioSource = target;
                    else
                        root.toggleNodeMute(target);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_M) {
                if (root.focusSection === "masterOut")
                    root.toggleNodeMute(Pipewire.defaultAudioSink);
                else if (root.focusSection === "masterIn")
                    root.toggleNodeMute(Pipewire.defaultAudioSource);
                else if (root.activeTab === "streams" && root.selectedListIndex >= 0 && root.selectedListIndex < nodes.length)
                    root.toggleNodeMute(nodes[root.selectedListIndex]);
                event.accepted = true;
            }
        }
    }

    // Reusable compact Liquid Glass slider
    component VolumeSlider: Item {
        id: slider
        property real value: 0
        property bool muted: false
        property bool enabledControl: true
        signal moved(real newValue)

        implicitHeight: 18

        readonly property real clamped: Math.max(0, Math.min(1, value))
        readonly property bool activeHover: sliderMouse.containsMouse || sliderMouse.pressed

        Rectangle {
            id: track
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                right: parent.right
            }
            height: 6
            radius: 3
            antialiasing: true
            color: Qt.rgba(1, 1, 1, 0.12)

            Rectangle {
                width: Math.max(0, Math.min(parent.width, parent.width * slider.clamped))
                height: parent.height
                radius: parent.radius
                antialiasing: true
                color: !slider.enabledControl
                    ? root.theme.textMuted
                    : (slider.muted ? root.theme.warn : root.theme.accent)

                Behavior on color {
                    ColorAnimation {
                        duration: root.theme.animFast
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Rectangle {
            id: thumb
            visible: slider.enabledControl
            width: slider.activeHover ? 12 : 10
            height: width
            radius: width / 2
            antialiasing: true
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, slider.clamped * parent.width - width / 2))
            color: slider.muted ? root.theme.warn : root.theme.textPrimary

            Behavior on width {
                NumberAnimation {
                    duration: root.theme.animFast
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            id: sliderMouse
            anchors.fill: parent
            enabled: slider.enabledControl
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            preventStealing: true

            function updateFromX(mx) {
                if (width <= 0)
                    return;
                const ratio = Math.max(0, Math.min(1, mx / width));
                slider.moved(ratio);
            }

            onPressed: mouse => updateFromX(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    updateFromX(mouse.x);
            }
            onWheel: wheel => {
                const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                slider.moved(Math.max(0, Math.min(1, slider.clamped + delta)));
            }
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
            text: ""
            color: root.theme.accent
            font.family: root.theme.fontMono
            font.pixelSize: root.theme.fontSizeMd
            renderType: Text.NativeRendering
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 52
            text: "Ses Kontrolleri"
            color: root.theme.textPrimary
            font.family: root.theme.fontUi
            font.pixelSize: root.theme.fontSizeLg
            font.weight: Font.Medium
            renderType: Text.NativeRendering
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24

            Rectangle {
                anchors.fill: parent
                radius: 12
                antialiasing: true
                color: closeMouse.containsMouse ? root.theme.glassPillHover : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: root.theme.animFast
                        easing.type: Easing.OutCubic
                    }
                }
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
    // Master Output & Input Sliders
    // ------------------------------------------------------------------
    Column {
        id: masterCol
        anchors {
            top: headerRow.bottom
            topMargin: 10
            left: parent.left
            right: parent.right
        }
        spacing: 8

        // Default Output (Sink)
        Rectangle {
            id: outCard
            width: parent.width
            height: 58
            radius: root.theme.pillRadius
            antialiasing: true
            readonly property bool kbFocused: root.open && root.keyboardNavActive && root.focusSection === "masterOut"
            color: kbFocused ? root.theme.glassPillHover : root.theme.glassPill

            Rectangle {
                visible: outCard.kbFocused
                anchors {
                    left: parent.left
                    leftMargin: 3
                    verticalCenter: parent.verticalCenter
                }
                width: 3
                height: 30
                radius: 1.5
                color: root.theme.accent
            }

            readonly property var sink: Pipewire.defaultAudioSink
            readonly property real lvl: (sink && sink.audio && !isNaN(sink.audio.volume)) ? Math.max(0, Math.min(1, sink.audio.volume)) : 0
            readonly property bool isMuted: sink && sink.audio ? sink.audio.muted : false

            Column {
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                    topMargin: 8
                    bottomMargin: 8
                }
                spacing: 6

                Row {
                    width: parent.width
                    spacing: 8

                    Item {
                        width: 22
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            antialiasing: true
                            color: outMuteMouse.containsMouse ? root.theme.glassPillHover : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.sinkIcon(outCard.lvl, outCard.isMuted)
                            color: outCard.isMuted ? root.theme.warn : root.theme.accent
                            font.family: root.theme.fontMono
                            font.pixelSize: root.theme.fontSizeMd
                            renderType: Text.NativeRendering
                        }

                        MouseArea {
                            id: outMuteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleNodeMute(Pipewire.defaultAudioSink)
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 74
                        text: root.deviceLabel(Pipewire.defaultAudioSink, "Çıkış cihazı yok")
                        color: root.theme.textPrimary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeSm
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        horizontalAlignment: Text.AlignRight
                        text: `${Math.round(outCard.lvl * 100)}%`
                        color: outCard.isMuted ? root.theme.textMuted : root.theme.textSecondary
                        font.family: root.theme.fontMono
                        font.pixelSize: root.theme.fontSizeSm
                        font.features: { "tnum": 1 }
                        renderType: Text.NativeRendering
                    }
                }

                VolumeSlider {
                    width: parent.width
                    value: outCard.lvl
                    muted: outCard.isMuted
                    enabledControl: !!(Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio)
                    onMoved: newValue => root.setNodeVolume(Pipewire.defaultAudioSink, newValue)
                }
            }
        }

        // Default Input (Source / Microphone)
        Rectangle {
            id: inCard
            width: parent.width
            height: 58
            radius: root.theme.pillRadius
            antialiasing: true
            readonly property bool kbFocused: root.open && root.keyboardNavActive && root.focusSection === "masterIn"
            color: kbFocused ? root.theme.glassPillHover : root.theme.glassPill

            Rectangle {
                visible: inCard.kbFocused
                anchors {
                    left: parent.left
                    leftMargin: 3
                    verticalCenter: parent.verticalCenter
                }
                width: 3
                height: 30
                radius: 1.5
                color: root.theme.accent
            }

            readonly property var src: Pipewire.defaultAudioSource
            readonly property real lvl: (src && src.audio && !isNaN(src.audio.volume)) ? Math.max(0, Math.min(1, src.audio.volume)) : 0
            readonly property bool isMuted: src && src.audio ? src.audio.muted : false

            Column {
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                    topMargin: 8
                    bottomMargin: 8
                }
                spacing: 6

                Row {
                    width: parent.width
                    spacing: 8

                    Item {
                        width: 22
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            antialiasing: true
                            color: inMuteMouse.containsMouse ? root.theme.glassPillHover : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.sourceIcon(inCard.isMuted)
                            color: inCard.isMuted ? root.theme.warn : root.theme.accent
                            font.family: root.theme.fontMono
                            font.pixelSize: root.theme.fontSizeMd
                            renderType: Text.NativeRendering
                        }

                        MouseArea {
                            id: inMuteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleNodeMute(Pipewire.defaultAudioSource)
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 74
                        text: root.deviceLabel(Pipewire.defaultAudioSource, "Mikrofon yok")
                        color: root.theme.textPrimary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeSm
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        horizontalAlignment: Text.AlignRight
                        text: `${Math.round(inCard.lvl * 100)}%`
                        color: inCard.isMuted ? root.theme.textMuted : root.theme.textSecondary
                        font.family: root.theme.fontMono
                        font.pixelSize: root.theme.fontSizeSm
                        font.features: { "tnum": 1 }
                        renderType: Text.NativeRendering
                    }
                }

                VolumeSlider {
                    width: parent.width
                    value: inCard.lvl
                    muted: inCard.isMuted
                    enabledControl: !!(Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio)
                    onMoved: newValue => root.setNodeVolume(Pipewire.defaultAudioSource, newValue)
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Section Tabs: Çıkış | Giriş | Uygulamalar
    // ------------------------------------------------------------------
    Rectangle {
        id: tabBar
        anchors {
            top: masterCol.bottom
            topMargin: 10
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
                    { id: "sinks", label: "Çıkış" },
                    { id: "sources", label: "Giriş" },
                    { id: "streams", label: `Uygulamalar (${root.streamNodes.length})` }
                ]

                delegate: Item {
                    required property var modelData
                    readonly property bool selected: root.activeTab === modelData.id

                    width: (tabBar.width - 14) / 3
                    height: tabBar.height - 6

                    Rectangle {
                        anchors.fill: parent
                        radius: root.theme.pillRadius - 2
                        antialiasing: true
                        color: parent.selected
                            ? root.theme.glassPillActive
                            : (tabMouse.containsMouse ? root.theme.glassPillHover : "transparent")

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
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: tabMouse
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
    // Tab Content Lists
    // ------------------------------------------------------------------
    Item {
        anchors {
            top: tabBar.bottom
            topMargin: 8
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        // Output Devices List
        ListView {
            id: sinkList
            anchors.fill: parent
            visible: root.activeTab === "sinks"
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: root.sinkNodes

            delegate: Item {
                id: sinkDelegate
                required property var modelData
                required property int index
                readonly property bool isDefault: Pipewire.defaultAudioSink === modelData
                readonly property bool kbFocused: root.open && root.keyboardNavActive && root.focusSection === "list" && root.activeTab === "sinks" && root.selectedListIndex === index

                width: sinkList.width
                height: 40

                Rectangle {
                    anchors.fill: parent
                    radius: root.theme.pillRadius
                    antialiasing: true
                    color: sinkDelegate.isDefault
                        ? root.theme.glassPillActive
                        : ((sinkItemMouse.containsMouse || sinkDelegate.kbFocused) ? root.theme.glassPillHover : "transparent")

                    Behavior on color {
                        ColorAnimation {
                            duration: root.theme.animFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Rectangle {
                    visible: sinkDelegate.kbFocused
                    anchors {
                        left: parent.left
                        leftMargin: 3
                        verticalCenter: parent.verticalCenter
                    }
                    width: 3
                    height: 20
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
                        text: parent.parent.isDefault ? "󰄬" : "󰓃"
                        color: parent.parent.isDefault ? root.theme.accent : root.theme.textSecondary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeMd
                        renderType: Text.NativeRendering
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 26
                        text: root.deviceLabel(modelData, "Çıkış Cihazı")
                        color: parent.parent.isDefault ? root.theme.textPrimary : root.theme.textSecondary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeSm
                        font.weight: parent.parent.isDefault ? Font.Medium : Font.Normal
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }

                MouseArea {
                    id: sinkItemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                }
            }

            Text {
                anchors.centerIn: parent
                visible: sinkList.count === 0
                text: "Çıkış cihazı bulunamadı"
                color: root.theme.textMuted
                font.family: root.theme.fontUi
                font.pixelSize: root.theme.fontSizeMd
                renderType: Text.NativeRendering
            }
        }

        // Input Devices List
        ListView {
            id: sourceList
            anchors.fill: parent
            visible: root.activeTab === "sources"
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: root.sourceNodes

            delegate: Item {
                id: srcDelegate
                required property var modelData
                required property int index
                readonly property bool isDefault: Pipewire.defaultAudioSource === modelData
                readonly property bool kbFocused: root.open && root.keyboardNavActive && root.focusSection === "list" && root.activeTab === "sources" && root.selectedListIndex === index

                width: sourceList.width
                height: 40

                Rectangle {
                    anchors.fill: parent
                    radius: root.theme.pillRadius
                    antialiasing: true
                    color: srcDelegate.isDefault
                        ? root.theme.glassPillActive
                        : ((srcItemMouse.containsMouse || srcDelegate.kbFocused) ? root.theme.glassPillHover : "transparent")

                    Behavior on color {
                        ColorAnimation {
                            duration: root.theme.animFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Rectangle {
                    visible: srcDelegate.kbFocused
                    anchors {
                        left: parent.left
                        leftMargin: 3
                        verticalCenter: parent.verticalCenter
                    }
                    width: 3
                    height: 20
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
                        text: parent.parent.isDefault ? "󰄬" : ""
                        color: parent.parent.isDefault ? root.theme.accent : root.theme.textSecondary
                        font.family: root.theme.fontMono
                        font.pixelSize: root.theme.fontSizeMd
                        renderType: Text.NativeRendering
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 26
                        text: root.deviceLabel(modelData, "Giriş Cihazı")
                        color: parent.parent.isDefault ? root.theme.textPrimary : root.theme.textSecondary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeSm
                        font.weight: parent.parent.isDefault ? Font.Medium : Font.Normal
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }

                MouseArea {
                    id: srcItemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pipewire.preferredDefaultAudioSource = modelData
                }
            }

            Text {
                anchors.centerIn: parent
                visible: sourceList.count === 0
                text: "Giriş cihazı bulunamadı"
                color: root.theme.textMuted
                font.family: root.theme.fontUi
                font.pixelSize: root.theme.fontSizeMd
                renderType: Text.NativeRendering
            }
        }

        // Application Streams List
        ListView {
            id: streamList
            anchors.fill: parent
            visible: root.activeTab === "streams"
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: root.streamNodes

            delegate: Rectangle {
                id: streamCard
                required property var modelData
                required property int index
                readonly property real lvl: (modelData && modelData.audio && !isNaN(modelData.audio.volume)) ? Math.max(0, Math.min(1, modelData.audio.volume)) : 0
                readonly property bool isMuted: modelData && modelData.audio ? modelData.audio.muted : false
                readonly property string sub: root.streamSublabel(modelData)
                readonly property bool kbFocused: root.open && root.keyboardNavActive && root.focusSection === "list" && root.activeTab === "streams" && root.selectedListIndex === index

                width: streamList.width
                height: sub.length > 0 ? 64 : 52
                radius: root.theme.pillRadius
                antialiasing: true
                color: kbFocused ? root.theme.glassPillHover : root.theme.glassPill

                Rectangle {
                    visible: streamCard.kbFocused
                    anchors {
                        left: parent.left
                        leftMargin: 3
                        verticalCenter: parent.verticalCenter
                    }
                    width: 3
                    height: 26
                    radius: 1.5
                    color: root.theme.accent
                }

                Column {
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 12
                        topMargin: 7
                        bottomMargin: 7
                    }
                    spacing: 4

                    Row {
                        width: parent.width
                        spacing: 8

                        Item {
                            width: 20
                            height: 18
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                anchors.fill: parent
                                radius: 9
                                antialiasing: true
                                color: stMuteMouse.containsMouse ? root.theme.glassPillHover : "transparent"
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.sinkIcon(streamCard.lvl, streamCard.isMuted)
                                color: streamCard.isMuted ? root.theme.warn : root.theme.accent
                                font.family: root.theme.fontMono
                                font.pixelSize: root.theme.fontSizeSm
                                renderType: Text.NativeRendering
                            }

                            MouseArea {
                                id: stMuteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleNodeMute(modelData)
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 72
                            text: root.streamLabel(modelData)
                            color: root.theme.textPrimary
                            font.family: root.theme.fontUi
                            font.pixelSize: root.theme.fontSizeSm
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36
                            horizontalAlignment: Text.AlignRight
                            text: `${Math.round(streamCard.lvl * 100)}%`
                            color: streamCard.isMuted ? root.theme.textMuted : root.theme.textSecondary
                            font.family: root.theme.fontMono
                            font.pixelSize: root.theme.fontSizeSm
                            font.features: { "tnum": 1 }
                            renderType: Text.NativeRendering
                        }
                    }

                    Text {
                        visible: streamCard.sub.length > 0
                        width: parent.width
                        text: streamCard.sub
                        color: root.theme.textMuted
                        font.family: root.theme.fontUi
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    VolumeSlider {
                        width: parent.width
                        value: streamCard.lvl
                        muted: streamCard.isMuted
                        enabledControl: !!(modelData && modelData.audio)
                        onMoved: newValue => root.setNodeVolume(modelData, newValue)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: streamList.count === 0
                text: "Aktif ses akışı yok"
                color: root.theme.textMuted
                font.family: root.theme.fontUi
                font.pixelSize: root.theme.fontSizeMd
                renderType: Text.NativeRendering
            }
        }
    }
}
