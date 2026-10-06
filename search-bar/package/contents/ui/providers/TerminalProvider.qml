import QtQuick

import "../../code/util.js" as Util
import "../../code/terminals.js" as Terminals

// Terminal mode: runs the typed command in the configured terminal (or in the
// background), offers "run as root", completion suggestions (commands from $PATH,
// files for path arguments) and a searchable command history.
Item {
    id: provider

    property var core
    property string query: ""
    property bool active: false
    property bool busy: false
    property string emptyText: ""

    readonly property int maxHistoryItems: 8
    readonly property var items: active && core ? buildItems(query) : []

    // ---- suggestions ----

    // Executable names available in $PATH, loaded once on first use
    property var commandNames: []
    property bool commandsRequested: false
    // File completions for `pathWord`, filled asynchronously
    property string pathWord: ""
    property var pathMatches: []

    // Splits the command into the part before the word being typed and that word
    function currentWord(cmd) {
        const sep = Math.max(cmd.lastIndexOf(" "), cmd.lastIndexOf("\t"))
        return { head: cmd.slice(0, sep + 1), word: cmd.slice(sep + 1), first: sep < 0 }
    }

    function isPathWord(word) {
        return /^(~|\.{1,2}\/|\/)/.test(word) || word.indexOf("/") >= 0
    }

    onQueryChanged: if (active) requestSuggestions()
    onActiveChanged: if (active) requestSuggestions()

    function requestSuggestions() {
        const cfg = core.cfg
        const w = currentWord(query)
        if (cfg.terminalSuggestCommands && w.first && w.word.length > 0 && !commandsRequested) {
            commandsRequested = true
            core.exec("bash -lc 'compgen -c' 2>/dev/null | sort -u", stdout => {
                commandNames = stdout.split("\n").filter(c => c.length > 0 && !/^[^a-zA-Z0-9_]/.test(c))
            })
        }
        if (cfg.terminalSuggestPaths && !w.first && isPathWord(w.word)) {
            pathTimer.restart()
        }
    }

    Timer {
        id: pathTimer
        interval: 120
        onTriggered: {
            const word = provider.currentWord(provider.query).word
            // compgen keeps "~" in its output; test directories with it expanded
            provider.core.exec(Terminals.cdPrefix(provider.core.cfg.terminalWorkdir)
                + " && bash -c 'compgen -f -- \"$1\" | head -n 60 | while IFS= read -r f; do "
                + "t=\"${f/#\\~/$HOME}\"; [ -d \"$t\" ] && echo \"$f/\" || echo \"$f\"; done' _ "
                + Util.shellQuote(word), stdout => {
                    if (provider.currentWord(provider.query).word !== word) return
                    provider.pathWord = word
                    provider.pathMatches = stdout.split("\n").filter(f => f.length > 0)
                })
        }
    }

    function suggestions(cmd) {
        const cfg = core.cfg
        const w = currentWord(cmd)
        const max = Math.max(1, cfg.terminalSuggestMax)
        let names = []
        let isPath = false
        if (cfg.terminalSuggestCommands && w.first && w.word.length > 0) {
            const lower = w.word.toLowerCase()
            names = commandNames.filter(c => c.toLowerCase().startsWith(lower) && c !== w.word)
            names.sort((a, b) => a.length - b.length || a.localeCompare(b))
        } else if (cfg.terminalSuggestPaths && !w.first && isPathWord(w.word) && pathWord === w.word) {
            names = pathMatches.filter(f => f !== w.word)
            isPath = true
        }
        return names.slice(0, max).map(name => {
            const isDir = name.endsWith("/")
            const full = w.head + name
            return {
                text: full,
                subtext: isPath ? (isDir ? i18n("Složka") : i18n("Soubor")) : i18n("Příkaz"),
                icon: isPath ? (isDir ? "folder" : "text-x-generic") : "application-x-executable",
                category: i18n("Návrhy"),
                highlight: w.word,
                completion: cfg.terminalPrefix + " " + full + (isDir ? "" : " "),
                data: { command: full, background: false, runs: [], suggestion: true }
            }
        })
    }

    function historyList() {
        return Array.prototype.slice.call(core.cfg.terminalHistory || [])
    }

    // Run variants of a non-empty command: primary first, then the actions.
    function runVariants() {
        const cfg = core.cfg
        const bgPrimary = cfg.terminalBackgroundEnabled && cfg.terminalBackgroundDefault
        const variants = [{ sudo: false, background: bgPrimary }]
        if (cfg.terminalBackgroundEnabled) {
            variants.push(bgPrimary
                ? { sudo: false, background: false, icon: "utilities-terminal", text: i18n("Spustit v okně terminálu") }
                : { sudo: false, background: true, icon: "system-run", text: i18n("Spustit na pozadí") })
        }
        if (cfg.terminalSudoEnabled) {
            variants.push({ sudo: true, background: false, icon: "dialog-password", text: i18n("Spustit jako root") })
        }
        return variants
    }

    function buildItems(raw) {
        const cmd = raw.trim()
        const cfg = core.cfg
        const terminalName = Terminals.label(cfg.terminalApp, cfg.terminalCustom)
        const variants = runVariants()
        const runs = variants.slice(1)
        const actions = runs.map(v => ({ icon: v.icon, text: v.text }))

        const workdir = cfg.terminalWorkdir.trim() || "~"
        const subtext = cfg.terminalKeepOpen
            ? i18n("Složka: %1 · terminál zůstane otevřený", workdir)
            : i18n("Složka: %1 · terminál se po dokončení zavře", workdir)

        const result = []
        if (cmd.length === 0) {
            result.push({
                text: i18n("Otevřít %1", terminalName),
                subtext: i18n("Složka: %1", workdir),
                icon: "utilities-terminal",
                category: i18n("Terminál"),
                data: { command: "", runs: [] }
            })
        } else {
            result.push({
                text: variants[0].background ? i18n("Spustit na pozadí: %1", cmd)
                                             : i18n("Spustit v %1: %2", terminalName, cmd),
                subtext: variants[0].background ? i18n("Složka: %1 · výstup se zobrazí v oznámení", workdir) : subtext,
                icon: "utilities-terminal",
                category: i18n("Terminál"),
                highlight: cmd,
                actions: actions,
                data: { command: cmd, background: variants[0].background, runs: runs }
            })
        }

        for (const suggestion of suggestions(raw)) {
            suggestion.data.background = variants[0].background
            result.push(suggestion)
        }

        if (!cfg.terminalHistoryEnabled) {
            return result
        }

        let matches = historyList()
            .filter(c => c !== cmd)
            .map((c, i) => ({ command: c, score: Util.fuzzyScore(cmd, c), order: i }))
            .filter(m => m.score >= 0)
        if (cmd.length > 0) {
            matches.sort((a, b) => b.score - a.score || a.order - b.order)
        }
        matches = matches.slice(0, maxHistoryItems)

        const historyActions = actions.concat([{ icon: "edit-delete-remove", text: i18n("Odebrat z historie") }])
        for (const m of matches) {
            result.push({
                text: m.command,
                icon: "utilities-terminal",
                category: i18n("Historie příkazů"),
                highlight: cmd,
                completion: cfg.terminalPrefix + " " + m.command,
                actions: historyActions,
                data: { command: m.command, background: variants[0].background, runs: runs, history: true }
            })
        }
        return result
    }

    function remember(cmd) {
        if (cmd.length === 0) {
            return
        }
        const cfg = core.cfg
        if (cfg.terminalHistoryEnabled) {
            const list = historyList().filter(c => c !== cmd)
            list.unshift(cmd)
            cfg.terminalHistory = list.slice(0, Math.max(1, cfg.terminalHistoryMax))
        }
        core.addHistory({ kind: "terminal", key: cmd, text: cmd, icon: "utilities-terminal" })
    }

    function run(cmd, sudo, background) {
        const cfg = core.cfg
        remember(cmd)
        core.runInTerminal(cmd, {
            workdir: cfg.terminalWorkdir,
            keepOpen: cfg.terminalKeepOpen,
            sudo: sudo,
            background: background && cmd.length > 0
        })
        core.reset()
    }

    function activate(index, modifiers) {
        const item = items[index]
        if (item) {
            run(item.data.command, false, item.data.background)
        }
    }

    function runAction(index, actionIndex) {
        const item = items[index]
        if (!item || !item.actions || actionIndex < 0 || actionIndex >= item.actions.length) {
            return
        }
        const data = item.data
        if (actionIndex < data.runs.length) {
            const v = data.runs[actionIndex]
            run(data.command, v.sudo, v.background)
        } else if (data.history) {
            core.cfg.terminalHistory = historyList().filter(c => c !== data.command)
        }
    }
}
