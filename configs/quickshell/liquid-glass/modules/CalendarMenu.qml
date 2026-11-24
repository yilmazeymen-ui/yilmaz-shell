import QtQuick
import Quickshell

// Bar-integrated Monthly Calendar rendered inside centerIsland's GlassSurface.
Item {
    id: root
    required property var theme
    property bool open: false
    property bool openedByKeyboard: false

    signal closeRequested()

    readonly property var monthNames: [
        "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
        "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"
    ]
    readonly property var weekdayShort: ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
    readonly property var weekdayFull: [
        "Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"
    ]

    SystemClock {
        id: clock
        precision: root.open ? SystemClock.Seconds : SystemClock.Minutes
    }

    readonly property int todayYear: clock.date.getFullYear()
    readonly property int todayMonth: clock.date.getMonth()
    readonly property int todayDay: clock.date.getDate()

    property int viewYear: todayYear
    property int viewMonth: todayMonth

    readonly property bool isCurrentMonth: viewYear === todayYear && viewMonth === todayMonth

    function goToday() {
        viewYear = todayYear;
        viewMonth = todayMonth;
    }

    function stepMonth(delta) {
        let m = viewMonth + delta;
        let y = viewYear;
        while (m < 0) {
            m += 12;
            y -= 1;
        }
        while (m > 11) {
            m -= 12;
            y += 1;
        }
        viewYear = y;
        viewMonth = m;
    }

    readonly property var dayCells: {
        const firstOfMonth = new Date(root.viewYear, root.viewMonth, 1);
        const startOffset = (firstOfMonth.getDay() + 6) % 7; // Monday = 0
        const daysInMonth = new Date(root.viewYear, root.viewMonth + 1, 0).getDate();
        const daysInPrevMonth = new Date(root.viewYear, root.viewMonth, 0).getDate();

        const cells = [];
        for (let i = 0; i < 42; i++) {
            const idx = i - startOffset;
            let dayNum = 0;
            let inCurrent = false;
            let monthDelta = 0;

            if (idx < 0) {
                dayNum = daysInPrevMonth + idx + 1;
                monthDelta = -1;
            } else if (idx >= daysInMonth) {
                dayNum = idx - daysInMonth + 1;
                monthDelta = 1;
            } else {
                dayNum = idx + 1;
                inCurrent = true;
            }

            const isToday = inCurrent
                && root.viewYear === root.todayYear
                && root.viewMonth === root.todayMonth
                && dayNum === root.todayDay;
            const col = i % 7;
            const isWeekend = col >= 5;

            cells.push({
                day: dayNum,
                inCurrent: inCurrent,
                monthDelta: monthDelta,
                isToday: isToday,
                isWeekend: isWeekend
            });
        }
        return cells;
    }

    onOpenChanged: {
        if (open) {
            goToday();
            focusTimer.restart();
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
            if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_PageUp) {
                root.stepMonth(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_PageDown) {
                root.stepMonth(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_T || event.key === Qt.Key_Home) {
                root.goToday();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.closeRequested();
                event.accepted = true;
            }
        }
    }

    Column {
        anchors.fill: parent
        spacing: 8

        // --------------------------------------------------------------
        // Header: Month/Year title + Today pill + Prev/Next navigation
        // --------------------------------------------------------------
        Item {
            width: parent.width
            height: 30

            Row {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.monthNames[root.viewMonth] + " " + root.viewYear
                    color: root.theme.textPrimary
                    font.family: root.theme.fontUi
                    font.pixelSize: root.theme.fontSizeLg
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    renderType: Text.NativeRendering
                }

                // Quick return to current month when browsing other months
                Item {
                    visible: !root.isCurrentMonth
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.theme.evenPx(todayBtnLabel.implicitWidth + 16)
                    height: 22

                    Rectangle {
                        anchors.fill: parent
                        radius: 11
                        antialiasing: true
                        color: todayBtnMouse.containsMouse ? root.theme.glassPillHover : root.theme.glassPill

                        Behavior on color {
                            ColorAnimation {
                                duration: root.theme.animFast
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Text {
                        id: todayBtnLabel
                        anchors.centerIn: parent
                        text: "Bugün"
                        color: root.theme.accent
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeSm
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: todayBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.goToday()
                    }
                }
            }

            Row {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                spacing: 4

                Item {
                    width: 28
                    height: 28

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        antialiasing: true
                        color: prevMouse.containsMouse ? root.theme.glassPillHover : root.theme.glassPill

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
                        color: prevMouse.containsMouse ? root.theme.accent : root.theme.textPrimary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeLg
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stepMonth(-1)
                    }
                }

                Item {
                    width: 28
                    height: 28

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        antialiasing: true
                        color: nextMouse.containsMouse ? root.theme.glassPillHover : root.theme.glassPill

                        Behavior on color {
                            ColorAnimation {
                                duration: root.theme.animFast
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅂"
                        color: nextMouse.containsMouse ? root.theme.accent : root.theme.textPrimary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeLg
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stepMonth(1)
                    }
                }
            }
        }

        // --------------------------------------------------------------
        // Weekday Header Row (Monday-first)
        // --------------------------------------------------------------
        Grid {
            width: parent.width
            columns: 7
            columnSpacing: 2

            Repeater {
                model: root.weekdayShort

                Item {
                    required property int index
                    required property string modelData
                    width: Math.floor((parent.width - 12) / 7)
                    height: 22

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: index >= 5 ? root.theme.textMuted : root.theme.textSecondary
                        font.family: root.theme.fontUi
                        font.pixelSize: root.theme.fontSizeSm
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }
                }
            }
        }

        // --------------------------------------------------------------
        // 6x7 Day Grid
        // --------------------------------------------------------------
        Grid {
            width: parent.width
            columns: 7
            columnSpacing: 2
            rowSpacing: 2

            Repeater {
                model: root.dayCells

                Item {
                    id: dayCell
                    required property var modelData
                    width: Math.floor((parent.width - 12) / 7)
                    height: 34

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        antialiasing: true
                        color: dayCell.modelData.isToday
                            ? root.theme.glassPillActive
                            : (dayMouse.containsMouse ? root.theme.glassPillHover : "transparent")

                        Behavior on color {
                            ColorAnimation {
                                duration: root.theme.animFast
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    // Subtle accent dot under today's date
                    Rectangle {
                        visible: dayCell.modelData.isToday
                        anchors {
                            bottom: parent.bottom
                            bottomMargin: 4
                            horizontalCenter: parent.horizontalCenter
                        }
                        width: 4
                        height: 4
                        radius: 2
                        color: root.theme.accent
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: dayCell.modelData.isToday ? -2 : 0
                        text: dayCell.modelData.day
                        color: {
                            if (dayCell.modelData.isToday)
                                return root.theme.accent;
                            if (!dayCell.modelData.inCurrent)
                                return root.theme.textMuted;
                            return dayCell.modelData.isWeekend ? root.theme.textSecondary : root.theme.textPrimary;
                        }
                        font.family: root.theme.fontMono
                        font.pixelSize: root.theme.fontSizeMd
                        font.weight: dayCell.modelData.isToday ? Font.DemiBold : Font.Normal
                        font.features: { "tnum": 1 }
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        id: dayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: dayCell.modelData.monthDelta !== 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (dayCell.modelData.monthDelta !== 0)
                                root.stepMonth(dayCell.modelData.monthDelta);
                        }
                    }
                }
            }
        }

        // --------------------------------------------------------------
        // Footer: Full date + live time with seconds
        // --------------------------------------------------------------
        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.10)
        }

        Item {
            width: parent.width
            height: 22

            Text {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
                text: root.todayDay + " " + root.monthNames[root.todayMonth] + " " + root.todayYear
                    + " · " + root.weekdayFull[clock.date.getDay()]
                color: root.theme.textSecondary
                font.family: root.theme.fontUi
                font.pixelSize: root.theme.fontSizeSm
                font.features: { "tnum": 1 }
                renderType: Text.NativeRendering
            }

            Text {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                text: Qt.formatDateTime(clock.date, "HH:mm:ss")
                color: root.theme.accent
                font.family: root.theme.fontMono
                font.pixelSize: root.theme.fontSizeSm
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                renderType: Text.NativeRendering
            }
        }
    }
}
