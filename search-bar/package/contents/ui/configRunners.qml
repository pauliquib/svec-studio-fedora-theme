import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root

    property alias cfg_runnerFilterEnabled: enabledCheck.checked
    property var cfg_runnerFilter: []

    implicitHeight: layout.implicitHeight

    InstalledRunners {
        id: installedRunners
    }

    function nameOf(id) {
        for (const r of installedRunners.runners) {
            if (r.id === id) return r.name
        }
        return installedRunners.nameFor(id, id)
    }

    // Always assign a new array so the configuration dialog notices the change
    function move(index, delta) {
        const list = cfg_runnerFilter.slice()
        const target = index + delta
        if (target < 0 || target >= list.length) return
        const item = list.splice(index, 1)[0]
        list.splice(target, 0, item)
        cfg_runnerFilter = list
    }

    function remove(index) {
        const list = cfg_runnerFilter.slice()
        list.splice(index, 1)
        cfg_runnerFilter = list
    }

    function add(id) {
        if (!id || cfg_runnerFilter.indexOf(id) >= 0) return
        cfg_runnerFilter = cfg_runnerFilter.concat([id])
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.largeSpacing

        QQC2.CheckBox {
            id: enabledCheck
            text: i18n("Používat jen vybrané runnery KRunneru v tomto pořadí")
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.75
            text: i18n("Když je volba vypnutá, použijí se všechny runnery povolené v Nastavení systému → Hledání. Když je zapnutá, výsledky se zobrazí jen z níže uvedených runnerů, seskupené v uvedeném pořadí.")
        }

        Repeater {
            model: root.cfg_runnerFilter

            RowLayout {
                required property string modelData
                required property int index
                Layout.fillWidth: true
                enabled: enabledCheck.checked

                QQC2.Label {
                    text: (index + 1) + "."
                    opacity: 0.6
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.nameOf(modelData) + "  (" + modelData + ")"
                }
                QQC2.ToolButton {
                    icon.name: "arrow-up"
                    enabled: index > 0
                    onClicked: root.move(index, -1)
                    QQC2.ToolTip.text: i18n("Posunout nahoru")
                    QQC2.ToolTip.visible: hovered
                }
                QQC2.ToolButton {
                    icon.name: "arrow-down"
                    enabled: index < root.cfg_runnerFilter.length - 1
                    onClicked: root.move(index, 1)
                    QQC2.ToolTip.text: i18n("Posunout dolů")
                    QQC2.ToolTip.visible: hovered
                }
                QQC2.ToolButton {
                    icon.name: "list-remove"
                    onClicked: root.remove(index)
                    QQC2.ToolTip.text: i18n("Odebrat")
                    QQC2.ToolTip.visible: hovered
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            enabled: enabledCheck.checked

            QQC2.ComboBox {
                id: addCombo
                Layout.fillWidth: true
                textRole: "text"
                valueRole: "value"
                model: installedRunners.runners
                    .filter(r => root.cfg_runnerFilter.indexOf(r.id) < 0)
                    .map(r => ({ value: r.id, text: r.name + "  (" + r.id + ")" }))
            }
            QQC2.Button {
                icon.name: "list-add"
                text: i18n("Přidat")
                enabled: addCombo.count > 0
                onClicked: root.add(addCombo.currentValue)
            }
        }
    }
}
