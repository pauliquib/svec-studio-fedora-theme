/*
 * Content of the hover popup: one live thumbnail card per window of a task.
 * `windows` is a list of { row, child, title, uuid, minimized, icon }.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.pipewire as PipeWire
import org.kde.taskmanager as TaskManager

Item {
    id: previews

    property var windows: []
    property real maxWidth: 1600
    readonly property bool hovered: hover.hovered

    signal activateWindow(int row, int child)
    signal closeWindow(int row, int child)
    signal highlightWindow(string uuid)

    readonly property real cardWidth: {
        const n = Math.max(1, windows.length)
        const ideal = Kirigami.Units.gridUnit * 14
        return Math.max(Kirigami.Units.gridUnit * 7,
                        Math.min(ideal, (maxWidth - (n - 1) * Kirigami.Units.smallSpacing) / n))
    }

    implicitWidth: cards.implicitWidth
    implicitHeight: cards.implicitHeight

    HoverHandler { id: hover }

    Row {
        id: cards
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: previews.windows

            delegate: Item {
                id: card

                required property var modelData

                width: previews.cardWidth
                height: header.height + Kirigami.Units.smallSpacing + thumbnail.height

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -Kirigami.Units.smallSpacing / 2
                    radius: Kirigami.Units.cornerRadius
                    color: Kirigami.Theme.highlightColor
                    opacity: cardHover.hovered ? 0.2 : 0
                    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                }

                HoverHandler {
                    id: cardHover
                    onHoveredChanged: previews.highlightWindow(hovered ? card.modelData.uuid : "")
                }

                TapHandler {
                    onTapped: previews.activateWindow(card.modelData.row, card.modelData.child)
                }

                RowLayout {
                    id: header
                    width: parent.width
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: card.modelData.icon
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    }
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: card.modelData.title
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.weight: Font.DemiBold
                    }
                    PlasmaComponents3.ToolButton {
                        icon.name: "window-close"
                        display: QQC2.AbstractButton.IconOnly
                        text: i18n("Close")
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 2
                        Layout.preferredHeight: Layout.preferredWidth
                        onClicked: previews.closeWindow(card.modelData.row, card.modelData.child)
                    }
                }

                Item {
                    id: thumbnail
                    anchors.top: header.bottom
                    anchors.topMargin: Kirigami.Units.smallSpacing
                    width: parent.width
                    height: Math.round(width * 9 / 16)

                    TaskManager.ScreencastingRequest {
                        id: cast
                        uuid: card.modelData.minimized ? "" : card.modelData.uuid
                    }

                    PipeWire.PipeWireSourceItem {
                        id: stream
                        anchors.fill: parent
                        nodeId: cast.nodeId
                        visible: nodeId > 0 && ready
                    }

                    // Fallback for minimized windows or while the stream starts
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Kirigami.Units.iconSizes.huge
                        height: width
                        source: card.modelData.icon
                        visible: !stream.visible
                        opacity: 0.8
                    }
                }
            }
        }
    }
}
