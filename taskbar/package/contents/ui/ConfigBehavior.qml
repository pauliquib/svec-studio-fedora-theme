import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property bool cfg_groupWindows
    property alias cfg_groupedClick: groupedClick.currentIndex
    property alias cfg_sortMode: sortMode.currentIndex
    property alias cfg_minimizeActive: minimizeActive.checked
    property alias cfg_middleClick: middleClick.currentIndex
    property alias cfg_wheelMode: wheelMode.currentIndex
    property alias cfg_wheelSkipMinimized: wheelSkipMinimized.checked
    property alias cfg_onlyCurrentDesktop: onlyCurrentDesktop.checked
    property alias cfg_onlyCurrentActivity: onlyCurrentActivity.checked
    property alias cfg_onlyCurrentScreen: onlyCurrentScreen.checked
    property alias cfg_onlyMinimized: onlyMinimized.checked
    property alias cfg_unhideOnAttention: unhideOnAttention.checked
    property bool cfg_reverseMode
    property alias cfg_equalHoverZones: equalHoverZones.checked
    property alias cfg_hoverTransition: hoverTransition.checked
    property alias cfg_hoverTransitionWidth: hoverTransitionWidth.value
    property alias cfg_hoverAnimationSpeed: hoverAnimationSpeed.value

    // Slider with its value shown next to it (same as on the Appearance page)
    component ValueSlider: RowLayout {
        id: valueSlider
        property real value
        property alias from: slider.from
        property alias to: slider.to
        property real stepSize: 1
        property string unit: ""

        QQC2.Slider {
            id: slider
            Layout.preferredWidth: Kirigami.Units.gridUnit * 9
            value: valueSlider.value
            onMoved: valueSlider.value = Math.round(value / valueSlider.stepSize) * valueSlider.stepSize
        }
        QQC2.Label {
            Layout.minimumWidth: Kirigami.Units.gridUnit * 3
            text: slider.value.toFixed(0) + " " + unit
        }
    }
    property alias cfg_dragToClose: dragToClose.checked

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: groupMode
            Kirigami.FormData.label: i18n("Group:")
            Layout.fillWidth: true
            model: [i18n("Do not group"), i18n("By program name")]
            currentIndex: cfg_groupWindows ? 1 : 0
            onActivated: cfg_groupWindows = currentIndex === 1
        }

        QQC2.ComboBox {
            id: groupedClick
            Kirigami.FormData.label: i18n("Clicking grouped task:")
            Layout.fillWidth: true
            enabled: groupMode.currentIndex === 1
            model: [
                i18n("Cycles through tasks"),
                i18n("Shows windows side by side"),
                i18n("Shows textual list")
            ]
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.ComboBox {
            id: sortMode
            Kirigami.FormData.label: i18n("Sort:")
            Layout.fillWidth: true
            model: [
                i18n("Manually (drag to reorder)"),
                i18n("Alphabetically"),
                i18n("By desktop"),
                i18n("By activity"),
                i18n("By horizontal window position")
            ]
        }

        QQC2.CheckBox {
            id: minimizeActive
            Kirigami.FormData.label: i18n("Clicking active task:")
            text: i18n("Minimizes the task")
        }

        QQC2.ComboBox {
            id: middleClick
            Kirigami.FormData.label: i18n("Middle-clicking any task:")
            Layout.fillWidth: true
            model: [
                i18n("Does nothing"),
                i18n("Closes window or group"),
                i18n("Opens a new window"),
                i18n("Minimizes/Restores window or group"),
                i18n("Toggles grouping"),
                i18n("Brings it to the current virtual desktop")
            ]
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.ComboBox {
            id: wheelMode
            Kirigami.FormData.label: i18n("Scrolling behavior:")
            Layout.fillWidth: true
            model: [
                i18n("Does nothing"),
                i18n("Cycles through all tasks"),
                i18n("Cycles through windows of the hovered task")
            ]
        }

        QQC2.CheckBox {
            id: wheelSkipMinimized
            enabled: wheelMode.currentIndex > 0
            text: i18n("Skip minimized tasks")
        }

        QQC2.CheckBox {
            id: equalHoverZones
            Kirigami.FormData.label: i18n("Hovering:")
            text: i18n("Same hover area for every icon")
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("When off, a task with a long label takes up a larger area and can make a neighbour with a short label hard to reach.")
        }

        QQC2.CheckBox {
            id: hoverTransition
            enabled: equalHoverZones.checked
            text: i18n("Blend smoothly into the neighbouring icon near the edge")
        }

        ValueSlider {
            id: hoverTransitionWidth
            Kirigami.FormData.label: i18n("Transition width:")
            enabled: equalHoverZones.checked && hoverTransition.checked
            from: 10
            to: 100
            stepSize: 5
            unit: "%"
        }

        ValueSlider {
            id: hoverAnimationSpeed
            Kirigami.FormData.label: i18n("Animation speed:")
            from: 25
            to: 300
            stepSize: 5
            unit: "%"
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("Transition width is the part of each icon's hover area, measured from its edge, in which the label hands over to the neighbour. 100 % blends across the whole area.")
        }

        QQC2.CheckBox {
            id: dragToClose
            Kirigami.FormData.label: i18n("Dragging a task:")
            text: i18n("Toward the screen center closes it")
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("Pull a running task's icon toward the screen center. The screen dims and a red cross appears; releasing then closes it, releasing earlier cancels. A group closes all its windows.")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: onlyCurrentDesktop
            Kirigami.FormData.label: i18n("Show only tasks:")
            text: i18n("From the current desktop")
        }

        QQC2.CheckBox {
            id: onlyCurrentActivity
            text: i18n("From the current activity")
        }

        QQC2.CheckBox {
            id: onlyCurrentScreen
            text: i18n("From the current screen")
        }

        QQC2.CheckBox {
            id: onlyMinimized
            text: i18n("That are minimized")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: unhideOnAttention
            Kirigami.FormData.label: i18n("When panel is hidden:")
            text: i18n("Unhide when a window wants attention")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.RadioButton {
            Kirigami.FormData.label: i18n("New tasks appear:")
            text: i18n("To the right")
            checked: !cfg_reverseMode
            onToggled: if (checked) cfg_reverseMode = false
        }

        QQC2.RadioButton {
            text: i18n("To the left")
            checked: cfg_reverseMode
            onToggled: if (checked) cfg_reverseMode = true
        }
    }
}
