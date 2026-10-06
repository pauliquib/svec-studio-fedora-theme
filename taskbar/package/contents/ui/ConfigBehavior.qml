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
