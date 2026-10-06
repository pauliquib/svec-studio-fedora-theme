import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Item {
    id: root

    property alias cfg_systemEnabled: systemEnabledCheck.checked
    property alias cfg_systemPrefix: systemPrefixField.text
    property alias cfg_systemConfirm: systemConfirmCheck.checked
    property alias cfg_webEnabled: webEnabledCheck.checked
    property alias cfg_webPrefix: webPrefixField.text
    property var cfg_webEngines: []
    property alias cfg_helpEnabled: helpEnabledCheck.checked
    property alias cfg_helpPrefix: helpPrefixField.text
    property alias cfg_runnerModesEnabled: runnerModesEnabledCheck.checked
    property var cfg_runnerModes: []

    // True while this page writes the StringList keys itself, so that only
    // external changes (e.g. the "Defaults" button) reload the working copies.
    property bool saving: false

    // Prefixes used by more than one enabled mode (other pages: saved values)
    readonly property var duplicates: {
        const used = []
        const add = (enabled, prefix) => { if (enabled && prefix) used.push(prefix) }
        add(Plasmoid.configuration.terminalEnabled, Plasmoid.configuration.terminalPrefix)
        add(Plasmoid.configuration.filesEnabled, Plasmoid.configuration.filesPrefix)
        add(systemEnabledCheck.checked, systemPrefixField.text)
        add(webEnabledCheck.checked, webPrefixField.text)
        add(helpEnabledCheck.checked, helpPrefixField.text)
        if (runnerModesEnabledCheck.checked) {
            (cfg_runnerModes || []).forEach(line => add(true, String(line).split("|")[0]))
        }
        return used.filter((p, i) => used.indexOf(p) !== i).filter((p, i, a) => a.indexOf(p) === i)
    }

    InstalledRunners { id: installedRunners }

    ListModel { id: engineModel }   // { name, url }
    ListModel { id: runnerModel }   // { prefix, runner, label }

    function loadEngines() {
        engineModel.clear()
        ;(cfg_webEngines || []).forEach(line => {
            const sep = String(line).indexOf("|")
            engineModel.append(sep < 0 ? { name: String(line), url: "" }
                                       : { name: line.slice(0, sep), url: line.slice(sep + 1) })
        })
    }

    function loadRunners() {
        runnerModel.clear()
        ;(cfg_runnerModes || []).forEach(line => {
            const parts = String(line).split("|")
            runnerModel.append({ prefix: parts[0] || "", runner: parts[1] || "", label: parts.slice(2).join("|") })
        })
    }

    function saveEngines() {
        const list = []
        for (let i = 0; i < engineModel.count; ++i) {
            const e = engineModel.get(i)
            const name = e.name.replace(/\|/g, "").trim()
            if (name || e.url.trim()) list.push(name + "|" + e.url.trim())
        }
        saving = true
        cfg_webEngines = list
        saving = false
    }

    function saveRunners() {
        const list = []
        for (let i = 0; i < runnerModel.count; ++i) {
            const r = runnerModel.get(i)
            const prefix = r.prefix.replace(/\|/g, "").trim()
            const runner = r.runner.replace(/\|/g, "").trim()
            if (prefix || runner) list.push(prefix + "|" + runner + "|" + r.label.trim())
        }
        saving = true
        cfg_runnerModes = list
        saving = false
    }

    onCfg_webEnginesChanged: if (!saving) loadEngines()
    onCfg_runnerModesChanged: if (!saving) loadRunners()
    Component.onCompleted: {
        loadEngines()
        loadRunners()
    }

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Warning
            visible: root.duplicates.length > 0
            text: i18n("Stejný prefix používá více režimů: %1", root.duplicates.join("  "))
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Systémové akce")
        }

        QQC2.CheckBox {
            id: systemEnabledCheck
            Kirigami.FormData.label: i18n("Systémové akce:")
            text: i18n("Zamknout, odhlásit, uspat, restartovat, vypnout…")
        }

        QQC2.TextField {
            id: systemPrefixField
            Kirigami.FormData.label: i18n("Prefix:")
            enabled: systemEnabledCheck.checked
            maximumLength: 4
            implicitWidth: Kirigami.Units.gridUnit * 4
        }

        QQC2.CheckBox {
            id: systemConfirmCheck
            enabled: systemEnabledCheck.checked
            text: i18n("Potvrzovat odhlášení, restart a vypnutí dialogem Plasmy")
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Web")
        }

        QQC2.CheckBox {
            id: webEnabledCheck
            Kirigami.FormData.label: i18n("Hledání na webu:")
            text: i18n("Povolit")
        }

        QQC2.TextField {
            id: webPrefixField
            Kirigami.FormData.label: i18n("Prefix:")
            enabled: webEnabledCheck.checked
            maximumLength: 4
            implicitWidth: Kirigami.Units.gridUnit * 4
        }

        ColumnLayout {
            Kirigami.FormData.label: i18n("Vyhledávače:")
            Kirigami.FormData.labelAlignment: Qt.AlignTop
            enabled: webEnabledCheck.checked

            Repeater {
                model: engineModel

                RowLayout {
                    required property int index
                    required property string name
                    required property string url

                    QQC2.TextField {
                        implicitWidth: Kirigami.Units.gridUnit * 7
                        text: name
                        placeholderText: i18n("Název")
                        onTextEdited: {
                            engineModel.setProperty(index, "name", text)
                            root.saveEngines()
                        }
                    }
                    QQC2.TextField {
                        implicitWidth: Kirigami.Units.gridUnit * 16
                        text: url
                        placeholderText: "https://example.com/?q=%s"
                        onTextEdited: {
                            engineModel.setProperty(index, "url", text)
                            root.saveEngines()
                        }
                    }
                    QQC2.ToolButton {
                        icon.name: "arrow-up"
                        enabled: index > 0
                        onClicked: { engineModel.move(index, index - 1, 1); root.saveEngines() }
                        QQC2.ToolTip.text: i18n("Posunout nahoru")
                        QQC2.ToolTip.visible: hovered
                    }
                    QQC2.ToolButton {
                        icon.name: "arrow-down"
                        enabled: index < engineModel.count - 1
                        onClicked: { engineModel.move(index, index + 1, 1); root.saveEngines() }
                        QQC2.ToolTip.text: i18n("Posunout dolů")
                        QQC2.ToolTip.visible: hovered
                    }
                    QQC2.ToolButton {
                        icon.name: "list-remove"
                        onClicked: { engineModel.remove(index); root.saveEngines() }
                        QQC2.ToolTip.text: i18n("Odebrat")
                        QQC2.ToolTip.visible: hovered
                    }
                }
            }

            QQC2.Button {
                icon.name: "list-add"
                text: i18n("Přidat vyhledávač")
                onClicked: engineModel.append({ name: "", url: "" })
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 26
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.75
                text: i18n("%s v adrese se nahradí hledaným výrazem. První vyhledávač je výchozí. Napište „%1g rust“ nebo „%1wiki Praha“ pro hledání jen v jednom vyhledávači.", webPrefixField.text)
            }
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Nápověda")
        }

        QQC2.CheckBox {
            id: helpEnabledCheck
            Kirigami.FormData.label: i18n("Nápověda:")
            text: i18n("Zobrazit seznam prefixů a klávesových zkratek")
        }

        QQC2.TextField {
            id: helpPrefixField
            Kirigami.FormData.label: i18n("Prefix:")
            enabled: helpEnabledCheck.checked
            maximumLength: 4
            implicitWidth: Kirigami.Units.gridUnit * 4
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Prefixy runnerů KRunneru")
        }

        QQC2.CheckBox {
            id: runnerModesEnabledCheck
            Kirigami.FormData.label: i18n("Prefixy runnerů:")
            text: i18n("Prefix omezí hledání na jeden runner")
        }

        ColumnLayout {
            Kirigami.FormData.label: i18n("Prefixy:")
            Kirigami.FormData.labelAlignment: Qt.AlignTop
            enabled: runnerModesEnabledCheck.checked

            Repeater {
                model: runnerModel

                RowLayout {
                    required property int index
                    required property string prefix
                    required property string runner
                    required property string label

                    QQC2.TextField {
                        implicitWidth: Kirigami.Units.gridUnit * 3
                        maximumLength: 4
                        text: prefix
                        placeholderText: i18n("Prefix")
                        onTextEdited: {
                            runnerModel.setProperty(index, "prefix", text)
                            root.saveRunners()
                        }
                    }

                    QQC2.ComboBox {
                        id: runnerCombo
                        implicitWidth: Kirigami.Units.gridUnit * 11
                        editable: true
                        model: installedRunners.runners
                        textRole: "id"
                        valueRole: "id"

                        delegate: QQC2.ItemDelegate {
                            required property var modelData
                            required property int index
                            width: runnerCombo.popup.width
                            text: modelData.name + "  (" + modelData.id + ")"
                            highlighted: runnerCombo.highlightedIndex === index
                        }

                        function setRunner(id) {
                            runnerModel.setProperty(parent.index, "runner", id)
                            root.saveRunners()
                        }
                        function restore() {
                            currentIndex = indexOfValue(parent.runner)
                            editText = parent.runner
                        }

                        Component.onCompleted: restore()
                        onModelChanged: Qt.callLater(restore)
                        onActivated: index => setRunner(valueAt(index))
                        onAccepted: setRunner(editText)

                        Connections {
                            target: runnerCombo.contentItem
                            ignoreUnknownSignals: true
                            function onTextEdited() { runnerCombo.setRunner(runnerCombo.editText) }
                        }
                    }

                    QQC2.TextField {
                        Layout.fillWidth: true
                        implicitWidth: Kirigami.Units.gridUnit * 8
                        text: label
                        placeholderText: i18n("Popis")
                        onTextEdited: {
                            runnerModel.setProperty(index, "label", text)
                            root.saveRunners()
                        }
                    }

                    QQC2.ToolButton {
                        icon.name: "list-remove"
                        onClicked: { runnerModel.remove(index); root.saveRunners() }
                        QQC2.ToolTip.text: i18n("Odebrat")
                        QQC2.ToolTip.visible: hovered
                    }
                }
            }

            QQC2.Button {
                icon.name: "list-add"
                text: i18n("Přidat prefix")
                onClicked: runnerModel.append({ prefix: "", runner: "", label: "" })
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 26
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.75
                text: i18n("Např. „@ okno“ hledá jen mezi otevřenými okny. Runner vyberte ze seznamu nebo napište jeho id.")
            }
        }
    }
}
