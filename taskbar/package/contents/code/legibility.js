.pragma library

// Label font weights selectable in the settings (OpenType weights, as Font.* in Qt 6)
var fontWeights = [400, 500, 600, 700, 800, 900]

// Outline colour modes: 0 automatic, 1 dark, 2 light, 3 custom
function outlineColor(mode, customColor, labelColor, opacityPercent) {
    let base
    switch (mode) {
    case 1:
        base = Qt.rgba(0, 0, 0, 1)
        break
    case 2:
        base = Qt.rgba(1, 1, 1, 1)
        break
    case 3:
        base = customColor
        break
    default: {
        // Opposite brightness of the label, so text and icons separate from
        // both light and dark backgrounds
        const luminance = 0.2126 * labelColor.r + 0.7152 * labelColor.g + 0.0722 * labelColor.b
        base = luminance > 0.5 ? Qt.rgba(0, 0, 0, 1) : Qt.rgba(1, 1, 1, 1)
    }
    }
    const alpha = Math.max(0, Math.min(100, opacityPercent)) / 100
    return Qt.rgba(base.r, base.g, base.b, base.a * alpha)
}
