import QtQuick

import "../../code/util.js" as Util

// User-defined aliases / custom commands, shown on top of KRunner results.
Item {
    id: root

    property var core
    property string query: ""          // full query
    property bool active: false
    property var items: []
    property bool busy: false
    property string emptyText: ""

    readonly property int maxSuggestions: 5

    function modeIcon(mode) {
        switch (mode) {
        case "background": return "system-run"
        case "silent": return "system-run"
        case "open": return "internet-web-browser"
        default: return "utilities-terminal"
        }
    }

    function modeText(mode) {
        switch (mode) {
        case "background": return i18n("Na pozadí s notifikací")
        case "silent": return i18n("Tiše")
        case "open": return i18n("Otevřít URL/soubor")
        default: return i18n("V terminálu")
        }
    }

    function parseAliases() {
        const out = []
        for (const raw of (core && core.cfg.aliases) || []) {
            try {
                const a = JSON.parse(raw)
                if (a && a.name && a.command) {
                    out.push({ name: String(a.name).trim(), command: String(a.command),
                               mode: a.mode || "terminal", workdir: a.workdir || "" })
                }
            } catch (err) {
                // skip invalid entries
            }
        }
        return out
    }

    // `%s` in the command is replaced by the arguments, otherwise they are appended.
    function expand(command, args) {
        if (command.indexOf("%s") >= 0) {
            return command.split("%s").join(args)
        }
        return args ? command + " " + args : command
    }

    function makeItem(a, args, exact) {
        // URL templates get URL-encoded arguments
        const urlArgs = a.mode === "open" && /^[a-z][a-z0-9+.-]*:/i.test(a.command)
        const cmd = expand(a.command, urlArgs ? encodeURIComponent(args) : args)
        const actions = core.cfg.actionsEnabled && a.mode !== "terminal"
            ? [{ icon: "utilities-terminal", text: i18n("Spustit v terminálu") }]
            : []
        return {
            text: i18n("%1 → %2", a.name, cmd),
            subtext: a.workdir ? i18n("%1 · %2", modeText(a.mode), a.workdir) : modeText(a.mode),
            icon: modeIcon(a.mode),
            category: i18n("Aliasy"),
            actions: actions,
            highlight: a.name,
            completion: a.name + " ",
            preselect: exact,
            data: { alias: a, command: cmd, exact: exact }
        }
    }

    function refresh() {
        const q = query.trim()
        if (!active || !core || !core.cfg.aliasesEnabled || q === "") {
            items = []
            return
        }
        const m = q.match(/^(\S+)\s*(.*)$/)
        const word = m[1].toLowerCase()
        const args = m[2]
        const aliases = parseAliases()
        const result = []
        const exact = aliases.find(a => a.name.toLowerCase() === word)
        if (exact) {
            result.push(makeItem(exact, args, true))
        }
        // Suggestions only while the first word is still being typed.
        if (args === "") {
            aliases.filter(a => a !== exact)
                .map(a => ({ a: a, score: Util.fuzzyScore(word, a.name) }))
                .filter(s => s.score >= 0)
                .sort((x, y) => y.score - x.score)
                .slice(0, maxSuggestions)
                .forEach(s => result.push(makeItem(s.a, "", false)))
        }
        items = result
    }

    onQueryChanged: refresh()
    onActiveChanged: refresh()
    Connections {
        target: root.core ? root.core.cfg : null
        function onAliasesChanged() { root.refresh() }
        function onAliasesEnabledChanged() { root.refresh() }
        function onActionsEnabledChanged() { root.refresh() }
    }

    function run(item, mode) {
        const a = item.data.alias
        const cmd = item.data.command
        const cfg = core.cfg
        switch (mode) {
        case "background":
            core.runInTerminal(cmd, { workdir: a.workdir, background: true })
            break
        case "silent":
            // detached, output discarded
            core.exec("(cd " + Util.expandHome(a.workdir) + " && " + cmd + ") >/dev/null 2>&1 &")
            break
        case "open":
            core.openUrl(cmd)
            break
        default:
            core.runInTerminal(cmd, { workdir: a.workdir, keepOpen: cfg.terminalKeepOpen })
        }
        // Record what was run: for a suggestion that is just the alias name.
        const key = item.data.exact ? query.trim() : a.name
        core.addHistory({ kind: "alias", key: key, text: item.text, icon: item.icon })
        core.reset()
    }

    function activate(index, modifiers) {
        const item = items[index]
        if (item) {
            run(item, item.data.alias.mode)
        }
    }

    function runAction(index, actionIndex) {
        const item = items[index]
        if (item && actionIndex === 0 && item.actions.length > 0) {
            run(item, "terminal")
        }
    }
}
