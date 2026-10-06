import QtQuick

import "../../code/util.js" as Util

// System actions (":" mode): lock, log out, suspend, reboot, ...
Item {
    id: provider

    property var core
    property string query: ""
    property bool active: false
    property var items: []
    property bool busy: false
    property string emptyText: i18n("Žádná systémová akce neodpovídá")

    // qdbus is called qdbus6 or qdbus-qt6 on some distributions
    readonly property string qdbus: 'q=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus); "$q"'

    readonly property var actions: {
        const confirm = core && core.cfg.systemConfirm
        const q = qdbus
        const session = (prompt, direct) => confirm
            ? q + " org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt." + prompt
            : q + " org.kde.Shutdown /Shutdown org.kde.Shutdown." + direct
        const power = method => q + " org.kde.Solid.PowerManagement"
            + " /org/kde/Solid/PowerManagement/Actions/SuspendSession"
            + " org.kde.Solid.PowerManagement.Actions.SuspendSession." + method
        const lock = q + " org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.Lock"
        return [
            { id: "lock", icon: "system-lock-screen", command: lock,
              text: i18n("Zamknout obrazovku"), subtext: i18n("Uzamkne sezení"),
              keywords: "zamknout zámek lock screen" },
            { id: "logout", icon: "system-log-out", command: session("promptLogout", "logout"),
              text: i18n("Odhlásit"), subtext: i18n("Ukončí sezení"),
              keywords: "odhlásit odhlášení logout log out sign out" },
            { id: "suspend", icon: "system-suspend", command: power("suspendToRam"),
              text: i18n("Uspat"), subtext: i18n("Uspání do paměti"),
              keywords: "uspat spánek suspend sleep" },
            { id: "hibernate", icon: "system-suspend-hibernate", command: power("suspendToDisk"),
              text: i18n("Hibernovat"), subtext: i18n("Uspání na disk"),
              keywords: "hibernovat hibernace hibernate" },
            { id: "reboot", icon: "system-reboot", command: session("promptReboot", "logoutAndReboot"),
              text: i18n("Restartovat"), subtext: i18n("Restartuje počítač"),
              keywords: "restartovat restart reboot" },
            { id: "shutdown", icon: "system-shutdown", command: session("promptShutDown", "logoutAndShutdown"),
              text: i18n("Vypnout"), subtext: i18n("Vypne počítač"),
              keywords: "vypnout vypnutí shutdown power off poweroff halt" },
            { id: "switchuser", icon: "system-switch-user",
              // Same as Plasma's SessionManagement: lock first, then switch to the greeter
              command: lock + "; " + q + " --system org.freedesktop.DisplayManager \"$XDG_SEAT_PATH\""
                       + " org.freedesktop.DisplayManager.Seat.SwitchToGreeter",
              text: i18n("Přepnout uživatele"), subtext: i18n("Otevře přihlašovací obrazovku pro jiného uživatele"),
              keywords: "přepnout uživatele switch user" },
            { id: "settings", icon: "preferences-system", command: "systemsettings",
              text: i18n("Nastavení systému"), subtext: i18n("Otevře Nastavení systému"),
              keywords: "nastavení systému system settings preferences" },
            { id: "monitor", icon: "utilities-system-monitor", command: "plasma-systemmonitor",
              text: i18n("Sledování systému"), subtext: i18n("Procesy a využití prostředků"),
              keywords: "sledování systému procesy system monitor task manager top" },
            { id: "restartplasma", icon: "view-refresh",
              command: "systemctl --user restart plasma-plasmashell.service || (kquitapp6 plasmashell; kstart plasmashell)",
              text: i18n("Restartovat Plasmu"), subtext: i18n("Znovu spustí plasmashell (panel a plochu)"),
              keywords: "restartovat plasmu plasma plasmashell restart reload panel" },
            { id: "emptytrash", icon: "trash-empty", command: "ktrash6 --empty",
              text: i18n("Vysypat koš"), subtext: i18n("Trvale smaže soubory v koši"),
              keywords: "vysypat koš trash empty bin" }
        ]
    }

    function update() {
        if (!active) {
            items = []
            return
        }
        const scored = []
        actions.forEach((a, i) => {
            const score = query.length === 0 ? -i : Util.fuzzyScore(query, a.text + " " + a.keywords)
            if (query.length === 0 || score >= 0) {
                scored.push({ score: score, item: {
                    text: a.text,
                    subtext: a.subtext,
                    icon: a.icon,
                    category: i18n("Systém"),
                    data: { id: a.id, command: a.command }
                } })
            }
        })
        scored.sort((a, b) => b.score - a.score)
        items = scored.map(s => s.item)
    }

    onQueryChanged: update()
    onActiveChanged: update()
    onActionsChanged: update()

    // Runs an action by id (also usable by the history to re-run an entry directly).
    function run(id) {
        const a = actions.find(a => a.id === id)
        if (!a) {
            return false
        }
        core.exec(a.command)
        core.addHistory({ kind: "system", key: a.id, text: a.text, icon: a.icon })
        core.reset()
        return true
    }

    function activate(index, modifiers) {
        const item = items[index]
        if (item) {
            run(item.data.id)
        }
    }

    function runAction(index, actionIndex) {
    }
}
