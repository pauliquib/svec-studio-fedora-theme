import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Obecné")
        icon: "configure"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Režimy")
        icon: "view-list-symbolic"
        source: "configModes.qml"
    }
    ConfigCategory {
        name: i18n("Terminál")
        icon: "utilities-terminal"
        source: "configTerminal.qml"
    }
    ConfigCategory {
        name: i18n("Soubory")
        icon: "folder"
        source: "configFiles.qml"
    }
    ConfigCategory {
        name: i18n("Historie")
        icon: "view-history"
        source: "configHistory.qml"
    }
    ConfigCategory {
        name: i18n("Aliasy")
        icon: "bookmarks"
        source: "configAliases.qml"
    }
    ConfigCategory {
        name: i18n("KRunner")
        icon: "plasma-search"
        source: "configRunners.qml"
    }
}
