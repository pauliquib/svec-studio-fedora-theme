import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Lists the installed KRunner plugins (shared libraries and D-Bus runners).
// `runners` is an array of { id, name } sorted by name, filled asynchronously.
Item {
    id: root

    property var runners: []

    readonly property var knownNames: ({
        "calculator": i18n("Kalkulačka"),
        "helprunner": i18n("Nápověda"),
        "krunner_appstream": i18n("Software Center (AppStream)"),
        "krunner_bookmarksrunner": i18n("Záložky"),
        "krunner_charrunner": i18n("Speciální znaky"),
        "krunner_colors": i18n("Barvy"),
        "krunner_dictionary": i18n("Slovník"),
        "krunner_katesessions": i18n("Sezení Kate"),
        "krunner_keys": i18n("Klávesové zkratky"),
        "krunner_kill": i18n("Ukončení aplikací"),
        "krunner_konsoleprofiles": i18n("Profily Konsole"),
        "krunner_kwin": "KWin",
        "krunner_pimcontacts": i18n("Kontakty"),
        "krunner_placesrunner": i18n("Místa"),
        "krunner_plasma-desktop": i18n("Plasma"),
        "krunner_powerdevil": i18n("Správa napájení"),
        "krunner_recentdocuments": i18n("Nedávné dokumenty"),
        "krunner_services": i18n("Aplikace"),
        "krunner_sessions": i18n("Sezení a uživatelé"),
        "krunner_shell": i18n("Příkazový řádek"),
        "krunner_spellcheck": i18n("Kontrola pravopisu"),
        "krunner_systemsettings": i18n("Nastavení systému"),
        "krunner_webshortcuts": i18n("Webové zkratky"),
        "locations": i18n("Umístění (cesty a URL)"),
        "org.kde.datetime": i18n("Datum a čas"),
        "unitconverter": i18n("Převod jednotek"),
        "windows": i18n("Okna"),
        "baloosearch": i18n("Hledání souborů (Baloo)"),
        "browserhistory": i18n("Historie prohlížeče"),
        "browsertabs": i18n("Karty prohlížeče"),
        "org.kde.activities2": i18n("Aktivity")
    })

    function nameFor(id, fallback) {
        return knownNames[id] || fallback || id
    }

    P5Support.DataSource {
        engine: "executable"
        onNewData: (sourceName, data) => {
            const seen = {}
            const list = []
            for (const line of data.stdout.split("\n")) {
                const sep = line.indexOf("|")
                const id = sep < 0 ? line.trim() : line.slice(0, sep).trim()
                if (!id || seen[id]) continue
                seen[id] = true
                list.push({ id: id, name: root.nameFor(id, sep < 0 ? "" : line.slice(sep + 1).trim()) })
            }
            list.sort((a, b) => a.name.localeCompare(b.name))
            root.runners = list
            disconnectSource(sourceName)
        }
        Component.onCompleted: connectSource(
            'pd=$(qtpaths6 --plugin-dir 2>/dev/null || qtpaths-qt6 --plugin-dir 2>/dev/null); '
            + 'for f in "$pd"/kf6/krunner/*.so; do [ -e "$f" ] && b=${f##*/} && echo "${b%.so}|"; done; '
            + 'for f in /usr/share/krunner/dbusplugins/*.desktop "$HOME"/.local/share/krunner/dbusplugins/*.desktop; do '
            + '[ -e "$f" ] || continue; '
            + 'id=$(sed -n "s/^X-KDE-PluginInfo-Name=//p" "$f" | head -1); '
            + 'n=$(sed -n "s/^Name=//p" "$f" | head -1); '
            + 'echo "${id:-$(basename "$f" .desktop)}|$n"; done')
    }
}
