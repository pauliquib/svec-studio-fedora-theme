import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root

    property alias cfg_aliasesEnabled: enabledCheck.checked
    property var cfg_aliases: []

    // Lower-cased names that occur more than once
    property var duplicates: []

    implicitHeight: layout.implicitHeight

    readonly property var modes: [
        { value: "terminal", text: i18n("V terminálu") },
        { value: "background", text: i18n("Na pozadí s notifikací") },
        { value: "silent", text: i18n("Tiše") },
        { value: "open", text: i18n("Otevřít URL/soubor") }
    ]

    // Working copy; edited in place so the row delegates (and focus) survive typing.
    ListModel { id: aliasModel }

    function load() {
        aliasModel.clear()
        for (const raw of root.cfg_aliases || []) {
            try {
                const a = JSON.parse(raw)
                aliasModel.append({ name: a.name || "", command: a.command || "",
                                    mode: a.mode || "terminal", workdir: a.workdir || "" })
            } catch (err) {
                // skip invalid entries
            }
        }
        updateDuplicates()
    }

    // Assign a new array so the config dialog notices the change.
    function save() {
        const out = []
        for (let i = 0; i < aliasModel.count; ++i) {
            const a = aliasModel.get(i)
            out.push(JSON.stringify({ name: a.name.trim(), command: a.command, mode: a.mode, workdir: a.workdir.trim() }))
        }
        root.cfg_aliases = out
        updateDuplicates()
    }

    function updateDuplicates() {
        const seen = {}
        const dups = []
        for (let i = 0; i < aliasModel.count; ++i) {
            const n = aliasModel.get(i).name.trim().toLowerCase()
            if (n === "") {
                continue
            }
            if (seen[n] && dups.indexOf(n) < 0) {
                dups.push(n)
            }
            seen[n] = true
        }
        duplicates = dups
    }

    function setField(index, field, value) {
        if (aliasModel.get(index)[field] !== value) {
            aliasModel.setProperty(index, field, value)
            save()
        }
    }

    Component.onCompleted: load()

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.smallSpacing

        QQC2.CheckBox {
            id: enabledCheck
            text: i18n("Povolit vlastní příkazy a aliasy")
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.75
            text: i18n("Alias se spustí, když první slovo dotazu odpovídá jeho názvu; další slova jsou argumenty. Výskyt %s v příkazu se nahradí argumenty, jinak se argumenty připojí na konec. Příklady: „gs“ → „git status“; „yt“ → „https://youtube.com/results?search_query=%s“ v režimu Otevřít URL/soubor (napište „yt kočky“).")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Warning
            visible: root.duplicates.length > 0
            text: i18n("Duplicitní názvy aliasů: %1. Použije se jen první z nich.", root.duplicates.join(", "))
        }

        RowLayout {
            enabled: enabledCheck.checked
            visible: aliasModel.count > 0
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label { text: i18n("Název"); Layout.preferredWidth: Kirigami.Units.gridUnit * 5 }
            QQC2.Label { text: i18n("Příkaz / URL"); Layout.fillWidth: true }
            QQC2.Label { text: i18n("Režim"); Layout.preferredWidth: Kirigami.Units.gridUnit * 10 }
            QQC2.Label { text: i18n("Pracovní složka"); Layout.preferredWidth: Kirigami.Units.gridUnit * 7 }
            Item { Layout.preferredWidth: removeMetrics.implicitWidth }
        }

        QQC2.ToolButton {
            id: removeMetrics
            visible: false
            icon.name: "list-remove"
        }

        Repeater {
            model: aliasModel

            delegate: RowLayout {
                id: row
                required property int index
                required property string name
                required property string command
                required property string mode
                required property string workdir

                Layout.fillWidth: true
                enabled: enabledCheck.checked
                spacing: Kirigami.Units.smallSpacing

                QQC2.TextField {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                    text: row.name
                    placeholderText: "gs"
                    color: root.duplicates.indexOf(row.name.trim().toLowerCase()) >= 0
                        ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                    onTextEdited: root.setField(row.index, "name", text)
                }

                QQC2.TextField {
                    Layout.fillWidth: true
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 10
                    text: row.command
                    placeholderText: "git status"
                    onTextEdited: root.setField(row.index, "command", text)
                }

                QQC2.ComboBox {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                    textRole: "text"
                    valueRole: "value"
                    model: root.modes
                    Component.onCompleted: currentIndex = Math.max(0, indexOfValue(row.mode))
                    onActivated: root.setField(row.index, "mode", currentValue)
                }

                QQC2.TextField {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                    text: row.workdir
                    placeholderText: "~"
                    enabled: row.mode !== "open"
                    onTextEdited: root.setField(row.index, "workdir", text)
                }

                QQC2.ToolButton {
                    icon.name: "list-remove"
                    QQC2.ToolTip.text: i18n("Odebrat alias")
                    QQC2.ToolTip.visible: hovered
                    onClicked: {
                        aliasModel.remove(row.index)
                        root.save()
                    }
                }
            }
        }

        QQC2.Button {
            enabled: enabledCheck.checked
            icon.name: "list-add"
            text: i18n("Přidat alias")
            onClicked: {
                aliasModel.append({ name: "", command: "", mode: "terminal", workdir: "" })
                root.save()
            }
        }
    }
}
