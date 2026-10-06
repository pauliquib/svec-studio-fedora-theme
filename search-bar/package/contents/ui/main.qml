import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.milou as Milou

PlasmoidItem {
    id: root

    property string query: ""
    property Item resultsView
    property Item popupField
    property Item compactField
    property bool pendingRun: false

    compactRepresentation: compactComp
    fullRepresentation: fullComp

    Component.onCompleted: Plasmoid.globalShortcut = "Ctrl+K"
    Plasmoid.onActivated: {
        if (compactField) {
            compactField.forceActiveFocus()
        }
    }

    function reset() {
        query = ""
        pendingRun = false
        expanded = false
        if (compactField) compactField.focus = false
        if (popupField) popupField.focus = false
    }

    function runCurrent() {
        if (resultsView) {
            resultsView.runCurrentIndex(null)
        } else {
            pendingRun = true
            expanded = true
        }
    }

    onExpandedChanged: {
        if (expanded && popupField) {
            popupField.forceActiveFocus()
        } else if (!expanded && compactField) {
            compactField.focus = false
        }
    }

    Component {
        id: compactComp

        Item {
            Layout.minimumWidth: Kirigami.Units.gridUnit * 26
            Layout.preferredWidth: Kirigami.Units.gridUnit * 30
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
            Layout.fillHeight: true
            implicitWidth: Layout.preferredWidth

        PlasmaComponents3.TextField {
            id: field
            anchors.fill: parent
            anchors.margins: Plasmoid.configuration.spacing
            cursorVisible: activeFocus && Window.active !== false
            placeholderText: i18n("Hledat nebo přejít…")
            text: root.query
            leftPadding: searchIcon.x + searchIcon.width + Kirigami.Units.largeSpacing
            rightPadding: shortcutChip.width + Kirigami.Units.largeSpacing * 1.5
            verticalAlignment: TextInput.AlignVCenter

            background: Rectangle {
                radius: height / 2
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.09)
                border.width: 1
                border.color: field.activeFocus
                    ? Kirigami.Theme.focusColor
                    : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.18)
            }

            Kirigami.Icon {
                id: searchIcon
                source: "system-search"
                width: Kirigami.Units.iconSizes.small
                height: width
                anchors.left: parent.left
                anchors.leftMargin: Kirigami.Units.largeSpacing
                anchors.verticalCenter: parent.verticalCenter
                opacity: 0.65
            }

            Rectangle {
                id: shortcutChip
                anchors.right: parent.right
                anchors.rightMargin: Kirigami.Units.smallSpacing * 1.5
                anchors.verticalCenter: parent.verticalCenter
                width: chipLabel.implicitWidth + Kirigami.Units.largeSpacing
                height: chipLabel.implicitHeight + Kirigami.Units.smallSpacing
                radius: Kirigami.Units.smallSpacing * 0.75
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
                border.width: 1
                border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                visible: field.text.length === 0

                PlasmaComponents3.Label {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: "Ctrl+K"
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                }
            }

            onTextEdited: {
                root.query = text
                if (text.length > 0) {
                    root.expanded = true
                }
            }
            onAccepted: root.runCurrent()

            Keys.onEscapePressed: root.reset()
            Keys.onDownPressed: if (root.resultsView) root.resultsView.incrementCurrentIndex()
            Keys.onUpPressed: if (root.resultsView) root.resultsView.decrementCurrentIndex()

            Connections {
                target: field.Window.window
                function onActiveChanged() {
                    if (!field.Window.active) {
                        field.focus = false
                    }
                }
            }

            Component.onCompleted: root.compactField = field
            Component.onDestruction: root.compactField = null
        }
        }
    }

    Component {
        id: fullComp

        Item {
            implicitWidth: Kirigami.Units.gridUnit * 32
            implicitHeight: Kirigami.Units.gridUnit * 22

            ColumnLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.TextField {
                    id: popupTextField
                    Layout.fillWidth: true
                    placeholderText: i18n("Hledat nebo přejít…")
                    text: root.query

                    onTextEdited: root.query = text
                    onAccepted: results.runCurrentIndex(null)
                    Keys.onEscapePressed: root.reset()
                    Keys.onDownPressed: results.incrementCurrentIndex()
                    Keys.onUpPressed: results.decrementCurrentIndex()

                    Component.onCompleted: root.popupField = popupTextField
                    Component.onDestruction: root.popupField = null
                }

                Milou.ResultsView {
                    id: results
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    queryString: root.query
                    queryField: popupTextField

                    onActivated: root.reset()
                    onUpdateQueryString: (text, pos) => {
                        root.query = text
                        if (popupTextField) popupTextField.cursorPosition = pos
                    }

                    Component.onCompleted: {
                        root.resultsView = results
                        if (root.pendingRun) {
                            root.pendingRun = false
                            results.runAutomatically = true
                        }
                    }
                    Component.onDestruction: root.resultsView = null
                }
            }
        }
    }
}
