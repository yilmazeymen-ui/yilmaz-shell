import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

// Bar-integrated Theme & Wallpaper Switcher rendered inside centerIsland's GlassSurface.
// Minimal horizontal strip inspired by my-shell's WallpaperView, tailored to Liquid Glass.
Item {
    id: root
    required property var theme
    property bool open: false
    property bool openedByKeyboard: false

    signal closeRequested()

    property int currentIndex: 0
    property var allThemes: []
    property bool keyboardNav: false
    property string activeTab: "wallpaper" // "wallpaper" | "theme"

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string activePath: root.theme.wallpaperPath
    readonly property string activeName: {
        const idx = activePath.lastIndexOf("/");
        return idx >= 0 ? activePath.slice(idx + 1) : activePath;
    }

    readonly property int cardWidth: 150
    readonly property int cardSpacing: 10

    function snapToActive() {
        for (let i = 0; i < root.allThemes.length; i++) {
            if (root.allThemes[i].full === root.activePath) {
                root.currentIndex = i;
                themeStrip.positionViewAtIndex(i, ListView.Center);
                return;
            }
        }
        if (root.allThemes.length > 0) {
            root.currentIndex = 0;
            themeStrip.positionViewAtBeginning();
        }
    }

    function glideTo(i) {
        const maxX = Math.max(0, themeStrip.contentWidth - themeStrip.width);
        const target = Math.max(0, Math.min(maxX, i * (root.cardWidth + root.cardSpacing) - (themeStrip.width - root.cardWidth) / 2));
        scrollAnim.to = target;
        scrollAnim.restart();
    }

    function moveSelection(delta) {
        const len = root.allThemes.length;
        if (len === 0)
            return;
        root.currentIndex = Math.max(0, Math.min(len - 1, root.currentIndex + delta));
        root.glideTo(root.currentIndex);
    }

    function applyTheme(item) {
        if (!item || !item.full)
            return;
        Quickshell.execDetached([root.home + "/.config/hypr/scripts/apply_theme.sh", item.full]);
    }

    function refreshList() {
        if (listProc.running)
            listProc.running = false;
        listProc.running = true;
    }

    onOpenChanged: {
        if (open) {
            keyboardNav = openedByKeyboard;
            if (allThemes.length > 0)
                snapToActive();
            refreshList();
            focusTimer.restart();
        } else {
            keyboardNav = false;
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

    // Keyboard navigation when menu is open
    Item {
        id: keyScope
        focus: root.open

        Keys.onPressed: event => {
            if (!root.open)
                return;
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                root.activeTab = (root.activeTab === "wallpaper") ? "theme" : "wallpaper";
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.closeRequested();
                event.accepted = true;
            } else if (root.activeTab === "wallpaper") {
                if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                    root.keyboardNav = true;
                    root.moveSelection(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                    root.keyboardNav = true;
                    root.moveSelection(1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.currentIndex >= 0 && root.currentIndex < root.allThemes.length)
                        root.applyTheme(root.allThemes[root.currentIndex]);
                    event.accepted = true;
                }
            }
        }
    }

    NumberAnimation {
        id: scrollAnim
        target: themeStrip
        property: "contentX"
        duration: root.theme.animNormal
        easing.type: Easing.OutCubic
    }

    Process {
        id: listProc
        command: [root.home + "/.config/hypr/scripts/list_wallpapers.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n");
                const parsed = [];
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    const tab = line.indexOf("\t");
                    if (tab <= 0)
                        continue;
                    const full = line.slice(0, tab);
                    const thumb = line.slice(tab + 1);
                    const slash = full.lastIndexOf("/");
                    const name = slash >= 0 ? full.slice(slash + 1) : full;
                    parsed.push({
                        full: full,
                        thumb: thumb,
                        name: name
                    });
                }
                root.allThemes = parsed;
                if (root.open)
                    root.snapToActive();
            }
        }
    }

    // ------------------------------------------------------------------
    // Minimal Header: Title + Current Theme Name
    // ------------------------------------------------------------------
    Item {
        id: headerRow
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            leftMargin: 4
            rightMargin: 4
        }
        height: 22

        Text {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            text: "Tema · Duvar Kağıdı"
            color: root.theme.textPrimary
            font.family: root.theme.fontUi
            font.pixelSize: root.theme.fontSizeMd
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }

        Text {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            width: Math.min(260, implicitWidth)
            text: root.activeName
            color: root.theme.textSecondary
            font.family: root.theme.fontUi
            font.pixelSize: root.theme.fontSizeSm
            elide: Text.ElideLeft
            renderType: Text.NativeRendering
        }
    }

    // ------------------------------------------------------------------
    // Section Tabs: Arkaplan | Tema
    // ------------------------------------------------------------------
    Rectangle {
        id: tabBar
        anchors {
            top: headerRow.bottom
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
                    { id: "wallpaper", label: "Arkaplan" },
                    { id: "theme", label: "Tema" }
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
                            : (themeTabMouse.containsMouse ? root.theme.glassPillHover : "transparent")

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
                        id: themeTabMouse
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
    // Horizontal Strip + Left/Right Chevrons (Arkaplan Tab)
    // ------------------------------------------------------------------
    Item {
        id: stripArea
        visible: root.activeTab === "wallpaper"
        anchors {
            top: tabBar.bottom
            topMargin: 10
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        Text {
            id: prevBtn
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: -10
            }
            width: 18
            horizontalAlignment: Text.AlignHCenter
            text: "‹"
            color: prevMouse.containsMouse ? root.theme.accent : root.theme.textSecondary
            font.family: root.theme.fontUi
            font.pixelSize: 22
            font.weight: Font.Bold
            renderType: Text.NativeRendering

            Behavior on color {
                ColorAnimation {
                    duration: root.theme.animFast
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                id: prevMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.moveSelection(-1)
            }
        }

        Text {
            id: nextBtn
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: -10
            }
            width: 18
            horizontalAlignment: Text.AlignHCenter
            text: "›"
            color: nextMouse.containsMouse ? root.theme.accent : root.theme.textSecondary
            font.family: root.theme.fontUi
            font.pixelSize: 22
            font.weight: Font.Bold
            renderType: Text.NativeRendering

            Behavior on color {
                ColorAnimation {
                    duration: root.theme.animFast
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                id: nextMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.moveSelection(1)
            }
        }

        ListView {
            id: themeStrip
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: prevBtn.right
                right: nextBtn.left
                leftMargin: 6
                rightMargin: 6
            }
            orientation: ListView.Horizontal
            spacing: root.cardSpacing
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.allThemes

            onMovementStarted: scrollAnim.stop()

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                onPositionChanged: root.keyboardNav = false
                onWheel: wheel => {
                    root.keyboardNav = false;
                    if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0)
                        root.moveSelection(-1);
                    else
                        root.moveSelection(1);
                }
            }

            delegate: Item {
                id: card
                required property var modelData
                required property int index

                readonly property bool isActive: modelData.full === root.activePath
                readonly property bool isSelected: root.keyboardNav && index === root.currentIndex
                readonly property bool hovering: !root.keyboardNav && cardMouse.containsMouse

                width: root.cardWidth
                height: themeStrip.height

                // Outer image wrapper (slight scale on hover, no Rectangle.border)
                Item {
                    id: imgWrap
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: 4
                        leftMargin: 3
                        rightMargin: 3
                    }
                    height: parent.height - 28
                    scale: card.hovering ? 1.04 : 1.0
                    transformOrigin: Item.Center

                    Behavior on scale {
                        NumberAnimation {
                            duration: root.theme.animFast
                            easing.type: Easing.OutCubic
                        }
                    }

                    // Active / selected highlight frame behind the rounded image
                    Rectangle {
                        anchors {
                            fill: parent
                            margins: -2
                        }
                        radius: 12
                        antialiasing: true
                        color: card.isActive ? root.theme.accent : (card.isSelected ? root.theme.rimTop : "transparent")

                        Behavior on color {
                            ColorAnimation {
                                duration: root.theme.animFast
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Image {
                        id: thumbImg
                        anchors.fill: parent
                        source: "file://" + card.modelData.thumb
                        asynchronous: true
                        sourceSize.width: 300
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }

                    Rectangle {
                        id: thumbMask
                        anchors.fill: parent
                        radius: 10
                        visible: false
                    }

                    OpacityMask {
                        anchors.fill: parent
                        source: thumbImg
                        maskSource: thumbMask
                    }
                }

                Text {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        leftMargin: 4
                        rightMargin: 4
                    }
                    text: card.modelData.name
                    color: card.isActive ? root.theme.accent : (card.isSelected ? root.theme.textPrimary : root.theme.textSecondary)
                    font.family: root.theme.fontUi
                    font.pixelSize: root.theme.fontSizeSm - 1
                    font.weight: card.isActive ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        if (!root.keyboardNav)
                            root.currentIndex = card.index;
                    }
                    onClicked: {
                        root.keyboardNav = false;
                        root.applyTheme(card.modelData);
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Theme Tab (Placeholder for upcoming theme options)
    // ------------------------------------------------------------------
    Item {
        id: themeTabArea
        visible: root.activeTab === "theme"
        anchors {
            top: tabBar.bottom
            topMargin: 10
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        Text {
            anchors.centerIn: parent
            text: "Tema ayarları yakında..."
            color: root.theme.textMuted
            font.family: root.theme.fontUi
            font.pixelSize: root.theme.fontSizeSm
            renderType: Text.NativeRendering
        }
    }
}
