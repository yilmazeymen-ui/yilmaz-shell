import QtQuick

// True SDF Liquid Glass island using compiled Qt6 fragment shader (refraction + Fresnel rim).
Item {
    id: root

    required property var theme
    required property var wallpaperTex
    required property real screenWidth
    required property real screenHeight
    property real islandX: x
    property real islandY: y
    property int radius: theme.barRadius
    property bool hovered: false
    property real innerAlpha: 0.62
    property real wallpaperMix: 1.0

    Behavior on innerAlpha {
        NumberAnimation {
            duration: root.theme.animNormal
            easing.type: Easing.OutCubic
        }
    }

    Behavior on wallpaperMix {
        NumberAnimation {
            duration: root.theme.animNormal
            easing.type: Easing.OutCubic
        }
    }

    property real hoverAmount: hovered ? 1.0 : 0.0
    Behavior on hoverAmount {
        NumberAnimation {
            duration: root.theme.animFast
            easing.type: Easing.OutCubic
        }
    }

    ShaderEffect {
        id: shader
        anchors.fill: parent

        readonly property var wallpaperTex: root.wallpaperTex
        readonly property vector2d itemSize: Qt.vector2d(root.width, root.height)
        readonly property vector2d itemPos: Qt.vector2d(root.islandX, root.islandY)
        readonly property vector2d screenSize: Qt.vector2d(root.screenWidth, root.screenHeight)
        readonly property real cornerRadius: root.radius
        readonly property real hoverAmount: root.hoverAmount
        readonly property real innerAlpha: root.innerAlpha
        readonly property real wallpaperMix: root.wallpaperMix
        readonly property color glassTintColor: root.theme.shaderGlassTint
        readonly property color pureGlassColor: root.theme.shaderPureGlass
        readonly property color highlightTint: root.theme.shaderHighlight

        fragmentShader: "../shaders/liquid_glass.frag.qsb"
    }
}
