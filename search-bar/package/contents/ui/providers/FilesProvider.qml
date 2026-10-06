import QtQuick

import "../../code/util.js" as Util

// Fuzzy file search (prefix cfg.filesPrefix, "/" by default).
// The shell tool (fd, find, locate or baloosearch6) produces candidates matching
// the query characters in order; they are then ranked with Util.fuzzyScore.
Item {
    id: provider

    property var core
    property string query: ""
    property bool active: false

    property var items: []
    property bool busy: false
    property string emptyText: ""

    // Filled by detect(): $HOME and the fd binary name ("" when not installed)
    property string home: ""
    property string fdBin: ""
    property bool detected: false
    property bool detecting: false

    // Incremented on every new search; outputs of older searches are dropped
    property int seq: 0

    readonly property var cfg: core ? core.cfg : null
    readonly property int candidateLimit: 300
    readonly property var skipDirs: [".git", "node_modules", ".cache"]

    onQueryChanged: restart()
    onActiveChanged: restart()

    Timer {
        id: debounce
        interval: 150
        onTriggered: provider.search()
    }

    function restart() {
        ++seq
        debounce.stop()
        if (!active) {
            busy = false
            items = []
            return
        }
        if (query.length === 0) {
            busy = false
            items = []
            emptyText = i18n("Napište název souboru…")
            return
        }
        emptyText = ""
        debounce.start()
    }

    function detect(callback) {
        detecting = true
        core.exec('printf "%s\\n" "$HOME"; for t in fd fdfind; do command -v "$t" >/dev/null 2>&1 && echo "$t"; done',
                  (stdout) => {
            const lines = String(stdout).split("\n").filter(l => l.length > 0)
            home = lines.length > 0 ? lines[0] : ""
            fdBin = lines.length > 1 ? lines[1] : ""
            detected = true
            detecting = false
            callback()
        })
    }

    // Search directory as typed in the settings, normalised to "~/…" or an absolute path.
    function searchDir() {
        let dir = String(cfg.filesDirectory || "").trim()
        if (dir === "" || dir === "~") {
            return "~"
        }
        if (!dir.startsWith("/") && !dir.startsWith("~/")) {
            dir = "~/" + dir
        }
        dir = dir.replace(/\/+$/, "")
        return dir === "" ? "/" : dir
    }

    function absolutePath(dir) {
        return dir === "~" ? home : dir.startsWith("~/") ? home + dir.slice(1) : dir
    }

    function tildePath(path) {
        if (home !== "" && (path === home || path.startsWith(home + "/"))) {
            return "~" + path.slice(home.length)
        }
        return path
    }

    // --- shell command builders ---
    // Every tool except baloo runs two passes: names containing the query as a
    // substring first, then the fuzzy pattern (a.*b.*c), so that the best
    // candidates survive the output limit. Duplicates are removed in rank().

    function regexPattern(q, fuzzy) {
        return q.split("").map(c => c.replace(/[\\.+*?()|\[\]{}^$]/g, "\\$&")).join(fuzzy ? ".*" : "")
    }

    function globPattern(q, fuzzy) {
        return "*" + q.split("").map(c => c.replace(/[\\*?\[\]]/g, "\\$&")).join(fuzzy ? "*" : "") + "*"
    }

    // awk filter keeping paths below $D and dropping skipped and (optionally) hidden ones
    function awkFilter(dirWord, showHidden) {
        const skip = "(^|/)(" + skipDirs.map(d => d.replace(/\./g, "\\.")).join("|") + ")(/|$)"
        const hidden = showHidden ? "" : " && rel !~ /(^|\\/)\\./"
        return "D=" + dirWord + " awk 'BEGIN { d = ENVIRON[\"D\"]; sub(/\\/+$/, \"\", d); d = d \"/\" } "
            + "index($0, d) == 1 { rel = substr($0, length(d) + 1); "
            + "if (rel !~ /" + skip.replace(/\//g, "\\/") + "/" + hidden + ") print }'"
    }

    // Appends "/" to directories
    readonly property string markDirs: 'while IFS= read -r p; do p="${p%/}"; [ -d "$p" ] && p="$p/"; printf "%s\\n" "$p"; done'

    function buildCommand(tool, dirWord, q, showHidden) {
        const fullPath = q.indexOf("/") >= 0
        const head = "head -n " + candidateLimit
        let pass
        if (tool === "fd") {
            const args = [fdBin, "-i", "--color", "never", "--absolute-path"]
            if (showHidden) args.push("--hidden")
            if (fullPath) args.push("--full-path")
            skipDirs.forEach(d => args.push("--exclude", d))
            pass = fuzzy => "timeout 3 " + args.join(" ") + " -- " + Util.shellQuote(regexPattern(q, fuzzy))
                + " " + dirWord + " 2>/dev/null"
        } else if (tool === "find") {
            const prune = skipDirs.map(d => "-name " + Util.shellQuote(d))
            if (!showHidden) prune.push("-name '.*'")
            pass = fuzzy => "timeout 3 find " + dirWord + " -mindepth 1 \\( " + prune.join(" -o ") + " \\) -prune -o "
                + (fullPath ? "-ipath " : "-iname ") + Util.shellQuote(globPattern(q, fuzzy))
                + " \\( -type d -printf '%p/\\n' -o -printf '%p\\n' \\) 2>/dev/null"
        } else if (tool === "locate") {
            pass = fuzzy => "timeout 3 locate -i " + (fullPath ? "" : "-b ") + "--regex "
                + Util.shellQuote(regexPattern(q, fuzzy)) + " 2>/dev/null | " + awkFilter(dirWord, showHidden)
        } else {
            // baloo: word query on the file name (last path segment)
            const words = q.split("/").filter(s => s.length > 0)
            return "timeout 3 baloosearch6 -d " + dirWord + " -l " + candidateLimit + " -- "
                + Util.shellQuote(words.length > 0 ? words[words.length - 1] : q)
                + " 2>/dev/null | " + awkFilter(dirWord, showHidden) + " | " + head + " | " + markDirs
        }
        const both = "{ " + pass(false) + " | head -n " + (candidateLimit / 2) + "; "
            + (q.length > 1 ? pass(true) + " | " + head + "; " : "") + "}"
        return tool === "find" ? both : both + " | " + markDirs
    }

    function search() {
        if (!active || query.length === 0 || !core) {
            return
        }
        if (!detected) {
            if (!detecting) {
                busy = true
                detect(search)
            }
            return
        }
        let tool = String(cfg.filesTool || "auto")
        if (tool === "auto" || (tool === "fd" && fdBin === "")) {
            tool = fdBin !== "" ? "fd" : "find"
        }
        const q = query.replace(/\s+/g, "")
        if (q.length === 0) {
            busy = false
            return
        }
        const dir = searchDir()
        const dirAbs = absolutePath(dir)
        const cmd = buildCommand(tool, Util.expandHome(dir), q, cfg.filesShowHidden)
        const mySeq = ++seq
        busy = true
        core.exec(cmd, (stdout) => {
            if (mySeq !== seq) {
                return
            }
            busy = false
            items = rank(String(stdout).split("\n"), q, dirAbs)
            emptyText = items.length === 0 ? i18n("Žádné soubory nenalezeny") : ""
        })
    }

    function rank(lines, q, dirAbs) {
        const prefix = dirAbs === "/" ? "/" : dirAbs + "/"
        const fullPath = q.indexOf("/") >= 0
        const seen = {}
        const scored = []
        for (const line of lines) {
            if (line.length === 0) continue
            const isDir = line.length > 1 && line.endsWith("/")
            const path = isDir ? line.slice(0, -1) : line
            if (seen[path]) continue
            seen[path] = true
            const name = path.slice(path.lastIndexOf("/") + 1)
            const rel = path.startsWith(prefix) ? path.slice(prefix.length) : path
            let score = fullPath ? -1 : Util.fuzzyScore(q, name)
            if (score < 0) {
                score = Util.fuzzyScore(q, rel)
                if (score < 0) {
                    // baloo matches whole words, not the subsequence
                    score = 0
                }
                score -= 50
            }
            // prefer shallow paths on ties
            score -= rel.split("/").length
            scored.push({ path, name, isDir, score })
        }
        scored.sort((a, b) => b.score - a.score || a.path.length - b.path.length)

        const actions = cfg.actionsEnabled ? [
            { icon: "folder-open", text: i18n("Otevřít složku") },
            { icon: "edit-copy", text: i18n("Kopírovat cestu") },
            { icon: "utilities-terminal", text: i18n("Otevřít terminál zde") }
        ] : []
        return scored.slice(0, Math.max(1, cfg.filesMaxResults)).map(r => {
            const parent = r.path.slice(0, r.path.lastIndexOf("/")) || "/"
            return {
                text: r.name + (r.isDir ? "/" : ""),
                subtext: tildePath(parent),
                icon: r.isDir ? "folder" : iconFor(r.name),
                category: i18n("Soubory"),
                actions: actions,
                highlight: query,
                data: { path: r.path, isDir: r.isDir }
            }
        })
    }

    readonly property var iconMap: ({
        "image-x-generic": ["png", "jpg", "jpeg", "gif", "bmp", "webp", "svg", "tif", "tiff", "ico", "heic", "avif", "xcf", "kra"],
        "video-x-generic": ["mp4", "mkv", "webm", "avi", "mov", "wmv", "flv", "m4v", "mpg", "mpeg"],
        "audio-x-generic": ["mp3", "flac", "ogg", "opus", "wav", "m4a", "aac", "wma"],
        "application-pdf": ["pdf"],
        "text-x-script": ["sh", "bash", "zsh", "fish", "py", "pl", "rb", "lua", "js", "ts", "qml", "php"],
        "text-x-csrc": ["c", "h"],
        "text-x-c++src": ["cpp", "cc", "cxx", "hpp", "hh"],
        "text-html": ["html", "htm", "xhtml"],
        "text-markdown": ["md", "markdown"],
        "application-json": ["json"],
        "application-xml": ["xml", "kcfg", "ui"],
        "package-x-generic": ["zip", "tar", "gz", "tgz", "bz2", "xz", "zst", "7z", "rar", "rpm", "deb", "flatpak"],
        "application-x-cd-image": ["iso", "img"],
        "application-x-executable": ["exe", "appimage", "bin"],
        "x-office-document": ["doc", "docx", "odt", "rtf"],
        "x-office-spreadsheet": ["xls", "xlsx", "ods", "csv"],
        "x-office-presentation": ["ppt", "pptx", "odp"],
        "font-x-generic": ["ttf", "otf", "woff", "woff2"]
    })

    function iconFor(name) {
        const dot = name.lastIndexOf(".")
        if (dot > 0) {
            const ext = name.slice(dot + 1).toLowerCase()
            for (const icon in iconMap) {
                if (iconMap[icon].indexOf(ext) >= 0) return icon
            }
        }
        return "text-x-generic"
    }

    function dirOf(data) {
        return data.isDir ? data.path : (data.path.slice(0, data.path.lastIndexOf("/")) || "/")
    }

    function activate(index, modifiers) {
        const item = items[index]
        if (!item) return
        const path = item.data.path
        const cmd = String(cfg.filesOpenCommand || "").trim()
        if (cmd === "") {
            core.openUrl(path)
        } else if (cmd.indexOf("%f") >= 0) {
            core.exec(cmd.split("%f").join(Util.shellQuote(path)))
        } else {
            core.exec(cmd + " " + Util.shellQuote(path))
        }
        core.addHistory({
            kind: "file",
            key: path,
            text: item.text.replace(/\/$/, ""),
            subtext: item.subtext,
            icon: item.icon
        })
        core.reset()
    }

    function runAction(index, actionIndex) {
        const item = items[index]
        if (!item) return
        const dir = dirOf(item.data)
        if (actionIndex === 0) {
            core.openUrl(dir)
        } else if (actionIndex === 1) {
            core.copyToClipboard(item.data.path)
        } else if (actionIndex === 2) {
            core.runInTerminal("", { workdir: dir })
        } else {
            return
        }
        core.reset()
    }
}
