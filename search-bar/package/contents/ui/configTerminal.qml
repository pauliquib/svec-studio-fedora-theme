import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

import "../code/terminals.js" as Terminals

Item {
    id: root

    property alias cfg_terminalEnabled: terminalEnabledCheck.checked
    property alias cfg_terminalPrefix: prefixField.text
    property string cfg_terminalApp
    property alias cfg_terminalCustom: customField.text
    property alias cfg_terminalKeepOpen: keepOpenCheck.checked
    property alias cfg_terminalWorkdir: workdirField.text
    property alias cfg_terminalBackgroundEnabled: backgroundCheck.checked
    property alias cfg_terminalBackgroundDefault: backgroundDefaultCheck.checked
    property alias cfg_terminalSudoEnabled: sudoCheck.checked
    property alias cfg_terminalSuggestCommands: suggestCommandsCheck.checked
    property alias cfg_terminalSuggestPaths: suggestPathsCheck.checked
    property alias cfg_terminalSuggestMax: suggestMaxSpin.value
    property alias cfg_terminalHistoryEnabled: historyCheck.checked
    property alias cfg_terminalHistoryMax: historyMaxSpin.value
    property var cfg_terminalHistory: []

    // Names of terminal executables found in $PATH
    property var installed: []

    P5Support.DataSource {
        id: detector
        engine: "executable"
        onNewData: (sourceName, data) => {
            root.installed = data.stdout.trim().split("\n")
            disconnectSource(sourceName)
        }
        Component.onCompleted: {
            const bins = Terminals.list.filter(t => t.bin).map(t => t.bin).join(" ")
            connectSource("for t in " + bins + "; do command -v \"$t\" >/dev/null && echo \"$t\"; done")
        }
    }

    Dialogs.FolderDialog {
        id: folderDialog
        title: i18n("Vyberte pracovní složku")
        onAccepted: workdirField.text = decodeURIComponent(selectedFolder.toString().replace(/^file:\/\//, ""))
    }

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.CheckBox {
            id: terminalEnabledCheck
            Kirigami.FormData.label: i18n("Příkazy:")
            text: i18n("Spouštět příkazy v terminálu")
        }

        QQC2.TextField {
            id: prefixField
            Kirigami.FormData.label: i18n("Prefix:")
            enabled: terminalEnabledCheck.checked
            maximumLength: 4
            implicitWidth: Kirigami.Units.gridUnit * 4
        }

        QQC2.ComboBox {
            id: terminalCombo
            Kirigami.FormData.label: i18n("Terminál:")
            enabled: terminalEnabledCheck.checked
            textRole: "text"
            valueRole: "value"
            model: Terminals.list.map(t => ({
                value: t.value,
                text: (t.bin && root.installed.length > 0 && root.installed.indexOf(t.bin) < 0)
                    ? i18n("%1 (nenainstalováno)", t.text)
                    : t.text
            }))
            onModelChanged: currentIndex = Math.max(0, indexOfValue(root.cfg_terminalApp))
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(root.cfg_terminalApp))
            onActivated: root.cfg_terminalApp = currentValue
        }

        QQC2.TextField {
            id: customField
            Kirigami.FormData.label: i18n("Vlastní příkaz:")
            visible: root.cfg_terminalApp === "custom"
            enabled: terminalEnabledCheck.checked
            placeholderText: "myterm -e"
            implicitWidth: Kirigami.Units.gridUnit * 14
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Pracovní složka:")
            enabled: terminalEnabledCheck.checked

            QQC2.TextField {
                id: workdirField
                placeholderText: i18n("~ (domovská složka)")
                implicitWidth: Kirigami.Units.gridUnit * 12
            }
            QQC2.Button {
                icon.name: "document-open-folder"
                display: QQC2.AbstractButton.IconOnly
                text: i18n("Vybrat složku…")
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
                onClicked: folderDialog.open()
            }
        }

        QQC2.CheckBox {
            id: keepOpenCheck
            enabled: terminalEnabledCheck.checked
            text: i18n("Ponechat terminál otevřený po dokončení příkazu")
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Akce")
        }

        QQC2.CheckBox {
            id: backgroundCheck
            Kirigami.FormData.label: i18n("Na pozadí:")
            enabled: terminalEnabledCheck.checked
            text: i18n("Povolit spouštění na pozadí s výstupem v oznámení")
        }

        QQC2.CheckBox {
            id: backgroundDefaultCheck
            enabled: terminalEnabledCheck.checked && backgroundCheck.checked
            text: i18n("Enter spouští příkaz na pozadí místo v okně terminálu")
        }

        QQC2.CheckBox {
            id: sudoCheck
            Kirigami.FormData.label: i18n("Root:")
            enabled: terminalEnabledCheck.checked
            text: i18n("Povolit akci „Spustit jako root“")
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Návrhy při psaní")
        }

        QQC2.CheckBox {
            id: suggestCommandsCheck
            Kirigami.FormData.label: i18n("Návrhy:")
            enabled: terminalEnabledCheck.checked
            text: i18n("Příkazy z $PATH (první slovo)")
        }

        QQC2.CheckBox {
            id: suggestPathsCheck
            enabled: terminalEnabledCheck.checked
            text: i18n("Soubory a složky (slova začínající /, ~ nebo ./)")
        }

        QQC2.SpinBox {
            id: suggestMaxSpin
            Kirigami.FormData.label: i18n("Počet návrhů:")
            enabled: terminalEnabledCheck.checked && (suggestCommandsCheck.checked || suggestPathsCheck.checked)
            from: 1
            to: 20
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Historie")
        }

        QQC2.CheckBox {
            id: historyCheck
            Kirigami.FormData.label: i18n("Historie:")
            enabled: terminalEnabledCheck.checked
            text: i18n("Pamatovat si spuštěné příkazy")
        }

        QQC2.SpinBox {
            id: historyMaxSpin
            Kirigami.FormData.label: i18n("Počet příkazů:")
            enabled: terminalEnabledCheck.checked && historyCheck.checked
            from: 1
            to: 1000
        }

        QQC2.Button {
            icon.name: "edit-clear-history"
            text: i18n("Vymazat historii příkazů")
            enabled: (root.cfg_terminalHistory || []).length > 0
            onClicked: root.cfg_terminalHistory = []
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            enabled: terminalEnabledCheck.checked
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.75
            text: i18n("Napište „%1 příkaz“ a stiskněte Enter; samotný prefix otevře prázdný terminál. Ctrl+Enter spustí v terminálu cokoliv, co je v poli napsáno. Shift+Enter a Alt+Enter spustí první a druhou akci (např. na pozadí nebo jako root). Při psaní se nabízejí příkazy, cesty a dříve spuštěné příkazy; Tab doplní vybraný návrh do pole.", prefixField.text)
        }
    }
}
