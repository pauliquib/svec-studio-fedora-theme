import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls

import "../code/legibility.js" as Legibility

KCM.SimpleKCM {
    property alias cfg_showLabels: showLabels.checked
    property alias cfg_labelSource: labelSource.currentIndex
    property alias cfg_maxLabelWidth: maxLabelWidth.value
    property alias cfg_showHoverPill: showHoverPill.checked
    property alias cfg_accentLabels: accentLabels.checked
    property alias cfg_labelFontWeight: labelFontWeight.currentIndex
    property alias cfg_labelFontSize: labelFontSize.value
    property alias cfg_legibilityMode: legibilityMode.currentIndex
    property alias cfg_outlineWidth: outlineWidth.value
    property alias cfg_outlineSoftness: outlineSoftness.value
    property alias cfg_outlineOpacity: outlineOpacity.value
    property alias cfg_outlineColorMode: outlineColorMode.currentIndex
    property alias cfg_outlineCustomColor: outlineCustomColor.color
    property alias cfg_backdropOpacity: backdropOpacity.value
    property alias cfg_showPreviews: showPreviews.checked
    property alias cfg_highlightWindows: highlightWindows.checked
    property alias cfg_audioIndicator: audioIndicator.checked
    property alias cfg_muteOnIndicatorClick: muteOnIndicatorClick.checked
    property alias cfg_audioBadgeStyle: audioBadgeStyle.currentIndex
    property alias cfg_audioBadgeSize: audioBadgeSize.currentIndex
    property alias cfg_audioBadgePosition: audioBadgePosition.currentIndex
    property alias cfg_iconSize: iconSize.value
    property alias cfg_iconSpacing: iconSpacing.currentIndex
    property alias cfg_fillSpace: fillSpace.checked
    property alias cfg_alignment: alignment.currentIndex
    property alias cfg_reserveSpace: reserveSpace.checked
    property alias cfg_hidePanelBackground: hidePanelBackground.checked

    readonly property bool outlineOn: legibilityMode.currentIndex === 1 || legibilityMode.currentIndex === 3
    readonly property bool backdropOn: legibilityMode.currentIndex === 2 || legibilityMode.currentIndex === 3

    // Slider with its value shown next to it. Rounds to `stepSize` itself, so the
    // style draws no tick marks (they make every row taller)
    component ValueSlider: RowLayout {
        id: valueSlider
        property real value
        property alias from: slider.from
        property alias to: slider.to
        property real stepSize: 1
        property string unit: ""
        property int decimals: 0

        QQC2.Slider {
            id: slider
            Layout.preferredWidth: Kirigami.Units.gridUnit * 9
            value: valueSlider.value
            onMoved: valueSlider.value = Math.round(value / valueSlider.stepSize) * valueSlider.stepSize
        }
        QQC2.Label {
            Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            text: slider.value.toFixed(decimals) + " " + unit
        }
    }

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: showLabels
            Kirigami.FormData.label: i18n("On hover:")
            text: i18n("Expand the icon with a label")
        }

        QQC2.ComboBox {
            id: labelSource
            Kirigami.FormData.label: i18n("Label shows:")
            enabled: showLabels.checked
            model: [i18n("Window title"), i18n("Application name")]
        }

        QQC2.SpinBox {
            id: maxLabelWidth
            Kirigami.FormData.label: i18n("Maximum label width:")
            enabled: showLabels.checked
            from: 60
            to: 800
            stepSize: 10
            textFromValue: (value, locale) => i18n("%1 px", value)
            valueFromText: (text, locale) => parseInt(text)
        }

        QQC2.CheckBox {
            id: showHoverPill
            text: i18n("Highlight background on hover")
        }

        QQC2.CheckBox {
            id: accentLabels
            enabled: showLabels.checked
            text: i18n("Labels in the system accent color")
        }

        QQC2.ComboBox {
            id: labelFontWeight
            Kirigami.FormData.label: i18n("Label font weight:")
            enabled: showLabels.checked
            model: [i18n("Normal"), i18n("Medium"), i18n("Semi-bold"), i18n("Bold"), i18n("Extra bold"), i18n("Black")]
        }

        QQC2.SpinBox {
            id: labelFontSize
            Kirigami.FormData.label: i18n("Label font size:")
            enabled: showLabels.checked
            from: 0
            to: 24
            textFromValue: (value, locale) => value === 0 ? i18n("Theme default") : i18n("%1 pt", value)
            valueFromText: (text, locale) => parseInt(text) || 0
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.ComboBox {
            id: legibilityMode
            Kirigami.FormData.label: i18n("Readability:")
            model: [
                i18n("Off"),
                i18n("Contrast outline"),
                i18n("Backdrop behind label"),
                i18n("Outline and backdrop")
            ]
        }

        ValueSlider {
            id: outlineWidth
            Kirigami.FormData.label: i18n("Outline width:")
            enabled: outlineOn
            from: 0.5
            to: 4
            stepSize: 0.1
            decimals: 1
            unit: i18n("px")
        }

        ValueSlider {
            id: outlineSoftness
            Kirigami.FormData.label: i18n("Soft edge:")
            enabled: outlineOn
            from: 0
            to: 6
            stepSize: 0.1
            decimals: 1
            unit: i18n("px")
        }

        ValueSlider {
            id: outlineOpacity
            Kirigami.FormData.label: i18n("Outline opacity:")
            enabled: outlineOn
            from: 10
            to: 100
            stepSize: 1
            unit: "%"
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Outline color:")
            enabled: outlineOn

            QQC2.ComboBox {
                id: outlineColorMode
                model: [
                    i18n("Automatic"),
                    i18n("Dark"),
                    i18n("Light"),
                    i18n("Custom")
                ]
            }
            KQuickControls.ColorButton {
                id: outlineCustomColor
                visible: outlineColorMode.currentIndex === 3
                showAlphaChannel: false
                dialogTitle: i18n("Outline Color")
            }
        }

        ValueSlider {
            id: backdropOpacity
            Kirigami.FormData.label: i18n("Backdrop opacity:")
            enabled: backdropOn
            from: 20
            to: 100
            stepSize: 1
            unit: "%"
        }

        QQC2.Button {
            text: i18n("Reset Readability to Defaults")
            icon.name: "edit-reset"
            onClicked: {
                outlineWidth.value = 1.4
                outlineSoftness.value = 1.9
                outlineOpacity.value = 82
                outlineColorMode.currentIndex = 0
                backdropOpacity.value = 90
            }
        }

        // Live preview on light, dark and colourful backgrounds
        Grid {
            Kirigami.FormData.label: i18n("Preview:")
            columns: 2
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: ["#f2f2f2", "#ffffff", "#202124", "#9a3a1e"]

                delegate: Rectangle {
                    required property string modelData
                    readonly property color labelColor: accentLabels.checked ? Kirigami.Theme.highlightColor
                                                                              : Kirigami.Theme.textColor

                    width: Kirigami.Units.gridUnit * 6
                    height: Kirigami.Units.gridUnit * 2.2
                    radius: Kirigami.Units.cornerRadius
                    color: modelData
                    border.width: 1
                    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                    clip: true

                    Rectangle {
                        anchors.fill: sample
                        anchors.margins: -Kirigami.Units.smallSpacing
                        radius: Kirigami.Units.cornerRadius
                        color: Kirigami.Theme.backgroundColor
                        opacity: backdropOn ? backdropOpacity.value / 100 : 0
                    }

                    Item {
                        id: sample
                        anchors.centerIn: parent
                        width: sampleRow.implicitWidth + 4
                        height: sampleRow.implicitHeight + 4

                        layer.enabled: outlineOn
                        layer.effect: OutlineEffect {
                            outlineColor: Legibility.outlineColor(outlineColorMode.currentIndex, outlineCustomColor.color,
                                                                  labelColor, outlineOpacity.value)
                            radius: outlineWidth.value
                            softness: outlineSoftness.value
                        }

                        Row {
                            id: sampleRow
                            anchors.centerIn: parent
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Kirigami.Units.iconSizes.medium
                                height: width
                                source: "system-file-manager"
                            }
                            QQC2.Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: i18n("Title")
                                font.weight: Legibility.fontWeights[labelFontWeight.currentIndex] ?? Font.DemiBold
                                font.pointSize: labelFontSize.value > 0 ? labelFontSize.value
                                                                        : Kirigami.Theme.defaultFont.pointSize
                                color: labelColor
                            }
                        }
                    }
                }
            }
        }

        QQC2.Label {
            // Fixed width: a wrapping label reports its unwrapped width and would
            // push the form into its narrow, labels-above-fields layout
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("The outline keeps icons and labels legible on any background, like desktop icon labels. A wide or very opaque outline fills the inside of outline-style icons.")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: showPreviews
            Kirigami.FormData.label: i18n("General:")
            text: i18n("Show window previews when hovering over tasks")
        }

        QQC2.CheckBox {
            id: highlightWindows
            enabled: showPreviews.checked
            leftPadding: Kirigami.Units.gridUnit
            text: i18n("Hide other windows when hovering over previews")
        }

        QQC2.CheckBox {
            id: audioIndicator
            text: i18n("Show an indicator when a task is playing audio")
        }

        QQC2.CheckBox {
            id: muteOnIndicatorClick
            enabled: audioIndicator.checked
            leftPadding: Kirigami.Units.gridUnit
            text: i18n("Mute task when clicking the indicator")
        }

        QQC2.ComboBox {
            id: audioBadgeStyle
            Kirigami.FormData.label: i18n("Audio indicator style:")
            enabled: audioIndicator.checked
            model: [i18n("Accent color"), i18n("Theme"), i18n("Icon only"), i18n("Outline ring")]
        }

        QQC2.ComboBox {
            id: audioBadgeSize
            Kirigami.FormData.label: i18n("Audio indicator size:")
            enabled: audioIndicator.checked
            model: [i18n("Small"), i18n("Normal"), i18n("Large")]
        }

        QQC2.ComboBox {
            id: audioBadgePosition
            Kirigami.FormData.label: i18n("Audio indicator position:")
            enabled: audioIndicator.checked
            model: [i18n("Top right"), i18n("Top left"), i18n("Bottom right"), i18n("Bottom left")]
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.SpinBox {
            id: iconSize
            Kirigami.FormData.label: i18n("Icon size:")
            from: 0
            to: 128
            textFromValue: (value, locale) => value === 0 ? i18n("Automatic") : i18n("%1 px", value)
            valueFromText: (text, locale) => parseInt(text) || 0
        }

        QQC2.ComboBox {
            id: iconSpacing
            Kirigami.FormData.label: i18n("Spacing between icons:")
            model: [i18n("Small"), i18n("Normal"), i18n("Large")]
        }

        QQC2.CheckBox {
            id: fillSpace
            Kirigami.FormData.label: i18n("Panel:")
            text: i18n("Fill free space on panel")
        }

        QQC2.ComboBox {
            id: alignment
            Kirigami.FormData.label: i18n("Icon alignment:")
            enabled: fillSpace.checked
            model: [i18n("Start"), i18n("Center"), i18n("End")]
        }

        QQC2.CheckBox {
            id: reserveSpace
            text: i18n("Reserve space for expanded labels")
        }

        QQC2.CheckBox {
            id: hidePanelBackground
            text: i18n("Hide the background of this panel")
        }
    }
}
