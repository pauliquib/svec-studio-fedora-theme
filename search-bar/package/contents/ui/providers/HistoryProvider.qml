import QtQuick

// Recent items, shown when the field is focused and empty.
Item {
    id: root

    property var core
    property string query: ""
    property bool active: false
    property var items: []
    property bool busy: false
    property string emptyText: i18n("Zatím žádné nedávné položky")

    readonly property var fallbackIcons: ({
        query: "system-search",
        terminal: "utilities-terminal",
        file: "document-open",
        alias: "system-run",
        web: "internet-web-browser",
        system: "system-shutdown"
    })

    function parseHistory() {
        const out = []
        for (const raw of (core && core.cfg.history) || []) {
            try {
                const e = JSON.parse(raw)
                if (e && typeof e.kind === "string" && typeof e.key === "string") {
                    out.push(e)
                }
            } catch (err) {
                // skip invalid entries
            }
        }
        return out
    }

    function refresh() {
        if (!active) {
            items = []
            return
        }
        const actions = core.cfg.actionsEnabled
            ? [{ icon: "edit-delete-remove", text: i18n("Odebrat z historie") }]
            : []
        items = parseHistory().map(e => ({
            text: e.text || e.key,
            subtext: e.subtext || "",
            icon: e.icon || fallbackIcons[e.kind] || "document-open-recent",
            category: i18n("Nedávné"),
            actions: actions,
            highlight: "",
            data: e
        }))
    }

    onActiveChanged: refresh()
    Connections {
        target: root.core ? root.core.cfg : null
        function onHistoryChanged() { root.refresh() }
        function onActionsEnabledChanged() { root.refresh() }
    }

    function activate(index, modifiers) {
        const item = items[index]
        if (!item) {
            return
        }
        const e = item.data
        const cfg = core.cfg
        switch (e.kind) {
        case "query":
            core.runQuery(e.key)
            break
        case "terminal":
            core.runInTerminal(e.key, { workdir: cfg.terminalWorkdir, keepOpen: cfg.terminalKeepOpen })
            core.reset()
            break
        case "file":
        case "web":
            core.openUrl(e.key)
            core.reset()
            break
        case "alias":
            core.setQuery(e.key)
            return
        case "system":
            core.setQuery(cfg.systemPrefix + (e.text || e.key))
            return
        default:
            return
        }
        core.addHistory(e)
    }

    function runAction(index, actionIndex) {
        const item = items[index]
        if (!item || actionIndex !== 0) {
            return
        }
        const e = item.data
        core.cfg.history = (core.cfg.history || []).filter(raw => {
            try {
                const o = JSON.parse(raw)
                return !(o && o.kind === e.kind && o.key === e.key)
            } catch (err) {
                return false // drop invalid entries as well
            }
        })
    }
}
