import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.milou as Milou

// Content of the results window: provider items on top, then KRunner results
// (one view for a runner prefix mode, or one view per runner when the runner
// filter is on). Keyboard selection spans all of them.
Item {
    id: pane

    property var core

    readonly property int providerCount: providerList.count
    readonly property int milouCount: {
        let n = singleView.shown ? singleView.count : 0
        for (let i = 0; i < mainRepeater.count; ++i) {
            const v = mainRepeater.itemAt(i)
            if (v && v.shown) n += v.count
        }
        return n
    }
    readonly property Item mainResults: mainRepeater.count > 0 ? mainRepeater.itemAt(0) : null
    readonly property bool hasResults: providerCount > 0 || milouCount > 0

    // null = automatic selection (first suitable view)
    property Item selectedView: null
    readonly property Item currentView: (selectedView && selectedView.shown && selectedView.count > 0)
        ? selectedView : autoView()

    implicitHeight: Math.min((hasResults ? flick.contentHeight : 0)
                                 + (statusLabel.shown ? statusLabel.implicitHeight + Kirigami.Units.largeSpacing * 2 : 0)
                                 + (footer.shown ? footer.implicitHeight + Kirigami.Units.smallSpacing : 0),
                             Kirigami.Units.gridUnit * Math.max(6, core.cfg.popupMaxHeight))
    height: implicitHeight

    function autoView() {
        const kind = core.mode.kind
        if (kind === "runner") {
            return singleView.count > 0 ? singleView : null
        }
        if (kind === "default") {
            if (providerList.count > 0 && core.providerItems[0].preselect) {
                return providerList
            }
            for (let i = 0; i < mainRepeater.count; ++i) {
                const v = mainRepeater.itemAt(i)
                if (v && v.shown && v.count > 0) return v
            }
        }
        return providerList.count > 0 ? providerList : null
    }

    function orderedViews() {
        const views = [providerList, singleView]
        for (let i = 0; i < mainRepeater.count; ++i) {
            views.push(mainRepeater.itemAt(i))
        }
        return views.filter(v => v && v.shown && v.count > 0)
    }

    // Only the selected KRunner view may show its highlight
    function syncSelection() {
        for (const v of [singleView].concat(Array.from({ length: mainRepeater.count }, (_, i) => mainRepeater.itemAt(i)))) {
            if (!v) continue
            if (v !== currentView && v.currentIndex !== -1) {
                v.currentIndex = -1
            } else if (v === currentView && v.currentIndex < 0 && v.count > 0) {
                v.currentIndex = 0
            }
        }
    }
    onCurrentViewChanged: syncSelection()

    function moveSelection(delta) {
        const views = orderedViews()
        if (views.length === 0) return
        let i = views.indexOf(currentView)
        if (i < 0) {
            selectedView = views[0]
            views[0].currentIndex = 0
        } else {
            const v = views[i]
            const next = v.currentIndex + delta
            if (next >= 0 && next < v.count) {
                v.currentIndex = next
            } else {
                const nv = views[(i + delta + views.length) % views.length]
                selectedView = nv
                nv.currentIndex = delta > 0 ? 0 : nv.count - 1
            }
        }
        syncSelection()
        ensureVisible()
    }

    function ensureVisible() {
        const v = currentView
        if (!v || !v.currentItem) return
        const top = v.y + v.currentItem.y
        const bottom = top + v.currentItem.height
        if (top < flick.contentY) {
            flick.contentY = top
        } else if (bottom > flick.contentY + flick.height) {
            flick.contentY = bottom - flick.height
        }
    }

    function currentProviderItem() {
        return currentView === providerList ? core.providerItems[providerList.currentIndex] : null
    }

    // Runs the first KRunner result as soon as it is available
    function queueRun() {
        if (core.mode.kind === "runner") {
            singleView.runCurrentIndex(null)
        } else if (core.mode.kind === "default" && mainResults) {
            mainResults.runCurrentIndex(null)
        }
    }

    function handleReturn(event) {
        const mods = event.modifiers
        event.accepted = true
        if (mods & Qt.ControlModifier) {
            core.runQueryInTerminal()
            return
        }
        const v = currentView
        if (v === providerList) {
            const index = providerList.currentIndex
            const item = core.providerItems[index]
            const provider = core.currentProvider
            if (!item || !provider) return
            const actions = core.cfg.actionsEnabled ? (item.actions || []) : []
            if ((mods & Qt.ShiftModifier) && actions.length > 0) {
                provider.runAction(index, 0)
            } else if ((mods & Qt.AltModifier) && actions.length > 1) {
                provider.runAction(index, 1)
            } else {
                provider.activate(index, mods)
            }
        } else if (v) {
            if ((mods & Qt.AltModifier) && v.currentItem && v.currentItem.actions && v.currentItem.actions.length > 1) {
                v.runAction(1)
            } else {
                v.runCurrentIndex(event)
            }
        } else {
            queueRun()
        }
    }

    function recordMilou(view) {
        const item = view.currentItem
        let icon = ""
        try {
            if (typeof item.model.decoration === "string") icon = item.model.decoration
        } catch (e) {}
        core.addHistory({
            kind: "query",
            key: core.query,
            text: item && item.displayText ? item.displayText : core.query,
            subtext: core.query,
            icon: icon
        })
    }

    Connections {
        target: pane.core
        function onQueryChanged() {
            pane.selectedView = null
            flick.contentY = 0
        }
    }

    Component.onCompleted: core.pane = pane

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: column.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: pane.hasResults

            PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar {}

            Column {
                id: column
                width: flick.width

                ResultsList {
                    id: providerList
                    width: parent.width
                    readonly property bool shown: count > 0
                    height: shown ? contentHeight : 0
                    visible: shown
                    items: pane.core.providerItems
                    pattern: pane.core.modeQuery
                    selected: pane.currentView === providerList
                    showHeaders: pane.core.cfg.showCategoryHeaders
                    highlightMatches: pane.core.cfg.highlightMatches
                    showActions: pane.core.cfg.actionsEnabled
                    onItemsChanged: currentIndex = items.length > 0 ? 0 : -1
                    onItemClicked: index => {
                        currentIndex = index
                        pane.core.currentProvider.activate(index, 0)
                    }
                    onActionClicked: (index, actionIndex) => pane.core.currentProvider.runAction(index, actionIndex)
                }

                Milou.ResultsView {
                    id: singleView
                    width: parent.width
                    height: shown ? contentHeight : 0
                    interactive: false
                    readonly property bool modeActive: pane.core.mode.kind === "runner"
                    // Own flag instead of `visible`, which also depends on the (hidden) window
                    readonly property bool shown: modeActive && count > 0
                    visible: shown
                    singleRunner: modeActive ? pane.core.mode.runner : ""
                    // The windows runner lists all windows only for its "window" keyword
                    queryString: !modeActive ? ""
                        : (pane.core.modeQuery.length === 0 && pane.core.mode.runner === "windows") ? "window"
                        : pane.core.modeQuery
                    onActivated: {
                        pane.recordMilou(singleView)
                        pane.core.reset()
                    }
                    onUpdateQueryString: (text, pos) => pane.core.setQuery(pane.core.mode.prefix + text)
                    onCountChanged: pane.syncSelection()
                }

                Repeater {
                    id: mainRepeater
                    // One view for all runners, or one per selected runner in the configured order
                    model: pane.core.cfg.runnerFilterEnabled && pane.core.cfg.runnerFilter.length > 0
                        ? pane.core.cfg.runnerFilter : [""]

                    Milou.ResultsView {
                        id: mainView
                        required property string modelData
                        width: column.width
                        height: shown ? contentHeight : 0
                        interactive: false
                        readonly property bool modeActive: pane.core.mode.kind === "default"
                        readonly property bool shown: modeActive && count > 0
                        visible: shown
                        singleRunner: modelData
                        queryString: modeActive ? pane.core.query : ""
                        onActivated: {
                            pane.recordMilou(mainView)
                            pane.core.reset()
                        }
                        onUpdateQueryString: (text, pos) => pane.core.setQuery(text)
                        onCountChanged: pane.syncSelection()
                    }
                }
            }
        }

        PlasmaComponents3.Label {
            id: statusLabel
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            readonly property bool shown: !pane.hasResults && text.length > 0
            visible: shown
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: {
                const p = pane.core.currentProvider
                if (!p || !p.active) return ""
                return p.busy ? i18n("Hledám…") : (p.emptyText || "")
            }
        }

        // Keyboard hints relevant to the current selection
        Flow {
            id: footer
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.largeSpacing
            readonly property bool shown: pane.core.cfg.showFooterHints && pane.hasResults
            visible: shown

            readonly property var hints: {
                const item = pane.currentProviderItem()
                const list = [["↵", i18n("spustit")]]
                if (pane.core.cfg.actionsEnabled && ((item && item.actions && item.actions.length > 0)
                        || (pane.currentView && pane.currentView !== providerList))) {
                    list.push(["⇧↵", i18n("akce")])
                }
                if (pane.core.cfg.terminalEnabled) list.push(["Ctrl+↵", i18n("v terminálu")])
                if (item && item.completion) list.push(["Tab", i18n("doplnit")])
                list.push(["↑↓", i18n("výběr")])
                list.push(["Esc", i18n("zavřít")])
                return list
            }

            Repeater {
                model: footer.hints
                RowLayout {
                    required property var modelData
                    spacing: Kirigami.Units.smallSpacing
                    Rectangle {
                        implicitWidth: keyLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
                        implicitHeight: keyLabel.implicitHeight
                        radius: Kirigami.Units.smallSpacing * 0.75
                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
                        PlasmaComponents3.Label {
                            id: keyLabel
                            anchors.centerIn: parent
                            text: modelData[0]
                            font: Kirigami.Theme.smallFont
                        }
                    }
                    PlasmaComponents3.Label {
                        text: modelData[1]
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                }
            }
        }
    }
}
