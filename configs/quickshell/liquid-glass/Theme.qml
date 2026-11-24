import QtQuick
import Quickshell
import Quickshell.Io

// Liquid Glass dynamic theme tokens.
// Watches ~/.config/hypr/vars/bg and ~/.config/hypr/vars/palettes/<wallpaper>.sh
// for live updates, with "orman çizim.png" as the baseline/fallback palette.
QtObject {
    id: th

    readonly property string home: Quickshell.env("HOME") || ""

    // Live wallpaper path watcher (falls back to orman çizim.png)
    readonly property FileView bgFile: FileView {
        path: th.home + "/.config/hypr/vars/bg"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
    }

    readonly property string wallpaperPath: {
        const p = bgFile.text().trim();
        return p.length > 0 ? p : (th.home + "/Resimler/Arkaplan/yeni/orman çizim.png");
    }
    readonly property url wallpaperUrl: "file://" + wallpaperPath

    readonly property string palettesDir: home + "/.config/hypr/vars/palettes"
    readonly property string palettePath: {
        if (wallpaperPath === "")
            return "";
        const slash = wallpaperPath.lastIndexOf("/");
        const name = slash >= 0 ? wallpaperPath.slice(slash + 1) : wallpaperPath;
        return palettesDir + "/" + name + ".sh";
    }

    readonly property FileView palFile: FileView {
        path: th.palettePath
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
    }

    function parsePalette(t) {
        const map = {};
        const re = /^\s*([A-Z0-9_]+)\s*=\s*'([^']*)'/gm;
        let m;
        while ((m = re.exec(String(t))) !== null)
            map[m[1]] = m[2];
        return map;
    }

    function isValidHex(v) {
        return typeof v === "string" && /^#?[0-9a-fA-F]{6}$/.test(v);
    }

    function pick(v, fallback) {
        return isValidHex(v) ? ("#" + v.replace("#", "")) : fallback;
    }

    function tint(c, a) {
        const col = Qt.color(c);
        return Qt.rgba(col.r, col.g, col.b, a);
    }

    function mixColor(c1, c2, t) {
        const a = Qt.color(c1);
        const b = Qt.color(c2);
        return Qt.rgba(
            a.r + (b.r - a.r) * t,
            a.g + (b.g - a.g) * t,
            a.b + (b.b - a.b) * t,
            a.a + (b.a - a.a) * t
        );
    }

    function readableAccent(c, minL, maxL) {
        const col = Qt.color(c);
        const lo = minL !== undefined ? minL : 0.48;
        const hi = maxL !== undefined ? maxL : 0.86;
        const l = col.hslLightness;
        if (l < lo)
            return Qt.hsla(col.hslHue, Math.min(col.hslSaturation * 1.06, 1.0), lo, 1.0);
        if (l > hi)
            return Qt.hsla(col.hslHue, col.hslSaturation, hi, 1.0);
        return col;
    }

    readonly property var pal: parsePalette(palFile.text())
    readonly property bool hasPalette: isValidHex(pal.COLOR14) || isValidHex(pal.COLOR6) || isValidHex(pal.FOREGROUND)

    // Base palette anchors (fallback = "orman çizim.png")
    readonly property color _rawBg: pick(pal.BACKGROUND, pick(pal.COLOR0, "#03142D"))
    readonly property color _rawDom: pick(pal.DOMINANT, "#002040")
    readonly property color _rawFg: pick(pal.FOREGROUND, pick(pal.COLOR15, "#ECF3F6"))

    readonly property color accent: hasPalette
        ? readableAccent(pick(pal.COLOR14, pick(pal.COLOR6, pick(pal.DOMINANT, "#5ABCC8"))), 0.48, 0.86)
        : "#5ABCC8"
    readonly property color accentDeep: hasPalette
        ? readableAccent(pick(pal.COLOR12, pick(pal.COLOR4, pick(pal.COLOR2, "#2E94A7"))), 0.34, 0.68)
        : "#2E94A7"
    readonly property color warn: hasPalette
        ? readableAccent(pick(pal.COLOR9, pick(pal.COLOR1, "#EBB079")), 0.54, 0.86)
        : "#EBB079"

    // Typography
    readonly property string fontUi: "Hurmit Nerd Font"
    readonly property string fontMono: "Hurmit Nerd Font"
    readonly property int fontSizeSm: 12
    readonly property int fontSizeMd: 13
    readonly property int fontSizeLg: 14

    // Layout metrics
    readonly property int barHeight: 38
    readonly property int topMargin: 8
    readonly property int sideMargin: 12
    readonly property int islandGap: 12
    readonly property int windowGap: 4
    readonly property int barRadius: 19
    readonly property int pillRadius: 13
    readonly property int pillHeight: 26

    // Snap dimensions to even integers so centered items never land on .5px at 1x DPI
    function evenPx(v) {
        return Math.ceil(v / 2) * 2;
    }

    // Crisp, non-distracting motion timings (ms)
    readonly property int animFast: 110
    readonly property int animNormal: 150

    // Liquid Glass surface colors (derived from active wallpaper palette; fallback = "orman çizim.png")
    readonly property color glassBase: hasPalette
        ? tint(mixColor(_rawBg, accentDeep, 0.12), 0.38)
        : Qt.rgba(6 / 255, 26 / 255, 48 / 255, 0.38)
    readonly property color _pillTintRgb: hasPalette ? mixColor("#FFFFFF", accent, 0.24) : Qt.rgba(215 / 255, 240 / 255, 248 / 255, 1.0)
    readonly property color glassPill: tint(_pillTintRgb, 0.07)
    readonly property color glassPillHover: tint(_pillTintRgb, 0.14)
    readonly property color glassPillActive: tint(accent, 0.24)

    // Specular refraction rim & inner sheen
    readonly property color rimTop: Qt.rgba(1, 1, 1, 0.32)
    readonly property color rimMid: hasPalette
        ? tint(mixColor("#FFFFFF", accent, 0.35), 0.14)
        : Qt.rgba(180 / 255, 232 / 255, 242 / 255, 0.14)
    readonly property color rimBottom: Qt.rgba(1, 1, 1, 0.07)
    readonly property color rimActive: tint(accent, 0.48)

    readonly property color sheenTop: Qt.rgba(1, 1, 1, 0.10)
    readonly property color sheenBottom: Qt.rgba(1, 1, 1, 0.0)

    // Text colors
    readonly property color textPrimary: hasPalette
        ? mixColor(_rawFg, mixColor("#FFFFFF", accent, 0.12), 0.72)
        : "#ECF3F6"
    readonly property color textSecondary: hasPalette
        ? mixColor(mixColor(textPrimary, pick(pal.COLOR8, "#9FB6C2"), 0.45), accent, 0.22)
        : "#9FB6C2"
    readonly property color textMuted: tint(textSecondary, 0.55)

    // Shader surface tint tokens passed to GlassSurface -> liquid_glass.frag
    readonly property color shaderGlassTint: hasPalette
        ? mixColor(mixColor(_rawBg, accentDeep, 0.32), accent, 0.12)
        : Qt.rgba(0.11, 0.24, 0.34, 1.0)
    readonly property color shaderPureGlass: hasPalette
        ? mixColor(_rawBg, _rawDom, 0.35)
        : Qt.rgba(0.03, 0.10, 0.16, 1.0)
    readonly property color shaderHighlight: hasPalette
        ? mixColor("#FFFFFF", accent, 0.20)
        : Qt.rgba(0.86, 0.96, 1.0, 1.0)
}
