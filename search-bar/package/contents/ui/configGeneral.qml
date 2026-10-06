import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root

    property alias cfg_spacing: spacingSpin.value
    property alias cfg_popupMaxHeight: heightSpin.value
    property alias cfg_showFooterHints: footerCheck.checked
    property alias cfg_highlightMatches: highlightCheck.checked
    property alias cfg_showCategoryHeaders: headersCheck.checked
    property alias cfg_actionsEnabled: actionsCheck.checked

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.SpinBox {
            id: spacingSpin
            Kirigami.FormData.label: i18n("Mezera okolo pole (px):")
            from: 0
            to: 32
            stepSize: 1
        }

        QQC2.SpinBox {
            id: heightSpin
            Kirigami.FormData.label: i18n("Max. výška výsledků (řádky):")
            from: 6
            to: 60
            stepSize: 1
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Výsledky")
        }

        QQC2.CheckBox {
            id: headersCheck
            Kirigami.FormData.label: i18n("Zobrazení:")
            text: i18n("Nadpisy kategorií")
        }

        QQC2.CheckBox {
            id: highlightCheck
            text: i18n("Zvýrazňovat shodu s dotazem")
        }

        QQC2.CheckBox {
            id: footerCheck
            text: i18n("Nápověda klávesových zkratek pod výsledky")
        }

        QQC2.CheckBox {
            id: actionsCheck
            Kirigami.FormData.label: i18n("Akce:")
            text: i18n("Tlačítka akcí u výsledků a Shift/Alt+Enter")
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.75
            text: i18n("Akce jsou např. „Otevřít složku“, „Kopírovat cestu“ nebo „Spustit jako root“. Shift+Enter spustí první akci vybraného výsledku, Alt+Enter druhou.")
        }
    }
}
