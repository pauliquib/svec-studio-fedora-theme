.pragma library

// bin:  executable that opens an empty terminal window
// exec: prefix that is followed by a program and its arguments
var list = [
    { value: "konsole",        text: "Konsole",        bin: "konsole",        exec: "konsole -e" },
    { value: "kitty",          text: "kitty",          bin: "kitty",          exec: "kitty" },
    { value: "alacritty",      text: "Alacritty",      bin: "alacritty",      exec: "alacritty -e" },
    { value: "wezterm",        text: "WezTerm",        bin: "wezterm",        exec: "wezterm start --" },
    { value: "foot",           text: "foot",           bin: "foot",           exec: "foot" },
    { value: "ghostty",        text: "Ghostty",        bin: "ghostty",        exec: "ghostty -e" },
    { value: "gnome-terminal", text: "GNOME Terminal", bin: "gnome-terminal", exec: "gnome-terminal --" },
    { value: "ptyxis",         text: "Ptyxis",         bin: "ptyxis",         exec: "ptyxis --" },
    { value: "xfce4-terminal", text: "Xfce Terminal",  bin: "xfce4-terminal", exec: "xfce4-terminal -x" },
    { value: "xterm",          text: "XTerm",          bin: "xterm",          exec: "xterm -e" },
    { value: "custom",         text: "Vlastní…",       bin: "",               exec: "" }
]

function find(value) {
    for (var i = 0; i < list.length; ++i) {
        if (list[i].value === value) {
            return list[i]
        }
    }
    return list[0]
}

function label(value, custom) {
    if (value === "custom") {
        return custom.trim().split(/\s+/)[0] || "terminál"
    }
    return find(value).text
}

function shellQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'"
}

// "cd" prefix for the working directory; "" or "~" means the home directory.
function cdPrefix(workdir) {
    workdir = String(workdir || "").trim()
    if (workdir === "" || workdir === "~") {
        return 'cd "$HOME"'
    }
    if (workdir.startsWith("~/")) {
        return 'cd "$HOME"/' + shellQuote(workdir.slice(2)) + ' 2>/dev/null || cd "$HOME"'
    }
    return 'cd ' + shellQuote(workdir) + ' 2>/dev/null || cd "$HOME"'
}

// Builds a /bin/sh command line that opens the terminal detached from plasmashell.
// The command runs in the user's login shell; with keepOpen the shell stays
// interactive afterwards so the output remains visible. sudo prefixes the command.
function buildCommand(value, custom, command, options) {
    options = options || {}
    var t = find(value)
    var exec = t.exec
    var bin = t.bin
    if (value === "custom") {
        exec = custom.trim()
        bin = exec.split(/\s+/)[0]
    }
    if (!exec) {
        return ""
    }

    var prefix = cdPrefix(options.workdir) + ' && exec setsid -f '
    if (command.length === 0) {
        return prefix + (options.sudo ? exec + ' sudo -i' : bin)
    }
    if (options.sudo) {
        command = 'sudo ' + command
    }
    var inner = options.keepOpen ? command + '\nexec "$SHELL"' : command
    return prefix + exec + ' "${SHELL:-/bin/sh}" -c ' + shellQuote(inner)
}

// Command line that runs `command` without a terminal; stdout/stderr are returned
// to the caller (merged, last 40 lines). sudo uses pkexec for a graphical prompt.
function buildBackground(command, options) {
    options = options || {}
    var run = '"${SHELL:-/bin/sh}" -c ' + shellQuote(command)
    if (options.sudo) {
        run = 'pkexec ' + run
    }
    return cdPrefix(options.workdir) + ' && out=$(' + run + ' 2>&1); rc=$?; '
        + 'printf "%s\\n" "$out" | tail -n 40; exit $rc'
}
