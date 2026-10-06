import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

Item {
    id: root

    property alias cfg_filesEnabled: enabledCheck.checked
    property alias cfg_filesPrefix: prefixField.text
    property alias cfg_filesDirectory: directoryField.text
    property string cfg_filesTool
    property alias cfg_filesMaxResults: maxResultsSpin.value
    property alias cfg_filesShowHidden: hiddenCheck.checked
    property alias cfg_filesOpenCommand: openCommandField.text

    // Search tools found in $PATH ("fd" also when only "fdfind" exists)
    property var installed: []
    property bool detected: false

    readonly property var tools: [
        { value: "auto", text: i18n("Automaticky (fd, jinak find)"), bin: "" },
        { value: "fd", text: "fd", bin: "fd" },
        { value: "find", text: "find", bin: "find" },
        { value: "locate", text: "locate", bin: "locate" },
        { value: "baloo", text: i18n("Baloo (baloosearch6)"), bin: "baloosearch6" }
    ]

    P5Support.DataSource {
        id: detector
        engine: "executable"
        onNewData: (sourceName, data) => {
            const found = data.stdout.trim().split("\n")
            if (found.indexOf("fdfind") >= 0) found.push("fd")
            root.installed = found
            root.detected = true
            disconnectSource(sourceName)
        }
        Component.onCompleted: connectSource(
            "for t in fd fdfind find locate baloosearch6; do command -v \"$t\" >/dev/null && echo \"$t\"; done")
    }

    FolderDialog {
        id: folderDialog
        title: i18n("Vyberte složku pro hledání")
        onAccepted: directoryField.text = decodeURIComponent(selectedFolder.toString().replace(/^file:\/\//, ""))
    }

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.CheckBox {
            id: enabledCheck
            Kirigami.FormData.label: i18n("Soubory:")
            text: i18n("Povolit hledání souborů")
        }

        QQC2.TextField {
            id: prefixField
            Kirigami.FormData.label: i18n("Prefix:")
            enabled: enabledCheck.checked
            maximumLength: 4
            implicitWidth: Kirigami.Units.gridUnit * 4
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Hledat ve složce:")
            enabled: enabledCheck.checked

            QQC2.TextField {
                id: directoryField
                placeholderText: i18n("Domovská složka")
                implicitWidth: Kirigami.Units.gridUnit * 14
            }

            QQC2.Button {
                icon.name: "document-open-folder"
                text: i18n("Vybrat…")
                onClicked: folderDialog.open()
            }
        }

        QQC2.ComboBox {
            id: toolCombo
            Kirigami.FormData.label: i18n("Nástroj:")
            enabled: enabledCheck.checked
            textRole: "text"
            valueRole: "value"
            model: root.tools.map(t => ({
                value: t.value,
                text: (t.bin && root.detected && root.installed.indexOf(t.bin) < 0)
                    ? i18n("%1 (nenainstalováno)", t.text)
                    : t.text
            }))
            onModelChanged: currentIndex = Math.max(0, indexOfValue(root.cfg_filesTool))
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(root.cfg_filesTool))
            onActivated: root.cfg_filesTool = currentValue
        }

        QQC2.SpinBox {
            id: maxResultsSpin
            Kirigami.FormData.label: i18n("Maximum výsledků:")
            enabled: enabledCheck.checked
            from: 1
            to: 200
            stepSize: 5
        }

        QQC2.CheckBox {
            id: hiddenCheck
            enabled: enabledCheck.checked
            text: i18n("Hledat i ve skrytých souborech a složkách")
        }

        QQC2.TextField {
            id: openCommandField
            Kirigami.FormData.label: i18n("Otevřít příkazem:")
            enabled: enabledCheck.checked
            placeholderText: "code %f"
            implicitWidth: Kirigami.Units.gridUnit * 14
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            enabled: enabledCheck.checked
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.75
            text: i18n("Prázdné = výchozí aplikace. %f se nahradí cestou k souboru, jinak se cesta přidá na konec příkazu.")
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            enabled: enabledCheck.checked
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.75
            text: i18n("Napište „%1název“ – stačí jen některá písmena v pořadí (např. „%1dkmt“ najde Dokumenty). Lomítko v dotazu hledá v celé cestě. Složky .git, node_modules a .cache se přeskakují. Shift+Enter otevře složku se souborem.", prefixField.text)
        }
    }
}
