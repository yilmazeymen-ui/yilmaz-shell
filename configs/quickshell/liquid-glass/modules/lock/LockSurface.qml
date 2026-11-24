import QtQuick
import Quickshell
import Qt5Compat.GraphicalEffects
import "../../components"

// Fullscreen lock surface rendered per monitor inside WlSessionLockSurface.
// Sharp wallpaper, compact Dynamic-Island-style lock pill at top (expands on input),
// and a massive bold digital clock in the center.
Item {
    id: root

    required property var context
    required property var theme
    required property string wallpaperPath
    required property var bgSize
    property bool unlocking: false

    readonly property bool pillExpanded: !root.unlocking && (passwordInput.text.length > 0
        || root.context.unlockInProgress
        || root.context.showFailure
        || root.context.pamError)

    property real transitionProgress: 0.0
    // Peaks at t ≈ 0.62 right as left/right bars slam into the center pill, then settles to 0 at t = 1.0
    readonly property real impactPulse: (transitionProgress > 0.35 && transitionProgress < 1.0)
        ? Math.sin(Math.PI * (transitionProgress - 0.35) / 0.65)
        : 0.0
    // Secondary surface-tension ripple (slight vertical squash-and-rebound after impact)
    readonly property real rippleWave: (transitionProgress > 0.45 && transitionProgress < 1.0)
        ? Math.sin(2.0 * Math.PI * (transitionProgress - 0.45) / 0.55) * (1.0 - transitionProgress)
        : 0.0

    Component.onCompleted: {
        passwordInput.forceActiveFocus();
        Qt.callLater(() => {
            transitionProgress = 1.0;
        });
    }

    onUnlockingChanged: {
        if (unlocking)
            transitionProgress = 0.0;
    }

    Behavior on transitionProgress {
        NumberAnimation {
            duration: 480
            easing.type: Easing.InOutCubic
        }
    }

    // Base fallback background
    Rectangle {
        anchors.fill: parent
        color: root.theme.shaderPureGlass
    }

    // Crisp wallpaper source (base layer + sampled by GlassSurface shader)
    Image {
        id: bgImg
        anchors.fill: parent
        visible: true
        source: root.wallpaperPath !== "" ? "file://" + root.wallpaperPath : ""
        sourceSize: root.bgSize
        fillMode: Image.PreserveAspectCrop
    }

    // Very subtle background blur
    FastBlur {
        id: bgSoftBlur
        anchors.fill: parent
        visible: bgImg.status === Image.Ready
        source: bgImg
        radius: 10
        cached: true
        opacity: root.transitionProgress
    }

    // Very subtle bloom pass
    FastBlur {
        id: bgBloom
        anchors.fill: parent
        visible: bgImg.status === Image.Ready
        source: bgImg
        radius: 40
        cached: true
        opacity: root.transitionProgress * 0.20
    }

    // Very subtle vignette around the edges
    RadialGradient {
        anchors.fill: parent
        opacity: root.transitionProgress
        horizontalRadius: root.width * 0.72
        verticalRadius: root.height * 0.72
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.58; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.38) }
        }
    }

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    FontLoader {
        id: fredokaFont
        source: "file://" + (Quickshell.env("HOME") || "") + "/.local/share/fonts/Fredoka.ttf"
    }

    // Center massive translucent glowing digital clock
    Row {
        id: clockBox
        anchors.centerIn: parent
        spacing: 2
        opacity: 0.25 + 0.75 * root.transitionProgress
        transform: [
            Translate {
                y: (1.0 - root.transitionProgress) * -(root.height / 2 - root.theme.topMargin - root.theme.barHeight / 2)
            },
            Scale {
                origin.x: clockBox.width / 2
                origin.y: clockBox.height / 2
                xScale: 0.14 + 0.86 * root.transitionProgress
                yScale: 0.14 + 0.86 * root.transitionProgress
            }
        ]

        // Hours (static cached effects)
        Item {
            width: hourText.implicitWidth
            height: hourText.implicitHeight

            Text {
                id: hourText
                anchors.centerIn: parent
                text: Qt.formatDateTime(sysClock.date, "HH")
                color: "#FFFFFF"
                font.family: fredokaFont.name !== "" ? fredokaFont.name : "Fredoka"
                font.pixelSize: 210
                font.weight: Font.Bold
                font.letterSpacing: 2
                font.features: { "tnum": 1 }
                renderType: Text.QtRendering
                visible: false
            }

            DropShadow {
                anchors.fill: hourText
                source: hourText
                horizontalOffset: 0
                verticalOffset: 4
                radius: 18
                samples: 25
                cached: true
                color: Qt.rgba(0, 0, 0, 0.20)
            }

            Glow {
                anchors.fill: hourText
                source: hourText
                radius: 26
                samples: 33
                spread: 0.12
                cached: true
                color: root.theme.tint(root.theme.shaderHighlight, 0.48)
            }

            Item {
                id: hourFill
                anchors.fill: hourText
                visible: false

                LinearGradient {
                    anchors.fill: parent
                    start: Qt.point(0, 0)
                    end: Qt.point(width, height)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.86) }
                        GradientStop { position: 0.5; color: Qt.rgba(0.95, 0.99, 1.0, 0.72) }
                        GradientStop { position: 1.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.80) }
                    }
                }

                RadialGradient {
                    anchors.fill: parent
                    horizontalOffset: width * 0.05
                    verticalOffset: -height * 0.08
                    horizontalRadius: width * 0.85
                    verticalRadius: height * 0.65
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.theme.tint(root.theme.accent, 0.55) }
                        GradientStop { position: 0.55; color: Qt.rgba(0.65, 0.96, 1.0, 0.22) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }

            OpacityMask {
                anchors.fill: hourText
                source: hourFill
                maskSource: hourText
                cached: true
            }
        }

        // Blinking colon (static cached effects, GPU-only opacity animation)
        Item {
            id: colonBox
            property bool colonOn: true
            width: colonText.implicitWidth
            height: colonText.implicitHeight
            opacity: colonOn ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.InOutSine
                }
            }

            Timer {
                interval: 1500
                repeat: true
                running: !root.unlocking
                onTriggered: colonBox.colonOn = !colonBox.colonOn
            }

            Text {
                id: colonText
                anchors.centerIn: parent
                text: ":"
                color: "#FFFFFF"
                font.family: fredokaFont.name !== "" ? fredokaFont.name : "Fredoka"
                font.pixelSize: 210
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                renderType: Text.QtRendering
                visible: false
            }

            DropShadow {
                anchors.fill: colonText
                source: colonText
                horizontalOffset: 0
                verticalOffset: 4
                radius: 18
                samples: 25
                cached: true
                color: Qt.rgba(0, 0, 0, 0.20)
            }

            Glow {
                anchors.fill: colonText
                source: colonText
                radius: 26
                samples: 33
                spread: 0.12
                cached: true
                color: root.theme.tint(root.theme.shaderHighlight, 0.48)
            }

            LinearGradient {
                id: colonFill
                anchors.fill: colonText
                visible: false
                start: Qt.point(0, 0)
                end: Qt.point(width, height)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.86) }
                    GradientStop { position: 0.5; color: Qt.rgba(0.95, 0.99, 1.0, 0.72) }
                    GradientStop { position: 1.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.80) }
                }
            }

            OpacityMask {
                anchors.fill: colonText
                source: colonFill
                maskSource: colonText
                cached: true
            }
        }

        // Minutes (static cached effects)
        Item {
            width: minText.implicitWidth
            height: minText.implicitHeight

            Text {
                id: minText
                anchors.centerIn: parent
                text: Qt.formatDateTime(sysClock.date, "mm")
                color: "#FFFFFF"
                font.family: fredokaFont.name !== "" ? fredokaFont.name : "Fredoka"
                font.pixelSize: 210
                font.weight: Font.Bold
                font.letterSpacing: 2
                font.features: { "tnum": 1 }
                renderType: Text.QtRendering
                visible: false
            }

            DropShadow {
                anchors.fill: minText
                source: minText
                horizontalOffset: 0
                verticalOffset: 4
                radius: 18
                samples: 25
                cached: true
                color: Qt.rgba(0, 0, 0, 0.20)
            }

            Glow {
                anchors.fill: minText
                source: minText
                radius: 26
                samples: 33
                spread: 0.12
                cached: true
                color: root.theme.tint(root.theme.shaderHighlight, 0.48)
            }

            LinearGradient {
                id: minFill
                anchors.fill: minText
                visible: false
                start: Qt.point(0, 0)
                end: Qt.point(width, height)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.86) }
                    GradientStop { position: 0.5; color: Qt.rgba(0.95, 0.99, 1.0, 0.72) }
                    GradientStop { position: 1.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.80) }
                }
            }

            OpacityMask {
                anchors.fill: minText
                source: minFill
                maskSource: minText
                cached: true
            }
        }
    }

    // Unified GLSL metaball (smin) liquid-glass shader for 3-bar water collision & coalescence
    ShaderEffect {
        id: liquidMerge
        x: 0
        y: 0
        width: root.width
        height: 88
        visible: root.transitionProgress < 0.99

        readonly property real moveT: Math.min(1.0, root.transitionProgress / 0.72)
        readonly property real targetCy: root.theme.evenPx(16) + root.theme.evenPx(30) * 0.5

        readonly property var wallpaperTex: bgImg
        readonly property vector2d itemSize: Qt.vector2d(width, height)
        readonly property vector2d screenSize: Qt.vector2d(root.width, root.height)

        readonly property vector4d leftRect: {
            const w = 220 + (48 - 220) * moveT;
            const h = root.theme.barHeight + (30 - root.theme.barHeight) * moveT;
            const startCx = root.theme.sideMargin + w * 0.5;
            const startCy = root.theme.topMargin + h * 0.5;
            const cx = startCx + (root.width * 0.5 - startCx) * moveT;
            const cy = startCy + (targetCy - startCy) * moveT;
            return Qt.vector4d(cx, cy, w * 0.5, h * 0.5);
        }

        readonly property vector4d centerRect: {
            const w = 128 + (54 - 128) * root.transitionProgress + 52 * root.impactPulse;
            const h = root.theme.barHeight + (30 - root.theme.barHeight) * root.transitionProgress + 8 * root.impactPulse + 5 * root.rippleWave;
            const startCy = root.theme.topMargin + root.theme.barHeight * 0.5;
            const cy = startCy + (targetCy - startCy) * root.transitionProgress - 3 * root.rippleWave;
            return Qt.vector4d(root.width * 0.5, cy, w * 0.5, h * 0.5);
        }

        readonly property vector4d rightRect: {
            const w = 240 + (48 - 240) * moveT;
            const h = root.theme.barHeight + (30 - root.theme.barHeight) * moveT;
            const startCx = root.width - root.theme.sideMargin - w * 0.5;
            const startCy = root.theme.topMargin + h * 0.5;
            const cx = startCx + (root.width * 0.5 - startCx) * moveT;
            const cy = startCy + (targetCy - startCy) * moveT;
            return Qt.vector4d(cx, cy, w * 0.5, h * 0.5);
        }

        readonly property vector4d params: Qt.vector4d(
            34.0,
            0.55 + 0.23 * root.transitionProgress,
            root.impactPulse,
            0.0
        )
        readonly property color glassTintColor: root.theme.shaderGlassTint
        readonly property color pureGlassColor: root.theme.shaderPureGlass
        readonly property color highlightTint: root.theme.shaderHighlight

        fragmentShader: "../../shaders/liquid_merge.frag.qsb"
    }

    // Top Dynamic-Island-style Liquid Glass lock pill (absorbs collision & ripples to rest)
    Item {
        id: passwordPill
        z: 10
        anchors {
            top: parent.top
            topMargin: Math.round(root.theme.topMargin + (root.theme.evenPx(16) - root.theme.topMargin) * root.transitionProgress - 3 * root.rippleWave)
            horizontalCenter: parent.horizontalCenter
        }
        width: root.pillExpanded
            ? root.theme.evenPx(300)
            : root.theme.evenPx(128 + (54 - 128) * root.transitionProgress + 52 * root.impactPulse)
        height: root.pillExpanded
            ? root.theme.evenPx(40)
            : Math.round(root.theme.barHeight + (root.theme.evenPx(30) - root.theme.barHeight) * root.transitionProgress + 8 * root.impactPulse + 5 * root.rippleWave)
        opacity: 1.0

        Behavior on width {
            enabled: root.transitionProgress >= 0.99
            NumberAnimation {
                duration: root.theme.animNormal
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            enabled: root.transitionProgress >= 0.99
            NumberAnimation {
                duration: root.theme.animNormal
                easing.type: Easing.OutCubic
            }
        }

        GlassSurface {
            anchors.fill: parent
            visible: root.transitionProgress >= 0.99
            theme: root.theme
            wallpaperTex: bgImg
            screenWidth: root.width
            screenHeight: root.height
            islandX: passwordPill.x
            islandY: passwordPill.y
            radius: Math.round(passwordPill.height / 2)
            innerAlpha: 0.78
            hovered: root.pillExpanded || pillHover.containsMouse || root.impactPulse > 0.25
        }

        MouseArea {
            id: pillHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.pillExpanded ? Qt.IBeamCursor : Qt.PointingHandCursor
            onClicked: passwordInput.forceActiveFocus()
        }

        // Compact lock icon (centered when collapsed, left-aligned when expanded)
        Text {
            id: lockIcon
            anchors.verticalCenter: parent.verticalCenter
            x: root.pillExpanded ? 14 : Math.round((parent.width - width) / 2)
            opacity: root.transitionProgress
            text: root.context.unlockInProgress ? "󰔟" : "󰌾"
            color: (root.context.showFailure || root.context.pamError)
                ? root.theme.warn
                : (root.pillExpanded ? root.theme.accent : "#FFFFFF")
            font.family: root.theme.fontUi
            font.pixelSize: root.pillExpanded ? 15 : 14
            renderType: Text.NativeRendering

            Behavior on x {
                NumberAnimation {
                    duration: root.theme.animNormal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: root.theme.animFast
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Password input field (always focused so typing immediately expands the pill)
        TextInput {
            id: passwordInput
            anchors {
                left: lockIcon.right
                leftMargin: 10
                right: submitBtn.left
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            opacity: root.pillExpanded ? 1.0 : 0.0
            echoMode: TextInput.Password
            passwordCharacter: "•"
            color: root.theme.textPrimary
            selectionColor: root.theme.glassPillActive
            font.family: root.theme.fontUi
            font.pixelSize: 14
            clip: true
            focus: true
            enabled: !root.context.unlockInProgress
            verticalAlignment: TextInput.AlignVCenter
            renderType: Text.NativeRendering

            onTextChanged: {
                if (root.context.currentText !== text)
                    root.context.currentText = text;
            }

            onActiveFocusChanged: {
                if (!activeFocus && !root.unlocking)
                    forceActiveFocus();
            }

            Keys.onReturnPressed: root.context.tryUnlock()
            Keys.onEnterPressed: root.context.tryUnlock()
            Keys.onEscapePressed: {
                text = "";
                root.context.currentText = "";
            }

            Connections {
                target: root.context
                function onCurrentTextChanged() {
                    if (passwordInput.text !== root.context.currentText)
                        passwordInput.text = root.context.currentText;
                }
            }

            // Status / error message when expanded with empty text
            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: passwordInput.text.length === 0 && root.pillExpanded
                text: {
                    if (root.context.unlockInProgress)
                        return "Doğrulanıyor...";
                    if (root.context.pamError)
                        return "PAM hatası";
                    if (root.context.showFailure)
                        return "Yanlış şifre";
                    return "";
                }
                color: (root.context.showFailure || root.context.pamError)
                    ? root.theme.warn
                    : root.theme.textMuted
                font.family: root.theme.fontUi
                font.pixelSize: root.theme.fontSizeSm
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
        }

        // Submit button
        Item {
            id: submitBtn
            anchors {
                right: parent.right
                rightMargin: 6
                verticalCenter: parent.verticalCenter
            }
            width: 28
            height: 28
            visible: root.pillExpanded && passwordInput.text.length > 0 && !root.context.unlockInProgress

            Rectangle {
                anchors.fill: parent
                radius: 14
                color: submitMouse.containsMouse ? root.theme.glassPillHover : root.theme.glassPill
            }

            Text {
                anchors.centerIn: parent
                text: "󰁔"
                color: root.theme.accent
                font.family: root.theme.fontUi
                font.pixelSize: 14
                renderType: Text.NativeRendering
            }

            MouseArea {
                id: submitMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.context.tryUnlock()
            }
        }
    }
}
