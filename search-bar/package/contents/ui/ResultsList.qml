import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

import "../code/util.js" as Util

// List of provider result items (see docs/ARCHITECTURE.md). Selection is driven
// by the core through `currentIndex`; the view is not interactive by itself so
// that it can be stacked with the KRunner result views in one scroll area.
ListView {
    id: list

    property var items: []
    property string pattern: ""
    property bool showHeaders: true
    property bool highlightMatches: true
    property bool showActions: true
    property bool selected: false

    signal itemClicked(int index)
    signal actionClicked(int index, int actionIndex)

    model: items
    interactive: false
    implicitHeight: contentHeight
    currentIndex: -1

    delegate: Item {
        id: row

        required property var modelData
        required property int index

        readonly property bool isCurrent: ListView.isCurrentItem && list.selected
        readonly property bool headerVisible: list.showHeaders && !!modelData.category
            && (index === 0 || list.items[index - 1].category !== modelData.category)
        readonly property var actions: list.showActions ? (modelData.actions || []) : []

        width: ListView.view.width
        height: (headerVisible ? header.implicitHeight : 0) + content.height

        PlasmaExtras.Heading {
            id: header
            visible: row.headerVisible
            level: 5
            opacity: 0.7
            text: row.modelData.category || ""
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Kirigami.Units.largeSpacing
            topPadding: row.index === 0 ? Kirigami.Units.smallSpacing : Kirigami.Units.largeSpacing
            bottomPadding: Kirigami.Units.smallSpacing
        }

        MouseArea {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.max(layout.implicitHeight + Kirigami.Units.smallSpacing * 2,
                             Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2)
            hoverEnabled: true
            onClicked: list.itemClicked(row.index)

            // Drawn per row (not as ListView.highlight) so it does not cover the category header
            PlasmaExtras.Highlight {
                anchors.fill: parent
                visible: row.isCurrent
            }

            Rectangle {
                anchors.fill: parent
                visible: content.containsMouse && !row.isCurrent
                color: Kirigami.Theme.hoverColor
                opacity: 0.25
                radius: Kirigami.Units.cornerRadius
            }

            RowLayout {
                id: layout
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.largeSpacing
                anchors.rightMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    source: row.modelData.icon || ""
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    // Overflowing titles fade/elide at rest and scroll in an infinite,
                    // seamless loop on hover (same technique as the svec-elektro.cz nav flyout:
                    // a cloned segment placed right after the original, looped back to x:0).
                    Item {
                        id: titleClip
                        Layout.fillWidth: true
                        implicitHeight: titleLabel.implicitHeight
                        clip: true

                        readonly property int titleFormat: list.highlightMatches ? Text.StyledText : Text.PlainText
                        readonly property string titleText: list.highlightMatches
                            ? Util.highlight(row.modelData.text || "",
                                             row.modelData.highlight !== undefined ? row.modelData.highlight : list.pattern)
                            : (row.modelData.text || "")
                        readonly property bool overflowing: titleLabel.implicitWidth > titleClip.width
                        property bool hoverReady: false
                        readonly property bool marquee: hoverReady && overflowing

                        onMarqueeChanged: if (!marquee) marqueeRow.x = 0

                        Timer {
                            interval: 250
                            repeat: true
                            running: content.containsMouse && titleClip.overflowing
                            onTriggered: titleClip.hoverReady = true
                            onRunningChanged: if (!running) titleClip.hoverReady = false
                        }

                        PlasmaComponents3.Label {
                            anchors.fill: parent
                            visible: !titleClip.marquee
                            elide: Text.ElideRight
                            textFormat: titleClip.titleFormat
                            text: titleClip.titleText
                        }

                        Row {
                            id: marqueeRow
                            visible: titleClip.marquee
                            spacing: Kirigami.Units.largeSpacing * 1.5

                            PlasmaComponents3.Label {
                                id: titleLabel
                                textFormat: titleClip.titleFormat
                                text: titleClip.titleText
                                wrapMode: Text.NoWrap
                            }
                            PlasmaComponents3.Label {
                                textFormat: titleClip.titleFormat
                                text: titleClip.titleText
                                wrapMode: Text.NoWrap
                            }

                            NumberAnimation on x {
                                running: titleClip.marquee
                                loops: Animation.Infinite
                                from: 0
                                to: -(titleLabel.implicitWidth + marqueeRow.spacing)
                                duration: Math.max(3200, Math.min(18000,
                                    (titleLabel.implicitWidth + marqueeRow.spacing) * 1000 / 16))
                            }
                        }
                    }
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        elide: Text.ElideMiddle
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        text: row.modelData.subtext || ""
                    }
                }

                Repeater {
                    model: row.actions
                    PlasmaComponents3.ToolButton {
                        required property var modelData
                        required property int index
                        visible: row.isCurrent || content.containsMouse
                        icon.name: modelData.icon || ""
                        display: PlasmaComponents3.AbstractButton.IconOnly
                        text: modelData.text || ""
                        PlasmaComponents3.ToolTip.text: text + (index === 0 ? "  (Shift+Enter)" : index === 1 ? "  (Alt+Enter)" : "")
                        PlasmaComponents3.ToolTip.visible: hovered
                        PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                        onClicked: list.actionClicked(row.index, index)
                    }
                }
            }
        }
    }
}
