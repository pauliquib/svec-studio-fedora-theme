import QtQuick

import "../../code/util.js" as Util

// Help ("?" mode): lists the enabled mode prefixes and the keyboard shortcuts.
Item {
    id: provider

    property var core
    property string query: ""
    property bool active: false
    property var items: []
    property bool busy: false
    property string emptyText: i18n("Nic neodpovídá")

    readonly property var shortcuts: [
        { key: "Enter", text: i18n("Spustit vybranou položku") },
        { key: "Shift+Enter", text: i18n("První akce položky") },
        { key: "Alt+Enter", text: i18n("Druhá akce položky") },
        { key: "Ctrl+Enter", text: i18n("Spustit celý text v terminálu") },
        { key: "Tab", text: i18n("Doplnit vybranou položku do pole") },
        { key: "↑ ↓", text: i18n("Pohyb ve výsledcích") },
        { key: "Esc", text: i18n("Vymazat a zavřít") },
        { key: "Ctrl+K", text: i18n("Přejít do vyhledávacího pole (globální zkratka)") }
    ]

    function update() {
        if (!active) {
            items = []
            return
        }
        const q = query.trim()
        const matches = (s) => q.length === 0 || Util.fuzzyScore(q, s) >= 0
        const result = []
        ;(core.modes || []).forEach(m => {
            const text = m.prefix + "  " + m.name
            if (matches(text + " " + (m.description || ""))) {
                result.push({
                    text: text,
                    subtext: m.description || "",
                    icon: m.icon || "help-hint",
                    category: i18n("Prefixy"),
                    completion: m.prefix,
                    data: { prefix: m.prefix }
                })
            }
        })
        shortcuts.forEach(s => {
            if (matches(s.key + " " + s.text)) {
                result.push({
                    text: s.key,
                    subtext: s.text,
                    icon: "input-keyboard",
                    category: i18n("Klávesové zkratky"),
                    data: {}
                })
            }
        })
        items = result
    }

    onQueryChanged: update()
    onActiveChanged: update()

    Connections {
        target: provider.core
        ignoreUnknownSignals: true
        function onModesChanged() { provider.update() }
    }

    function activate(index, modifiers) {
        const item = items[index]
        if (item && item.data.prefix !== undefined) {
            core.setQuery(item.data.prefix)
        }
    }

    function runAction(index, actionIndex) {
    }
}
