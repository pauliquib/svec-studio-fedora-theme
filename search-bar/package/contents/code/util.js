.pragma library

function shellQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'"
}

// Returns a shell word for a path, expanding a leading "~" to "$HOME".
function expandHome(path) {
    path = String(path || "").trim()
    if (path === "" || path === "~") {
        return '"$HOME"'
    }
    if (path.startsWith("~/")) {
        return '"$HOME"/' + shellQuote(path.slice(2))
    }
    return shellQuote(path)
}

// Subsequence match: every character of pattern must appear in text in order.
// Returns -1 when not matching, otherwise a score (higher is better) that favours
// contiguous runs, matches at word starts and matches near the beginning.
function fuzzyScore(pattern, text) {
    pattern = String(pattern).toLowerCase()
    const lower = String(text).toLowerCase()
    if (pattern.length === 0) {
        return 0
    }
    const direct = lower.indexOf(pattern)
    if (direct >= 0) {
        return 1000 - direct + (direct === 0 || /[\s\/._-]/.test(lower[direct - 1]) ? 200 : 0)
    }
    let score = 0
    let last = -2
    let pos = 0
    for (let i = 0; i < pattern.length; ++i) {
        const found = lower.indexOf(pattern[i], pos)
        if (found < 0) {
            return -1
        }
        if (found === last + 1) {
            score += 10
        }
        if (found === 0 || /[\s\/._-]/.test(lower[found - 1])) {
            score += 8
        }
        score -= Math.min(found - pos, 10)
        last = found
        pos = found + 1
    }
    return Math.max(score, 1)
}

function escapeHtml(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

// Returns rich text with the characters matching `pattern` in bold.
// A contiguous match is preferred, otherwise the fuzzy subsequence is marked.
function highlight(text, pattern) {
    text = String(text)
    pattern = String(pattern || "").trim()
    if (pattern.length === 0) {
        return escapeHtml(text)
    }
    const lower = text.toLowerCase()
    const p = pattern.toLowerCase()
    const direct = lower.indexOf(p)
    if (direct >= 0) {
        return escapeHtml(text.slice(0, direct))
            + "<b>" + escapeHtml(text.slice(direct, direct + p.length)) + "</b>"
            + escapeHtml(text.slice(direct + p.length))
    }
    let out = ""
    let pos = 0
    for (let i = 0; i < text.length; ++i) {
        if (pos < p.length && lower[i] === p[pos]) {
            out += "<b>" + escapeHtml(text[i]) + "</b>"
            ++pos
        } else {
            out += escapeHtml(text[i])
        }
    }
    return pos === p.length ? out : escapeHtml(text)
}
