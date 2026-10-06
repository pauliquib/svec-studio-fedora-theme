/*
 * Icon-only task manager. The hovered icon grows into a pill with its label,
 * ported from the app-chip rail on svec-elektro.cz (js/web-apps-render.js):
 *   - every icon sits in a fixed slot; the chip grows from the slot center
 *   - --expand (0–1) drives width, label width and pill tint
 *   - an expanding chip nudges neighbors outward by half of its growth
 *   - targets come from the pointer distance to slot centers (plateau + fade,
 *     sticky winner, chip under cursor wins), currents chase targets per frame
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    // ---- geometry (web: slot 2.35rem, logo 1.85rem, gap 0.45rem) ------------

    readonly property int thickness: vertical ? width : height
    readonly property int iconSize: cfg.iconSize > 0
        ? Math.min(cfg.iconSize, thickness)
        : Math.max(16, Math.round(thickness * 0.66))
    readonly property int slotSize: Math.min(thickness, Math.round(iconSize * 1.27))
    readonly property int spacing: Math.round(slotSize * 0.19)
    readonly property int chipPadding: Math.round((slotSize - iconSize) / 2)
    readonly property bool canExpand: !vertical

    // ---- tasks ----------------------------------------------------------------

    TaskManager.VirtualDesktopInfo { id: virtualDesktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }

    TaskManager.TasksModel {
        id: tasksModel

        virtualDesktop: virtualDesktopInfo.currentDesktop
        screenGeometry: Plasmoid.containment.screenGeometry
        activity: activityInfo.currentActivity

        filterByVirtualDesktop: root.cfg.onlyCurrentDesktop
        filterByScreen: root.cfg.onlyCurrentScreen
        filterByActivity: true
        filterHidden: true

        launchInPlace: true
        separateLaunchers: false
        hideActivatedLaunchers: true
        groupMode: root.cfg.groupWindows
            ? TaskManager.TasksModel.GroupApplications
            : TaskManager.TasksModel.GroupDisabled
        groupInline: false
        sortMode: TaskManager.TasksModel.SortManual

        launcherList: root.cfg.launchers
        onLauncherListChanged: root.cfg.launchers = launcherList
    }

    function activate(chip) {
        const idx = tasksModel.makeModelIndex(chip.index)
        if (chip.isGroup) {
            // Cycle through the group's windows, starting after the active one
            const n = chip.model.ChildCount
            let active = -1
            for (let j = 0; j < n; j++) {
                if (tasksModel.data(tasksModel.makeModelIndex(chip.index, j),
                                    TaskManager.AbstractTasksModel.IsActive)) {
                    active = j
                    break
                }
            }
            tasksModel.requestActivate(tasksModel.makeModelIndex(chip.index, (active + 1) % n))
        } else if (chip.isActive && !chip.isLauncher && cfg.minimizeActive) {
            tasksModel.requestToggleMinimized(idx)
        } else {
            tasksModel.requestActivate(idx)
        }
    }

    function newInstance(chip) {
        tasksModel.requestNewInstance(tasksModel.makeModelIndex(chip.index))
    }

    // ---- context menu -----------------------------------------------------------

    property Item menuChip: null

    function openMenu(chip) {
        menuChip = chip
        contextMenu.visualParent = chip
        contextMenu.openRelative()
    }

    PlasmaExtras.Menu {
        id: contextMenu
        placement: PlasmaExtras.Menu.TopPosedLeftAlignedPopup

        PlasmaExtras.MenuItem {
            text: i18n("Nová instance")
            icon: "list-add"
            onClicked: root.newInstance(root.menuChip)
        }
        PlasmaExtras.MenuItem {
            readonly property bool pinned: root.menuChip !== null && root.menuChip.model.HasLauncher === true
            visible: root.menuChip !== null && String(root.menuChip.model.LauncherUrlWithoutIcon || "").length > 0
            text: pinned ? i18n("Odepnout z panelu") : i18n("Připnout do panelu")
            icon: pinned ? "window-unpin" : "window-pin"
            onClicked: {
                const url = root.menuChip.model.LauncherUrlWithoutIcon
                if (pinned) tasksModel.requestRemoveLauncher(url)
                else tasksModel.requestAddLauncher(url)
            }
        }
        PlasmaExtras.MenuItem {
            visible: root.menuChip !== null && !root.menuChip.isLauncher && !root.menuChip.isGroup
            text: root.menuChip !== null && root.menuChip.isMinimized ? i18n("Obnovit") : i18n("Minimalizovat")
            icon: "window-minimize"
            onClicked: tasksModel.requestToggleMinimized(tasksModel.makeModelIndex(root.menuChip.index))
        }
        PlasmaExtras.MenuItem {
            visible: root.menuChip !== null && !root.menuChip.isLauncher
            text: root.menuChip !== null && root.menuChip.isGroup ? i18n("Zavřít všechna okna") : i18n("Zavřít")
            icon: "window-close"
            onClicked: tasksModel.requestClose(tasksModel.makeModelIndex(root.menuChip.index))
        }
        PlasmaExtras.MenuItem {
            separator: true
        }
        PlasmaExtras.MenuItem {
            text: i18n("Nastavit panel úloh…")
            icon: "configure"
            onClicked: Plasmoid.internalAction("configure").trigger()
        }
    }

    // ---- rail ---------------------------------------------------------------------

    fullRepresentation: Item {
        id: rail

        readonly property int count: repeater.count
        readonly property real railLength: count * root.slotSize + Math.max(0, count - 1) * root.spacing
        // Free space on each side so a fully grown pill never leaves the applet
        readonly property int reserve: root.canExpand && root.cfg.reserveSpace && count > 0
            ? Math.ceil((root.cfg.maxLabelWidth + root.spacing) / 2) : 0
        readonly property real mainLength: railLength + 2 * reserve

        // Web values 56 / 110 / 28 px against a 37.6 px slot
        readonly property real fullRadius: root.slotSize * 1.5
        readonly property real fadeRadius: root.slotSize * 2.9
        readonly property real stickyBias: root.slotSize * 0.75
        readonly property bool reducedMotion: Kirigami.Units.longDuration <= 1

        property int stickyIndex: -1

        Layout.minimumWidth: root.vertical ? -1 : mainLength
        Layout.preferredWidth: root.vertical ? -1 : mainLength
        Layout.maximumWidth: root.vertical ? Number.POSITIVE_INFINITY : mainLength
        Layout.minimumHeight: root.vertical ? mainLength : -1
        Layout.preferredHeight: root.vertical ? mainLength : -1
        Layout.maximumHeight: root.vertical ? mainLength : Number.POSITIVE_INFINITY

        function chips() {
            const list = []
            for (let i = 0; i < repeater.count; i++) {
                const c = repeater.itemAt(i)
                if (c) list.push(c)
            }
            return list
        }

        // Topmost chip whose (grown) area contains the point
        function chipUnder(px, py) {
            let best = null
            for (const c of chips()) {
                const inside = root.vertical
                    ? py >= c.y && py <= c.y + c.height
                    : px >= c.x && px <= c.x + c.width
                if (inside && (!best || c.expand > best.expand)) best = c
            }
            return best
        }

        function setExpand(c, value) {
            const v = Math.max(0, Math.min(1, value))
            c.expand = v
            // Label fades in ahead of full width so text is readable sooner
            c.labelOpacity = v <= 0 ? 0 : Math.min(1, 0.25 + v * 0.9)
        }

        function syncNudges() {
            // Each expanding chip pushes chips on its left further left and
            // chips on its right further right, so the pill never covers them.
            const list = chips()
            for (let j = 0; j < list.length; j++) {
                let nudge = 0
                for (let i = 0; i < list.length; i++) {
                    if (i === j) continue
                    const half = list[i].expand * list[i].grow * 0.5
                    nudge += i < j ? half : -half
                }
                list[j].nudge = nudge
            }
        }

        function tick(frameTime) {
            // Rates are tuned per 60 Hz frame on the web; scale to real frame time
            const frames = Math.max(0.25, Math.min(4, frameTime * 60))
            let needsMore = false
            for (const c of chips()) {
                const delta = c.target - c.expand
                if (Math.abs(delta) < 0.0015) {
                    setExpand(c, c.target)
                    continue
                }
                // Reach full readability quickly; ease out more slowly when leaving
                const rate = 1 - Math.pow(1 - (delta > 0 ? 0.22 : 0.12), frames)
                setExpand(c, c.expand + delta * rate)
                needsMore = true
            }
            syncNudges()
            if (!needsMore) ticker.stop()
        }

        function kick() {
            if (reducedMotion) {
                for (const c of chips()) setExpand(c, c.target)
                syncNudges()
                return
            }
            if (!ticker.running) ticker.start()
        }

        function pointAt(px, py) {
            if (!root.canExpand) return
            const list = chips()
            const dists = []
            let nearest = -1
            let nearestDist = Infinity

            for (let i = 0; i < list.length; i++) {
                const d = Math.abs(px - list[i].slotCenter)
                dists[i] = d
                if (d < nearestDist) {
                    nearestDist = d
                    nearest = i
                }
            }

            // Keep the sticky item until another one is clearly closer
            if (stickyIndex >= 0 && stickyIndex < list.length && dists[stickyIndex] < fadeRadius) {
                const stickyDist = dists[stickyIndex]
                if (nearest !== stickyIndex && nearestDist > stickyDist - stickyBias) {
                    nearest = stickyIndex
                    nearestDist = stickyDist
                }
            }

            // Prefer the chip under the cursor (covers the expanded label area)
            const under = chipUnder(px, py)
            if (under) {
                nearest = list.indexOf(under)
                nearestDist = Math.min(dists[nearest], fullRadius)
            }

            for (let j = 0; j < list.length; j++) {
                if (j !== nearest || nearestDist >= fadeRadius) {
                    list[j].target = 0
                } else if (nearestDist <= fullRadius) {
                    list[j].target = 1
                } else {
                    const t = 1 - (nearestDist - fullRadius) / (fadeRadius - fullRadius)
                    list[j].target = t * t * (3 - 2 * t)
                }
            }

            stickyIndex = nearestDist < fadeRadius ? nearest : -1
            kick()
        }

        function clearTargets() {
            stickyIndex = -1
            for (const c of chips()) c.target = 0
            kick()
        }

        FrameAnimation {
            id: ticker
            onTriggered: rail.tick(frameTime)
        }

        Repeater {
            id: repeater
            model: tasksModel
            onItemAdded: rail.syncNudges()
            onItemRemoved: {
                rail.stickyIndex = -1
                rail.syncNudges()
            }

            delegate: Item {
                id: chip

                required property int index
                required property var model

                property real target: 0
                property real expand: 0
                property real labelOpacity: 0
                property real nudge: 0

                readonly property bool isLauncher: model.IsLauncher === true
                readonly property bool isGroup: model.IsGroupParent === true
                readonly property bool isActive: model.IsActive === true
                readonly property bool isMinimized: model.IsMinimized === true
                readonly property bool demandsAttention: model.IsDemandingAttention === true

                readonly property string labelText: {
                    const app = model.AppName || model.display || ""
                    if (isLauncher) return app
                    if (isGroup) return app + "  ·  " + model.ChildCount
                    return root.cfg.labelSource === 0 ? (model.display || app) : app
                }
                readonly property real labelWidth: Math.min(Math.ceil(metrics.advanceWidth), root.cfg.maxLabelWidth)
                readonly property real grow: root.canExpand && labelText.length > 0 ? labelWidth + root.spacing : 0
                readonly property real slotCenter: rail.reserve + index * (root.slotSize + root.spacing) + root.slotSize / 2

                onGrowChanged: rail.syncNudges()

                width: root.slotSize + expand * grow
                height: root.slotSize
                x: root.vertical ? (rail.width - root.slotSize) / 2 : slotCenter + nudge - width / 2
                y: root.vertical ? slotCenter - root.slotSize / 2 : (rail.height - root.slotSize) / 2
                z: 1 + expand * 20

                TextMetrics {
                    id: metrics
                    font: label.font
                    text: chip.labelText
                }

                // Pill tint mixed in by expand (web: color-mix(--bg-tint, expand%))
                Rectangle {
                    anchors.fill: parent
                    radius: Math.round(root.slotSize * 0.22)
                    color: Kirigami.Theme.textColor
                    opacity: root.cfg.showHoverPill ? chip.expand * 0.1 : 0
                    visible: opacity > 0
                }

                Kirigami.Icon {
                    id: icon
                    x: root.chipPadding
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.iconSize
                    height: root.iconSize
                    source: chip.model.decoration
                }

                // Clip window: width grows with expand, the label itself stays full size
                Item {
                    x: icon.x + icon.width + chip.expand * root.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    width: chip.expand * chip.labelWidth
                    height: label.implicitHeight
                    clip: true
                    visible: chip.expand > 0

                    PlasmaComponents3.Label {
                        id: label
                        x: (1 - chip.expand) * -6
                        width: chip.labelWidth
                        text: chip.labelText
                        textFormat: Text.PlainText
                        wrapMode: Text.NoWrap
                        maximumLineCount: 1
                        elide: Text.ElideRight
                        font.weight: Font.DemiBold
                        opacity: chip.labelOpacity
                    }
                }

                // Running / active / attention indicator under the icon
                Rectangle {
                    readonly property bool emphasized: chip.isActive || chip.demandsAttention
                    readonly property int edge: Plasmoid.location

                    visible: !chip.isLauncher
                    width: emphasized ? Math.round(root.iconSize * 0.4) : (chip.isGroup ? 8 : 4)
                    height: 3
                    radius: height / 2
                    x: icon.x + (icon.width - width) / 2
                    y: edge === PlasmaCore.Types.TopEdge ? 1 : parent.height - height - 1
                    color: chip.demandsAttention ? Kirigami.Theme.neutralTextColor
                         : chip.isActive ? Kirigami.Theme.highlightColor
                         : Kirigami.Theme.textColor
                    opacity: emphasized ? 1 : 0.5

                    Behavior on width {
                        NumberAnimation { duration: Kirigami.Units.shortDuration }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: 1000
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

            onPositionChanged: mouse => rail.pointAt(root.vertical ? mouse.y : mouse.x, mouse.y)
            onExited: rail.clearTargets()

            onPressed: mouse => {
                // Empty space: let Plasma show the default applet menu
                if (!rail.chipUnder(mouse.x, mouse.y)) mouse.accepted = false
            }
            onClicked: mouse => {
                const c = rail.chipUnder(mouse.x, mouse.y)
                if (!c) return
                if (mouse.button === Qt.MiddleButton) root.newInstance(c)
                else if (mouse.button === Qt.RightButton) root.openMenu(c)
                else root.activate(c)
            }
        }
    }
}
