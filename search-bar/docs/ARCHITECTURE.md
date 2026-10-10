# Architecture

The widget is a single text field shown directly in the panel
(`preferredRepresentation: fullRepresentation`). Results are shown in a
non-focusable `PlasmaCore.Dialog` (type `Tooltip`) positioned under the field,
so keyboard input always stays in the panel field.

```
package/contents/
  config/main.xml            all configuration keys (single source of truth)
  config/config.qml          configuration pages
  code/terminals.js          terminal emulator table + command builder
  code/util.js               shared helpers (shell quoting, fuzzy match, highlighting)
  ui/main.qml                core: field, popup, mode dispatch, key handling, history API
  ui/ResultsPane.qml         content of the results window: provider list + KRunner views, selection, footer hints
  ui/ResultsList.qml         shared list view for provider items (headers, highlight, actions)
  ui/InstalledRunners.qml    lists installed KRunner plugins (used by the config pages)
  ui/providers/*.qml         one provider per feature (see below)
  ui/config*.qml             one configuration page per feature
```

## Modes

The core looks at the query and picks a *mode*:

| Mode            | Default prefix | Source                               |
|-----------------|----------------|--------------------------------------|
| terminal        | `>`            | `providers/TerminalProvider.qml`     |
| files           | `/`            | `providers/FilesProvider.qml`        |
| system          | `:`            | `providers/SystemProvider.qml`       |
| web             | `!`            | `providers/WebProvider.qml`          |
| help            | `?`            | `providers/HelpProvider.qml`         |
| runner modes    | `@`, `=`, …    | Milou `ResultsView` with `singleRunner` |
| default         | –              | `AliasesProvider` items on top + KRunner (Milou) results |
| empty field     | –              | `providers/HistoryProvider.qml` (recent items) |

Every mode can be disabled and its prefix changed in the settings. A disabled
mode's prefix is treated as ordinary text.

## Provider contract

A provider is a non-visual `QtObject`/`Item` instantiated once by `main.qml`.
It is duck-typed; it must provide:

```qml
Item {
    // --- set by the core ---
    property var core                 // the PlasmoidItem (API below)
    property string query: ""         // the query with the mode prefix stripped and trimmed
                                      // (AliasesProvider/HistoryProvider get the full query)
    property bool active: false       // true while this provider's mode is selected

    // --- read by the core ---
    property var items: []            // array of result objects, see below
    property bool busy: false         // optional: show a busy indicator
    property string emptyText: ""     // optional: text shown when items is empty and the mode is active

    // Run item `index`. `modifiers` are Qt.KeyboardModifiers of the Enter press
    // (0 for a mouse click). Call core.reset() when the popup should close.
    function activate(index, modifiers) { }

    // Run action `actionIndex` of item `index` (index into item.actions).
    function runAction(index, actionIndex) { }
}
```

Providers should only compute `items` while `active` is true (or, for
AliasesProvider, while the default mode is active) and debounce anything
expensive (≈150 ms `Timer`).

### Result item

```js
{
    text: "Display text",           // plain text; the core highlights the query in it
    subtext: "Secondary line",      // optional, plain text
    icon: "icon-name",              // icon name or file path/URL
    category: "Group header",       // optional, items with equal category are grouped
    actions: [                      // optional; shown as buttons, Shift+Enter = actions[0], Alt+Enter = actions[1]
        { icon: "folder-open", text: "Otevřít složku" }
    ],
    highlight: "text to highlight", // optional; defaults to the provider's query
    completion: "> git status",     // optional; Tab replaces the field text with it
    preselect: true,                // AliasesProvider only: select this item instead of the first KRunner result
    data: {}                        // anything the provider needs in activate()
}
```

### Core API (`core.*`)

| Member | Description |
|---|---|
| `core.cfg` | `Plasmoid.configuration` (read keys, assign to persist) |
| `core.query` | full raw query text |
| `core.setQuery(text)` | replace the field text (keeps focus, cursor at end) |
| `core.reset()` | clear the field and close the popup |
| `core.exec(cmd, callback)` | run a `/bin/sh -c` command line asynchronously; `callback(stdout, stderr, exitCode)` is optional |
| `core.runInTerminal(command, options)` | open the configured terminal; `options = { workdir, keepOpen, sudo, background }`; `command` may be `""` |
| `core.openUrl(urlOrPath)` | open with the default application (`xdg-open`) |
| `core.copyToClipboard(text)` | copy text to the clipboard |
| `core.notify(title, text, icon)` | show a desktop notification |
| `core.addHistory(entry)` | record a recent item, see *History* |
| `core.modes` | array of enabled modes `{ prefix, name, description, icon }` (for HelpProvider) |
| `core.runQuery(text)` | set the query and run the first KRunner result once it is available |

`code/util.js` (`import "../../code/util.js" as Util` from `ui/providers/`):

- `Util.shellQuote(s)` – single-quote for `/bin/sh`
- `Util.fuzzyScore(pattern, text)` – `-1` when not matching, higher is better
- `Util.expandHome(path)` – `~` → `$HOME` (for shell strings: returns `"$HOME/..."`)

## History

`core.addHistory(entry)` stores a JSON object in `cfg.history` (newest first,
deduplicated by `kind` + `key`, trimmed to `cfg.historyMax`), only when
`cfg.historyEnabled` is true:

```js
{ kind: "query",    key: "firefox",       text: "Firefox", subtext: "firefox", icon: "firefox" }   // KRunner result; re-run via core.runQuery(key)
{ kind: "terminal", key: "git status",    text: "git status", icon: "utilities-terminal" }
{ kind: "file",     key: "/home/u/a.txt", text: "a.txt", subtext: "/home/u", icon: "text-plain" }
{ kind: "alias",    key: "gs",            text: "gs → git status", icon: "..." }
{ kind: "web",      key: "<url>",         text: "Hledat „x“ na DuckDuckGo", icon: "internet-web-browser" }
{ kind: "system",   key: "lock",          text: "Zamknout obrazovku", icon: "system-lock-screen" }
```

The core records `query` entries itself; providers record their own kinds.
HistoryProvider re-runs entries: `query` → `core.runQuery`, `terminal` →
`core.runInTerminal`, `file`/`web` → `core.openUrl`, `alias`/`system` → by
setting the query to the alias/`:` action (`core.setQuery`) – or directly if it
can.

Terminal command history is kept separately in `cfg.terminalHistory` by
TerminalProvider.

## Keys (handled by the core)

| Key | Action |
|---|---|
| Enter | `activate(index, 0)` / run KRunner result |
| Shift+Enter | first action of the item (`runAction(index, 0)`) |
| Alt+Enter | second action (`runAction(index, 1)`) |
| Ctrl+Enter | run the whole query in the terminal |
| ↑ / ↓ | move selection across provider items and KRunner results |
| Tab | replace the field text with `item.completion` of the selected item |
| End / → (at end of text) | accept the inline "ghost text" suggestion (`core.ghostSuggestion`) |
| Esc | clear and close |

## Gotchas

- Never derive logic from `visible` of items inside the results window: an item's
  effective visibility also depends on the (hidden) window, which creates a
  deadlock (no results → window hidden → results "invisible"). Views expose an
  own `shown` flag instead.
- `console.log` is filtered out in plasmashell on Fedora; use `console.warn` when
  debugging, and `plasmawindowed org.psvec.searchbar` to load the widget standalone.
- The panel draws a "Panel Focus Indicator" (tab highlight) under the focused
  applet; the field hides it while it has focus.
