import QtQuick

// Web search ("!" mode): one item per engine, "g rust" / "wiki praha" picks one engine.
Item {
    id: provider

    property var core
    property string query: ""
    property bool active: false
    property var items: []
    property bool busy: false
    property string emptyText: query.length === 0 ? i18n("Napište hledaný výraz…") : ""

    readonly property var engines: (core ? core.cfg.webEngines : []).map(line => {
        const sep = String(line).indexOf("|")
        return sep > 0 ? { name: line.slice(0, sep).trim(), url: line.slice(sep + 1).trim() } : null
    }).filter(e => e && e.name && e.url)

    // Returns the engine selected by the first word (full name or its first letter, e.g. "g"), or null.
    function engineFor(word) {
        word = word.toLowerCase()
        return engines.find(e => e.name.toLowerCase() === word)
            || (word.length === 1 ? engines.find(e => e.name.toLowerCase().startsWith(word)) : undefined)
            || null
    }

    function looksLikeUrl(q) {
        return /^[a-z][a-z0-9+.-]*:\/\/\S+$/i.test(q)
            || /^(localhost|[\w-]+(\.[\w-]+)*\.[a-z]{2,})(:\d+)?([\/?#]\S*)?$/i.test(q)
    }

    function searchItem(engine, q) {
        const url = engine.url.indexOf("%s") >= 0
            ? engine.url.split("%s").join(encodeURIComponent(q))
            : engine.url + encodeURIComponent(q)
        return {
            text: i18n("Hledat „%1“ na %2", q, engine.name),
            subtext: url,
            icon: "internet-web-browser",
            category: i18n("Web"),
            highlight: q,
            actions: core.cfg.actionsEnabled ? [{ icon: "edit-copy", text: i18n("Kopírovat odkaz") }] : [],
            data: { url: url }
        }
    }

    function update() {
        const q = query.trim()
        if (!active || q.length === 0) {
            items = []
            return
        }
        const result = []
        if (looksLikeUrl(q)) {
            const url = /^[a-z][a-z0-9+.-]*:\/\//i.test(q) ? q : "https://" + q
            result.push({
                text: i18n("Otevřít %1", q),
                subtext: url,
                icon: "globe",
                category: i18n("Web"),
                highlight: q,
                actions: core.cfg.actionsEnabled ? [{ icon: "edit-copy", text: i18n("Kopírovat odkaz") }] : [],
                data: { url: url }
            })
        }
        const space = q.indexOf(" ")
        const engine = space > 0 ? engineFor(q.slice(0, space)) : null
        const rest = space > 0 ? q.slice(space + 1).trim() : ""
        if (engine && rest.length > 0) {
            result.push(searchItem(engine, rest))
        } else {
            engines.forEach(e => result.push(searchItem(e, q)))
        }
        items = result
    }

    onQueryChanged: update()
    onActiveChanged: update()
    onEnginesChanged: update()

    function activate(index, modifiers) {
        const item = items[index]
        if (!item) {
            return
        }
        core.openUrl(item.data.url)
        core.addHistory({ kind: "web", key: item.data.url, text: item.text, icon: item.icon })
        core.reset()
    }

    function runAction(index, actionIndex) {
        const item = items[index]
        if (item && actionIndex === 0) {
            core.copyToClipboard(item.data.url)
            core.reset()
        }
    }
}
