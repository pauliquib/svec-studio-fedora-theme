import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.milou as Milou

import "../code/terminals.js" as Terminals
import "../code/util.js" as Util
import "providers"

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration

    property string query: ""
    property Item field
    property Item pane
    // True while the user works with the field; the results window follows it
    property bool active: false

    // ---- modes -------------------------------------------------------------

    readonly property var runnerModes: {
        if (!cfg.runnerModesEnabled) return []
        const list = []
        for (const line of cfg.runnerModes) {
            const parts = String(line).split("|")
            if (parts.length >= 2 && parts[0].length > 0 && parts[1].length > 0) {
                list.push({ prefix: parts[0], runner: parts[1], name: parts[2] || parts[1] })
            }
        }
        return list
    }

    // Enabled prefix modes, also exposed to HelpProvider as `core.modes`
    readonly property var modes: {
        const list = []
        const add = (enabled, prefix, kind, name, description, icon) => {
            if (enabled && prefix.length > 0) {
                list.push({ prefix: prefix, kind: kind, name: name, description: description, icon: icon })
            }
        }
        add(cfg.terminalEnabled, cfg.terminalPrefix, "terminal", i18n("Terminál"),
            i18n("Spustí příkaz v terminálu"), "utilities-terminal")
        add(cfg.filesEnabled, cfg.filesPrefix, "files", i18n("Soubory"),
            i18n("Hledá soubory podle názvu"), "folder-open")
        add(cfg.systemEnabled, cfg.systemPrefix, "system", i18n("Systém"),
            i18n("Zamknutí, uspání, restart, vypnutí…"), "system-shutdown")
        add(cfg.webEnabled, cfg.webPrefix, "web", i18n("Web"),
            i18n("Hledá na internetu"), "internet-web-browser")
        add(cfg.helpEnabled, cfg.helpPrefix, "help", i18n("Nápověda"),
            i18n("Přehled prefixů a zkratek"), "help-contents")
        for (const m of runnerModes) {
            list.push({ prefix: m.prefix, kind: "runner", runner: m.runner, name: m.name,
                        description: i18n("Hledá jen pomocí runneru „%1“", m.runner), icon: "search" })
        }
        return list
    }

    // The mode matching the query; the longest matching prefix wins
    readonly property var mode: {
        let best = null
        for (const m of modes) {
            if (query.startsWith(m.prefix) && (!best || m.prefix.length > best.prefix.length)) {
                best = m
            }
        }
        if (best) return best
        if (query.length === 0) return { kind: "history", prefix: "" }
        return { kind: "default", prefix: "" }
    }
    readonly property string modeQuery: query.slice(mode.prefix.length).trim()

    readonly property var currentProvider: {
        switch (mode.kind) {
        case "terminal": return terminalProvider
        case "files": return filesProvider
        case "system": return systemProvider
        case "web": return webProvider
        case "help": return helpProvider
        case "history": return historyProvider
        case "default": return aliasesProvider
        }
        return null
    }
    readonly property var providerItems: currentProvider && currentProvider.active ? currentProvider.items : []
    readonly property bool historyMode: mode.kind === "history" && cfg.historyEnabled && cfg.historyShowOnFocus

    // ---- providers ---------------------------------------------------------

    TerminalProvider {
        id: terminalProvider
        core: root
        active: root.active && root.mode.kind === "terminal"
        // Not trimmed at the end: a trailing space starts the next word for suggestions
        query: active ? root.query.slice(root.mode.prefix.length).replace(/^\s+/, "") : ""
    }
    FilesProvider {
        id: filesProvider
        core: root
        active: root.active && root.mode.kind === "files"
        query: active ? root.modeQuery : ""
    }
    SystemProvider {
        id: systemProvider
        core: root
        active: root.active && root.mode.kind === "system"
        query: active ? root.modeQuery : ""
    }
    WebProvider {
        id: webProvider
        core: root
        active: root.active && root.mode.kind === "web"
        query: active ? root.modeQuery : ""
    }
    HelpProvider {
        id: helpProvider
        core: root
        active: root.active && root.mode.kind === "help"
        query: active ? root.modeQuery : ""
    }
    HistoryProvider {
        id: historyProvider
        core: root
        active: root.active && root.historyMode
        query: ""
    }
    AliasesProvider {
        id: aliasesProvider
        core: root
        active: root.active && root.mode.kind === "default" && root.cfg.aliasesEnabled
        query: active ? root.query : ""
    }

    // ---- representation ----------------------------------------------------

    // The field is shown directly in the panel. The standard applet popup is not
    // used because it grabs keyboard focus, which would force a second text field
    // into it; results are shown in a non-focusable window of our own instead.
    preferredRepresentation: fullRepresentation
    fullRepresentation: barComp
    activationTogglesExpanded: false

    Component.onCompleted: Plasmoid.globalShortcut = "Ctrl+K"
    Plasmoid.onActivated: requestInput()

    // ---- core API (see docs/ARCHITECTURE.md) -------------------------------

    // Panels do not accept keyboard focus by default. Raising the applet status
    // to AcceptingInputStatus makes the panel window focusable until it is lowered again.
    function requestInput() {
        Plasmoid.status = PlasmaCore.Types.AcceptingInputStatus
        active = true
        if (field) {
            field.forceActiveFocus()
        }
    }

    function releaseInput() {
        if (Plasmoid.status === PlasmaCore.Types.AcceptingInputStatus) {
            Plasmoid.status = PlasmaCore.Types.ActiveStatus
        }
    }

    function reset() {
        query = ""
        active = false
        if (field) field.focus = false
        releaseInput()
    }

    function setQuery(text) {
        query = text
        active = true
        if (field) field.cursorPosition = text.length
    }

    // Sets the query and runs the first KRunner result as soon as it arrives
    function runQuery(text) {
        setQuery(text)
        if (pane) {
            pane.queueRun()
        }
    }

    property int execSeq: 0
    property var execCallbacks: ({})

    function exec(cmd, callback) {
        // A unique trailing comment keeps identical commands from sharing one source
        const source = cmd + "\n# searchbar " + (++execSeq)
        if (callback) {
            execCallbacks[source] = callback
        }
        executable.connectSource(source)
    }

    function runInTerminal(command, options) {
        options = options || {}
        if (options.background && command.length > 0) {
            exec(Terminals.buildBackground(command, options), (stdout, stderr, code) => {
                const output = (stdout + stderr).trim()
                notify(code === 0 ? command : i18n("%1 (chyba %2)", command, code),
                       output.length > 0 ? output : i18n("Příkaz skončil bez výstupu."),
                       code === 0 ? "utilities-terminal" : "dialog-error")
            })
            return
        }
        const cmd = Terminals.buildCommand(cfg.terminalApp, cfg.terminalCustom, command, {
            keepOpen: options.keepOpen !== undefined ? options.keepOpen : cfg.terminalKeepOpen,
            workdir: options.workdir !== undefined ? options.workdir : cfg.terminalWorkdir,
            sudo: !!options.sudo
        })
        if (cmd) {
            exec(cmd)
        }
    }

    function openUrl(url) {
        url = String(url)
        if (url.startsWith("~")) {
            exec("xdg-open " + Util.expandHome(url))
            return
        }
        if (url.startsWith("/")) {
            url = "file://" + encodeURI(url)
        }
        Qt.openUrlExternally(url)
    }

    function copyToClipboard(text) {
        clipboardHelper.text = text
        clipboardHelper.selectAll()
        clipboardHelper.copy()
        // The panel may lose focus before the copy is served on Wayland, so also use wl-copy/xclip
        exec("printf '%s' " + Terminals.shellQuote(text)
             + " | (wl-copy 2>/dev/null || xclip -selection clipboard 2>/dev/null || xsel -bi 2>/dev/null)")
    }

    function notify(title, text, icon) {
        exec("notify-send -a " + Terminals.shellQuote(i18n("Vyhledávací pole"))
             + " -i " + Terminals.shellQuote(icon || "system-search")
             + " -- " + Terminals.shellQuote(title) + " " + Terminals.shellQuote(text || ""))
    }

    function addHistory(entry) {
        if (!cfg.historyEnabled || !entry || !entry.key) {
            return
        }
        const list = [JSON.stringify(entry)]
        for (const line of cfg.history) {
            try {
                const e = JSON.parse(line)
                if (e.kind === entry.kind && e.key === entry.key) continue
            } catch (e) {
                continue
            }
            list.push(line)
        }
        cfg.history = list.slice(0, Math.max(1, cfg.historyMax))
    }

    function runQueryInTerminal() {
        if (!cfg.terminalEnabled) return
        const command = mode.kind === "terminal" ? modeQuery : query.trim()
        if (command.length > 0) {
            addHistory({ kind: "terminal", key: command, text: command, icon: "utilities-terminal" })
        }
        runInTerminal(command, {})
        reset()
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        onNewData: (sourceName, data) => {
            const callback = root.execCallbacks[sourceName]
            delete root.execCallbacks[sourceName]
            disconnectSource(sourceName)
            if (callback) {
                callback(data.stdout || "", data.stderr || "", data["exit code"])
            }
        }
    }

    TextEdit {
        id: clipboardHelper
        visible: false
    }

    // ---- UI ------------------------------------------------------------------

    Component {
        id: barComp

        Item {
            id: bar
            Layout.minimumWidth: Kirigami.Units.gridUnit * 26
            Layout.preferredWidth: Kirigami.Units.gridUnit * 30
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
            Layout.fillHeight: true
            implicitWidth: Layout.preferredWidth
            implicitHeight: Kirigami.Units.gridUnit * 2

            PlasmaComponents3.TextField {
                id: field
                anchors.fill: parent
                anchors.margins: root.cfg.spacing
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
                    source: {
                        const m = root.mode
                        return m.icon ? m.icon : "system-search"
                    }
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

                onPressed: root.requestInput()
                onActiveFocusChanged: if (activeFocus) hidePanelFocusIndicator()
                onTextEdited: {
                    root.query = text
                    root.active = true
                }

                Keys.onReturnPressed: event => popup.handleReturn(event)
                Keys.onEnterPressed: event => popup.handleReturn(event)
                Keys.onEscapePressed: root.reset()
                Keys.onDownPressed: popup.moveSelection(1)
                Keys.onUpPressed: popup.moveSelection(-1)
                Keys.onTabPressed: event => {
                    const item = popup.currentProviderItem()
                    if (item && item.completion) {
                        root.setQuery(item.completion)
                    }
                    event.accepted = true
                }

                // Clicking into the results window may briefly deactivate the panel,
                // so closing is delayed to let that click finish.
                Timer {
                    id: deactivateTimer
                    interval: 250
                    onTriggered: if (!field.Window.active) root.reset()
                }

                Connections {
                    target: field.Window.window
                    function onActiveChanged() {
                        if (!field.Window.active) {
                            deactivateTimer.restart()
                        }
                    }
                }

                // The panel draws a "focus indicator" tab under the focused applet;
                // the field's own focus border is enough, so hide it while we have focus.
                function hidePanelFocusIndicator() {
                    const top = Window.contentItem
                    if (!top) return
                    const stack = [top]
                    let depth = 0
                    while (stack.length && depth++ < 200) {
                        const item = stack.shift()
                        if (item.imagePath === "widgets/tabbar" && item !== field) {
                            item.opacity = Qt.binding(() => field.activeFocus ? 0 : 1)
                            return
                        }
                        for (const child of item.children) stack.push(child)
                    }
                }

                Component.onCompleted: root.field = field
                Component.onDestruction: root.field = null
            }

            PlasmaCore.Dialog {
                id: popup
                type: PlasmaCore.Dialog.Tooltip
                flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
                location: PlasmaCore.Types.Floating
                hideOnWindowDeactivate: false

                readonly property bool busy: !!(root.currentProvider && root.currentProvider.active && root.currentProvider.busy)
                readonly property string emptyText: root.currentProvider && root.currentProvider.active
                    ? (root.currentProvider.emptyText || "") : ""

                visible: root.active
                    && (root.query.length > 0 || (root.historyMode && content.providerCount > 0))
                    && (content.hasResults || busy || emptyText.length > 0)

                // Positioned manually right under (or above) the field; the automatic
                // placement relative to a visualParent is unreliable for tooltip windows.
                function reposition() {
                    if (!visible) return
                    const p = field.mapToGlobal(0, 0)
                    const gap = Kirigami.Units.smallSpacing
                    x = Math.round(p.x + (field.width - width) / 2)
                    y = Plasmoid.location === PlasmaCore.Types.BottomEdge
                        ? Math.round(p.y - height - gap)
                        : Math.round(p.y + field.height + gap)
                }
                onVisibleChanged: reposition()
                onWidthChanged: reposition()
                onHeightChanged: reposition()

                function moveSelection(delta) { content.moveSelection(delta) }
                function handleReturn(event) { content.handleReturn(event) }
                function currentProviderItem() { return content.currentProviderItem() }

                mainItem: ResultsPane {
                    id: content
                    core: root
                    width: field.width
                }
            }
        }
    }
}
