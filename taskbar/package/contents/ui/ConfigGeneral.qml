import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_labelSource: labelSource.currentIndex
    property alias cfg_maxLabelWidth: maxLabelWidth.value
    property alias cfg_iconSize: iconSize.value
    property alias cfg_groupWindows: groupWindows.checked
    property alias cfg_onlyCurrentDesktop: onlyCurrentDesktop.checked
    property alias cfg_onlyCurrentScreen: onlyCurrentScreen.checked
    property alias cfg_minimizeActive: minimizeActive.checked
    property alias cfg_showHoverPill: showHoverPill.checked
    property alias cfg_accentLabels: accentLabels.checked
    property alias cfg_reserveSpace: reserveSpace.checked
    property alias cfg_hidePanelBackground: hidePanelBackground.checked

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: labelSource
            Kirigami.FormData.label: i18n("Popisek při najetí:")
            model: [i18n("Název okna"), i18n("Název aplikace")]
        }

        QQC2.SpinBox {
            id: maxLabelWidth
            Kirigami.FormData.label: i18n("Max. šířka popisku (px):")
            from: 60
            to: 800
            stepSize: 10
        }

        QQC2.SpinBox {
            id: iconSize
            Kirigami.FormData.label: i18n("Velikost ikon (px, 0 = podle panelu):")
            from: 0
            to: 128
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: groupWindows
            Kirigami.FormData.label: i18n("Chování:")
            text: i18n("Seskupovat okna stejné aplikace")
        }

        QQC2.CheckBox {
            id: onlyCurrentDesktop
            text: i18n("Jen okna z aktuální plochy")
        }

        QQC2.CheckBox {
            id: onlyCurrentScreen
            text: i18n("Jen okna z obrazovky tohoto panelu")
        }

        QQC2.CheckBox {
            id: minimizeActive
            text: i18n("Klik na aktivní okno ho minimalizuje")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: showHoverPill
            Kirigami.FormData.label: i18n("Vzhled:")
            text: i18n("Zvýrazňující pozadí při najetí myší")
        }

        QQC2.CheckBox {
            id: accentLabels
            text: i18n("Popisky v barvě akcentu systému")
        }

        QQC2.CheckBox {
            id: reserveSpace
            text: i18n("Rezervovat místo pro rozbalení (popisek nepřeteče přes okraj)")
        }

        QQC2.CheckBox {
            id: hidePanelBackground
            text: i18n("Skrýt pozadí panelu, ve kterém je tento widget")
        }
    }
}
