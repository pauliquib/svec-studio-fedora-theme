import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root

    property alias cfg_spacing: spacingSpin.value

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
    }
}
