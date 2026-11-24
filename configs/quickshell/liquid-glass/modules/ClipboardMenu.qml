import QtQuick
import Quickshell
import Quickshell.Io

// Bar-integrated Clipboard History menu rendered inside centerIsland's GlassSurface.
// Left pane: compact searchable list (elided text & image labels).
// Right pane: full text or image preview for the currently selected item.
Item {
    id: root
    required property var theme
    property bool open: false
    property bool openedByKeyboard: false
    property bool keyboardNavActive: false

    signal closeRequested()

    property string query: ""
    property int currentIndex: 0
    property var allItems: []

    // Preview state for the currently selected item
    property string previewItemId: ""
    property string previewMode: "empty" // "empty" | "text" | "image" | "binary"
    property string previewText: ""
    property string previewImageUrl: ""
    property string previewMeta: ""
    property bool previewLoading: false

    readonly property string cacheDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/liquid-glass-clip"

    readonly property var filteredItems: {
        const q = root.query.trim().toLowerCase();
        if (q.length === 0)
            return root.allItems;
        const result = [];
        for (let i = 0; i < root.allItems.length; i++) {
            const item = root.allItems[i];
            if (item.searchText.indexOf(q) !== -1)
                result.push(item);
        }
        return result;
    }

    readonly property var currentItem: (currentIndex >= 0 && currentIndex < filteredItems.length)
        ? filteredItems[currentIndex]
        : null

    // Show the right preview pane only for images, binary entries, or long/multi-line text
    readonly property bool showPreview: {
        if (!root.open || !root.currentItem)
            return false;
        if (root.currentItem.isImage || root.currentItem.isBinary)
            return true;
        if (root.previewMode === "text" && !root.previewLoading)
            return root.previewText.indexOf("\n") !== -1 || root.previewText.length > 50;
        return false;
    }

    function parseCliphistLine(line) {
        const tabIdx = line.indexOf("\t");
        if (tabIdx <= 0)
            return null;

        const id = line.slice(0, tabIdx).trim();
        const raw = line.slice(tabIdx + 1);
        if (!id)
            return null;

        const binMatch = raw.match(/^\[\[\s*binary data\s+(.+?)\s*\]\]$/i);
        if (binMatch) {
            const info = binMatch[1].trim();
            const tokens = info.split(/\s+/);
            const imgExts = ["png", "jpg", "jpeg", "webp", "gif", "bmp", "tiff", "ico", "svg", "avif"];
            let ext = "";
            let dims = "";
            const sizeParts = [];

            for (let i = 0; i < tokens.length; i++) {
                const tok = tokens[i];
                const low = tok.toLowerCase();
                if (!ext && imgExts.indexOf(low) !== -1) {
                    ext = low;
                } else if (!dims && /^\d+x\d+$/i.test(tok)) {
                    dims = tok.replace("x", "×");
                } else {
                    sizeParts.push(tok);
                }
            }

            const sizeStr = sizeParts.join(" ");
            if (ext) {
                const extUpper = ext.toUpperCase();
                const title = dims ? ("Görsel · " + extUpper + " (" + dims + ")") : ("Görsel · " + extUpper);
                return {
                    id: id,
                    isBinary: true,
                    isImage: true,
                    imageExt: ext,
                    displayName: title,
                    subtitle: sizeStr,
                    meta: [extUpper, dims, sizeStr].filter(Boolean).join(" · "),
                    searchText: (title + " " + sizeStr + " görsel image " + ext).toLowerCase()
                };
            }

            return {
                id: id,
                isBinary: true,
                isImage: false,
                imageExt: "",
                displayName: "İkili Veri",
                subtitle: info,
                meta: info,
                searchText: ("ikili binary " + info).toLowerCase()
            };
        }

        const compact = raw.replace(/\s+/g, " ").trim();
        return {
            id: id,
            isBinary: false,
            isImage: false,
            imageExt: "",
            displayName: compact.length > 0 ? compact : "(Boş metin)",
            subtitle: "",
            meta: "Metin",
            searchText: raw.toLowerCase()
        };
    }

    function refreshList() {
        listProc.running = false;
        listProc.running = true;
    }

    function loadPreviewForCurrent() {
        const item = root.currentItem;
        if (!root.open || !item) {
            root.previewItemId = "";
            root.previewMode = "empty";
            root.previewText = "";
            root.previewImageUrl = "";
            root.previewMeta = "";
            root.previewLoading = false;
            return;
        }

        root.previewItemId = item.id;
        root.previewMeta = item.meta;

        if (item.isImage) {
            root.previewMode = "image";
            root.previewText = "";
            root.previewImageUrl = "";
            root.previewLoading = true;
            const outPath = root.cacheDir + "/" + item.id + "." + item.imageExt;
            imgDecodeProc.running = false;
            imgDecodeProc.targetId = item.id;
            imgDecodeProc.targetPath = outPath;
            imgDecodeProc.command = ["sh", "-c", "mkdir -p \"$1\" && cliphist decode \"$2\" > \"$3\"", "_", root.cacheDir, item.id, outPath];
            imgDecodeProc.running = true;
        } else if (item.isBinary) {
            root.previewMode = "binary";
            root.previewText = "";
            root.previewImageUrl = "";
            root.previewLoading = false;
        } else {
            root.previewMode = "text";
            root.previewImageUrl = "";
            root.previewText = "";
            root.previewLoading = true;
            textDecodeProc.running = false;
            textDecodeProc.targetId = item.id;
            textDecodeProc.command = ["cliphist", "decode", item.id];
            textDecodeProc.running = true;
        }
    }

    function copyAndClose(item) {
        if (!item)
            return;
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "_", item.id]);
        root.closeRequested();
    }

    function deleteItem(item) {
        if (!item)
            return;
        deleteProc.running = false;
        deleteProc.command = ["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "_", item.id + "\t"];
        deleteProc.running = true;
    }

    function wipeClipboard() {
        if (root.allItems.length === 0)
            return;
        wipeProc.running = false;
        wipeProc.running = true;
    }

    onOpenChanged: {
        if (open) {
            query = "";
            searchInput.text = "";
            currentIndex = 0;
            keyboardNavActive = openedByKeyboard;
            clipList.positionViewAtBeginning();
            refreshList();
            loadPreviewForCurrent();
            focusTimer.restart();
        } else {
            keyboardNavActive = false;
            textDecodeProc.running = false;
            imgDecodeProc.running = false;
            previewItemId = "";
            previewMode = "empty";
            previewText = "";
            previewImageUrl = "";
            previewLoading = false;
            Quickshell.execDetached(["rm", "-rf", root.cacheDir]);
        }
    }

    onFilteredItemsChanged: {
        if (currentIndex >= filteredItems.length)
            currentIndex = Math.max(0, filteredItems.length - 1);
    }

    onCurrentItemChanged: {
        loadPreviewForCurrent();
    }

    Timer {
        id: focusTimer
        interval: 20
        onTriggered: {
            if (root.open)
                searchInput.forceActiveFocus();
        }
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                const lines = data.split("\n");
                const parsed = [];
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    if (!line)
                        continue;
                    const item = root.parseCliphistLine(line);
                    if (item)
                        parsed.push(item);
                }
                root.allItems = parsed;
            }
        }
    }

    Process {
        id: textDecodeProc
        property string targetId: ""
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                if (root.previewItemId !== textDecodeProc.targetId)
                    return;
                root.previewText = data;
                root.previewLoading = false;
                previewFlickable.contentY = 0;
            }
        }
        onExited: exitCode => {
            if (root.previewItemId === textDecodeProc.targetId && exitCode !== 0)
                root.previewLoading = false;
        }
    }

    Process {
        id: imgDecodeProc
        property string targetId: ""
        property string targetPath: ""
        onExited: exitCode => {
            if (root.previewItemId !== imgDecodeProc.targetId)
                return;
            if (exitCode === 0)
                root.previewImageUrl = "file://" + imgDecodeProc.targetPath;
            root.previewLoading = false;
        }
    }

    Process {
        id: deleteProc
        onExited: exitCode => {
            if (exitCode === 0 && root.open)
                root.refreshList();
        }
    }

    Process {
        id: wipeProc
        command: ["sh", "-c", "cliphist wipe && wl-copy --clear"]
        onExited: exitCode => {
            if (exitCode === 0) {
                root.allItems = [];
                root.currentIndex = 0;
                root.loadPreviewForCurrent();
                Quickshell.execDetached(["rm", "-rf", root.cacheDir]);
            }
        }
    }

    // ------------------------------------------------------------------
    // Search Header + Wipe Button
    // ------------------------------------------------------------------
    Rectangle {
        id: searchBox
        anchors {
            top: parent.top
            left: parent.left
            right: wipeBtn.left
            rightMargin: 8
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
                text: "󰅌"
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
                    text: "Panoda ara..."
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
                        clipList.positionViewAtBeginning();
                    }

                    Keys.onEscapePressed: event => {
                        event.accepted = true;
                        root.closeRequested();
                    }

                    Keys.onUpPressed: event => {
                        event.accepted = true;
                        root.keyboardNavActive = true;
                        if (root.filteredItems.length > 0) {
                            root.currentIndex = Math.max(0, root.currentIndex - 1);
                            clipList.positionViewAtIndex(root.currentIndex, ListView.Contain);
                        }
                    }

                    Keys.onDownPressed: event => {
                        event.accepted = true;
                        root.keyboardNavActive = true;
                        if (root.filteredItems.length > 0) {
                            root.currentIndex = Math.min(root.filteredItems.length - 1, root.currentIndex + 1);
                            clipList.positionViewAtIndex(root.currentIndex, ListView.Contain);
                        }
                    }

                    Keys.onReturnPressed: event => {
                        event.accepted = true;
                        if (root.currentItem)
                            root.copyAndClose(root.currentItem);
                    }

                    Keys.onEnterPressed: event => {
                        event.accepted = true;
                        if (root.currentItem)
                            root.copyAndClose(root.currentItem);
                    }

                    Keys.onDeletePressed: event => {
                        event.accepted = true;
                        if (root.currentItem)
                            root.deleteItem(root.currentItem);
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

    Rectangle {
        id: wipeBtn
        anchors {
            top: parent.top
            right: parent.right
        }
        width: root.theme.evenPx(wipeRow.implicitWidth + 20)
        height: 34
        radius: root.theme.pillRadius
        antialiasing: true
        color: (wipeMouse.containsMouse && root.allItems.length > 0) ? root.theme.glassPillHover : root.theme.glassPill
        opacity: root.allItems.length > 0 ? 1.0 : 0.45

        Behavior on color {
            ColorAnimation {
                duration: root.theme.animFast
                easing.type: Easing.OutCubic
            }
        }

        Row {
            id: wipeRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰃢"
                color: (wipeMouse.containsMouse && root.allItems.length > 0) ? root.theme.warn : root.theme.textSecondary
                font.family: root.theme.fontUi
                font.pixelSize: root.theme.fontSizeMd
                renderType: Text.NativeRendering
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Temizle"
                color: (wipeMouse.containsMouse && root.allItems.length > 0) ? root.theme.warn : root.theme.textSecondary
                font.family: root.theme.fontUi
                font.pixelSize: root.theme.fontSizeSm
                font.weight: Font.Medium
                renderType: Text.NativeRendering
            }
        }

        MouseArea {
            id: wipeMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.allItems.length > 0
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                root.wipeClipboard();
                searchInput.forceActiveFocus();
            }
        }
    }

    // ------------------------------------------------------------------
    // Two-Pane Body: Left List + Right Preview
    // ------------------------------------------------------------------
    Item {
        id: bodyArea
        anchors {
            top: searchBox.bottom
            topMargin: 8
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        // Left Pane: Clipboard Entries
        ListView {
            id: clipList
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            width: root.showPreview ? Math.floor(parent.width * 0.44) : parent.width
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: root.filteredItems

            delegate: Item {
                id: rowItem
                required property var modelData
                required property int index

                readonly property bool isSelected: root.keyboardNavActive && index === root.currentIndex

                width: clipList.width
                height: 38

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
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: rowItem.modelData.isImage ? "󰋩" : (rowItem.modelData.isBinary ? "󰈔" : "󰈙")
                        color: rowItem.isSelected ? root.theme.accent : root.theme.textSecondary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeLg
                        renderType: Text.NativeRendering
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24
                        spacing: 1

                        Text {
                            width: parent.width
                            text: rowItem.modelData.displayName
                            textFormat: Text.PlainText
                            color: root.theme.textPrimary
                            font.family: root.theme.fontUi
                            font.pixelSize: root.theme.fontSizeMd
                            font.weight: rowItem.isSelected ? Font.DemiBold : Font.Medium
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            renderType: Text.NativeRendering
                        }

                        Text {
                            visible: rowItem.modelData.subtitle.length > 0
                            width: parent.width
                            text: rowItem.modelData.subtitle
                            color: root.theme.textSecondary
                            font.family: root.theme.fontUi
                            font.pixelSize: root.theme.fontSizeSm - 1
                            elide: Text.ElideRight
                            maximumLineCount: 1
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
                    onClicked: root.copyAndClose(rowItem.modelData)
                }

                Item {
                    id: rowDeleteBtn
                    visible: !root.showPreview && (rowItem.isSelected || rowMouse.containsMouse || rowDeleteMouse.containsMouse)
                    anchors {
                        verticalCenter: parent.verticalCenter
                        right: parent.right
                        rightMargin: 8
                    }
                    width: 22
                    height: 22

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        antialiasing: true
                        color: rowDeleteMouse.containsMouse ? root.theme.glassPillHover : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰆴"
                        color: rowDeleteMouse.containsMouse ? root.theme.warn : root.theme.textSecondary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeMd
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: rowDeleteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.deleteItem(rowItem.modelData);
                            searchInput.forceActiveFocus();
                        }
                    }
                }
            }
        }

        // Empty list state
        Text {
            anchors.centerIn: clipList
            visible: root.filteredItems.length === 0
            text: root.allItems.length === 0 ? "Pano boş" : "Sonuç bulunamadı"
            color: root.theme.textMuted
            font.family: root.theme.fontUi
            font.pixelSize: root.theme.fontSizeMd
            renderType: Text.NativeRendering
        }

        // Vertical Divider
        Rectangle {
            id: paneDivider
            visible: root.showPreview
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: clipList.right
                leftMargin: 8
            }
            width: 1
            color: Qt.rgba(1, 1, 1, 0.14)
        }

        // Right Pane: Full Text or Image Preview
        Rectangle {
            id: previewPane
            visible: root.showPreview
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: paneDivider.right
                leftMargin: 8
                right: parent.right
            }
            radius: root.theme.pillRadius
            antialiasing: true
            color: root.theme.glassPill

            // Preview Header (metadata + delete action)
            Item {
                id: previewHeader
                visible: root.currentItem !== null
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 10
                }
                height: 22

                Text {
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                        right: deleteBtn.left
                        rightMargin: 8
                    }
                    text: {
                        if (root.previewMode === "text" && !root.previewLoading)
                            return "Metin · " + root.previewText.length + " karakter";
                        return root.previewMeta;
                    }
                    color: root.theme.textSecondary
                    font.family: root.theme.fontUi
                    font.pixelSize: root.theme.fontSizeSm - 1
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                Item {
                    id: deleteBtn
                    anchors {
                        verticalCenter: parent.verticalCenter
                        right: parent.right
                    }
                    width: 22
                    height: 22

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        antialiasing: true
                        color: deleteMouse.containsMouse ? root.theme.glassPillHover : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰆴"
                        color: deleteMouse.containsMouse ? root.theme.warn : root.theme.textSecondary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeMd
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: deleteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.currentItem)
                                root.deleteItem(root.currentItem);
                        }
                    }
                }
            }

            Rectangle {
                id: headerDivider
                visible: root.currentItem !== null
                anchors {
                    top: previewHeader.bottom
                    topMargin: 6
                    left: parent.left
                    right: parent.right
                    leftMargin: 10
                    rightMargin: 10
                }
                height: 1
                color: Qt.rgba(1, 1, 1, 0.10)
            }

            // Preview Content Area
            Item {
                anchors {
                    top: headerDivider.bottom
                    topMargin: 8
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    leftMargin: 10
                    rightMargin: 10
                    bottomMargin: 10
                }

                // Full text preview
                Flickable {
                    id: previewFlickable
                    anchors.fill: parent
                    visible: root.previewMode === "text" && !root.previewLoading
                    clip: true
                    contentWidth: width
                    contentHeight: fullTextItem.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Text {
                        id: fullTextItem
                        width: previewFlickable.width
                        text: root.previewText
                        textFormat: Text.PlainText
                        color: root.theme.textPrimary
                        font.family: root.theme.fontMono
                        font.pixelSize: root.theme.fontSizeSm
                        wrapMode: Text.WrapAnywhere
                        renderType: Text.NativeRendering
                    }
                }

                // Image preview
                Image {
                    anchors.fill: parent
                    visible: root.previewMode === "image" && root.previewImageUrl.length > 0
                    source: root.previewImageUrl
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    cache: false
                }

                // Binary non-image fallback
                Text {
                    anchors.centerIn: parent
                    visible: root.previewMode === "binary"
                    text: "Bu veri türü için ön izleme desteklenmiyor"
                    color: root.theme.textMuted
                    font.family: root.theme.fontUi
                    font.pixelSize: root.theme.fontSizeSm
                    renderType: Text.NativeRendering
                }

                // Empty or loading state
                Text {
                    anchors.centerIn: parent
                    visible: root.previewLoading || root.previewMode === "empty"
                    text: root.previewLoading ? "Yükleniyor..." : "Ön izleme yok"
                    color: root.theme.textMuted
                    font.family: root.theme.fontUi
                    font.pixelSize: root.theme.fontSizeSm
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
