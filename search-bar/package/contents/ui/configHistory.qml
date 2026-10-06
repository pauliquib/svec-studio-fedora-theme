import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root

    property alias cfg_historyEnabled: enabledCheck.checked
    property alias cfg_historyShowOnFocus: showOnFocusCheck.checked
    property alias cfg_historyMax: maxSpin.value
    property var cfg_history: []

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.CheckBox {
            id: enabledCheck
            Kirigami.FormData.label: i18n("Historie:")
            text: i18n("Pamatovat si nedávno spuštěné položky")
        }

        QQC2.CheckBox {
            id: showOnFocusCheck
            enabled: enabledCheck.checked
            text: i18n("Zobrazit nedávné položky po kliknutí do prázdného pole")
        }

        QQC2.SpinBox {
            id: maxSpin
            Kirigami.FormData.label: i18n("Maximální počet položek:")
            enabled: enabledCheck.checked
            from: 1
            to: 100
            stepSize: 1
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Uložených položek:")
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: String((root.cfg_history || []).length)
            }

            QQC2.Button {
                icon.name: "edit-clear-history"
                text: i18n("Vymazat historii")
                enabled: (root.cfg_history || []).length > 0
                onClicked: root.cfg_history = []
            }
        }
    }
}
