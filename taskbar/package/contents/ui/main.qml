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
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

import "../code/legibility.js" as Legibility

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    // Let an auto-hiding panel show up when a window wants attention
    Plasmoid.status: cfg.unhideOnAttention && tasksModel.anyTaskDemandsAttention
        ? PlasmaCore.Types.NeedsAttentionStatus
        : PlasmaCore.Types.ActiveStatus

    // Hide the background of the panel hosting this applet: the shell's
    // Panel.qml skips its frame (and panelview its blur/shadow) when the
    // containment reports NoBackground. Other panels are not affected.
    Binding {
        target: Plasmoid.containment
        property: "backgroundHints"
        value: PlasmaCore.Types.NoBackground
        when: root.cfg.hidePanelBackground && Plasmoid.containment !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    // ---- geometry (web: slot 2.35rem, logo 1.85rem, gap 0.45rem) ------------

    readonly property int thickness: vertical ? width : height
    readonly property int iconSize: cfg.iconSize > 0
        ? Math.min(cfg.iconSize, thickness)
        : Math.max(16, Math.round(thickness * 0.66))
    readonly property int slotSize: Math.min(thickness, Math.round(iconSize * 1.27))
    readonly property int spacing: Math.round(slotSize * ([0.1, 0.19, 0.32][cfg.iconSpacing] ?? 0.19))
    readonly property int labelGap: Math.round(slotSize * 0.19)
    readonly property int chipPadding: Math.round((slotSize - iconSize) / 2)
    // Extra room after the label so the text doesn't end flush with the pill edge
    readonly property int labelEndPadding: labelGap
    // ---- readability on any background --------------------------------------------
    // 0 off, 1 contrast outline, 2 backdrop behind the label, 3 both
    readonly property bool useShadow: cfg.legibilityMode === 1 || cfg.legibilityMode === 3
    readonly property bool useBackdrop: cfg.legibilityMode === 2 || cfg.legibilityMode === 3
    readonly property color labelColor: cfg.accentLabels ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
    readonly property color outlineColor: Legibility.outlineColor(cfg.outlineColorMode, cfg.outlineCustomColor,
                                                                  labelColor, cfg.outlineOpacity)

    // Labels grow sideways, so only horizontal panels can show them
    readonly property bool canExpand: !vertical && cfg.showLabels

    // ---- tasks ----------------------------------------------------------------

    TaskManager.VirtualDesktopInfo { id: virtualDesktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }

    readonly property var sortModes: [
        TaskManager.TasksModel.SortManual,
        TaskManager.TasksModel.SortAlpha,
        TaskManager.TasksModel.SortVirtualDesktop,
        TaskManager.TasksModel.SortActivity,
        TaskManager.TasksModel.SortWindowPositionHorizontal
    ]
    readonly property bool manualSort: cfg.sortMode === 0

    TaskManager.TasksModel {
        id: tasksModel

        virtualDesktop: virtualDesktopInfo.currentDesktop
        screenGeometry: Plasmoid.containment.screenGeometry
        activity: activityInfo.currentActivity

        filterByVirtualDesktop: root.cfg.onlyCurrentDesktop
        filterByScreen: root.cfg.onlyCurrentScreen
        filterByActivity: root.cfg.onlyCurrentActivity
        filterNotMinimized: root.cfg.onlyMinimized
        // No filterHidden: minimized windows count as hidden and would vanish

        launchInPlace: true
        separateLaunchers: false
        hideActivatedLaunchers: true
        groupMode: root.cfg.groupWindows
            ? TaskManager.TasksModel.GroupApplications
            : TaskManager.TasksModel.GroupDisabled
        groupInline: false
        sortMode: root.sortModes[root.cfg.sortMode] ?? TaskManager.TasksModel.SortManual

        launcherList: root.cfg.launchers
        onLauncherListChanged: root.cfg.launchers = launcherList
    }

    // Bumped on model changes so labels and previews that read child rows of
    // groups (not roles of the group row itself) re-evaluate
    property int dataRevision: 0

    Connections {
        target: tasksModel
        function onDataChanged() { root.dataRevision++ }
        function onRowsInserted() { root.dataRevision++ }
        function onRowsRemoved() { root.dataRevision++ }
        function onRowsMoved() { root.dataRevision++ }
    }

    function taskIndex(row, child) {
        return child === undefined || child < 0
            ? tasksModel.makeModelIndex(row)
            : tasksModel.makeModelIndex(row, child)
    }

    function roleOf(row, child, role) {
        return tasksModel.data(taskIndex(row, child), role)
    }

    // Row of the active window inside a group, or -1
    function activeChild(row, count) {
        for (let j = 0; j < count; j++) {
            if (roleOf(row, j, TaskManager.AbstractTasksModel.IsActive)) return j
        }
        return -1
    }

    // Windows of a task as { row, child, title, uuid, minimized, icon }
    function windowsOf(chip) {
        if (!chip || chip.isLauncher) return []
        const list = []
        const add = (row, child) => {
            const ids = roleOf(row, child, TaskManager.AbstractTasksModel.WinIdList) || []
            list.push({
                row: row,
                child: child,
                title: String(roleOf(row, child, Qt.DisplayRole) || ""),
                uuid: ids.length > 0 ? String(ids[0]) : "",
                minimized: roleOf(row, child, TaskManager.AbstractTasksModel.IsMinimized) === true,
                icon: roleOf(row, child, Qt.DecorationRole)
            })
        }
        if (chip.isGroup) {
            for (let j = 0; j < chip.model.ChildCount; j++) add(chip.index, j)
        } else {
            add(chip.index, -1)
        }
        return list
    }

    // ---- actions ------------------------------------------------------------------

    function activate(chip) {
        const idx = taskIndex(chip.index)
        if (chip.isGroup) {
            switch (cfg.groupedClick) {
            case 1: // Present Windows
                presentWindows(chip)
                return
            case 2: // Textual list
                openGroupMenu(chip)
                return
            default: { // Cycle through the group's windows, starting after the active one
                const n = chip.model.ChildCount
                tasksModel.requestActivate(taskIndex(chip.index, (activeChild(chip.index, n) + 1) % n))
                return
            }
            }
        }
        if (chip.isActive && !chip.isLauncher && cfg.minimizeActive) {
            tasksModel.requestToggleMinimized(idx)
        } else {
            tasksModel.requestActivate(idx)
        }
    }

    function middleClick(chip) {
        const idx = taskIndex(chip.index)
        switch (cfg.middleClick) {
        case 1: // Close window or group
            if (!chip.isLauncher) tasksModel.requestClose(idx)
            break
        case 2: // New instance
            tasksModel.requestNewInstance(idx)
            break
        case 3: // Minimize / restore window or group
            if (!chip.isLauncher) tasksModel.requestToggleMinimized(idx)
            break
        case 4: // Toggle grouping
            if (!chip.isLauncher) tasksModel.requestToggleGrouping(idx)
            break
        case 5: // Bring to the current virtual desktop
            if (!chip.isLauncher) tasksModel.requestVirtualDesktops(idx, [virtualDesktopInfo.currentDesktop])
            break
        }
    }

    // Called by plasmashell for Meta+1…9 (looks for activateTaskAtIndex(QVariant))
    function activateTaskAtIndex(index) {
        const rail = root.fullRepresentationItem
        const chip = rail ? rail.chipAtPosition(index) : null
        if (chip) activate(chip)
    }

    // ---- KWin effects over D-Bus --------------------------------------------------

    P5Support.DataSource {
        id: shell
        engine: "executable"
        connectedSources: []
        onNewData: source => disconnectSource(source)
    }

    function kwinCall(path, method, uuids) {
        const list = uuids.filter(u => /^[A-Za-z0-9{}\-]+$/.test(u)).map(u => "'" + u + "'")
        const arg = list.length > 0 ? "[" + list.join(",") + "]" : "@as []"
        shell.connectSource("gdbus call --session --dest org.kde.KWin --object-path " + path
                            + " --method " + method + " \"" + arg + "\"")
    }

    function highlightWindows(uuids) {
        kwinCall("/org/kde/KWin/HighlightWindow", "org.kde.KWin.HighlightWindow.highlightWindows", uuids)
    }

    function presentWindows(chip) {
        kwinCall("/org/kde/KWin/Effect/WindowView1", "org.kde.KWin.Effect.WindowView1.activate",
                 windowsOf(chip).map(w => w.uuid))
    }

    // ---- audio ----------------------------------------------------------------------

    AudioStreams {
        id: audio
        active: root.cfg.audioIndicator
    }

    function toggleMute(chip) {
        const mute = !chip.audioMuted
        for (const s of chip.audioStreams) s.setMuted(mute)
    }

    // ---- window previews --------------------------------------------------------------

    property Item previewChip: null

    function showPreview(chip) {
        const list = windowsOf(chip)
        if (list.length === 0) {
            hidePreview()
            return
        }
        previewChip = chip
        previewContent.windows = list
        previewDialog.visualParent = chip
        previewDialog.visible = true
    }

    function hidePreview() {
        previewHideTimer.stop()
        if (previewDialog.visible) highlightWindows([])
        previewDialog.visible = false
        previewContent.windows = []
        previewChip = null
    }

    function refreshPreview() {
        if (previewDialog.visible && previewChip) showPreview(previewChip)
    }

    onDataRevisionChanged: refreshPreviewTimer.restart()

    Timer {
        id: refreshPreviewTimer
        interval: 50
        onTriggered: root.refreshPreview()
    }

    Timer {
        id: previewHideTimer
        interval: 300
        onTriggered: {
            if (!previewContent.hovered) root.hidePreview()
        }
    }

    PlasmaCore.Dialog {
        id: previewDialog
        type: PlasmaCore.Dialog.Tooltip
        location: Plasmoid.location
        flags: Qt.WindowDoesNotAcceptFocus
        hideOnWindowDeactivate: false
        visible: false

        mainItem: WindowPreviews {
            id: previewContent
            maxWidth: Plasmoid.containment.screenGeometry.width * 0.9

            onHoveredChanged: {
                if (hovered) previewHideTimer.stop()
                else previewHideTimer.restart()
            }
            onActivateWindow: (row, child) => {
                tasksModel.requestActivate(root.taskIndex(row, child))
                root.hidePreview()
            }
            onCloseWindow: (row, child) => tasksModel.requestClose(root.taskIndex(row, child))
            onHighlightWindow: uuid => {
                if (root.cfg.highlightWindows) root.highlightWindows(uuid.length > 0 ? [uuid] : [])
            }
        }
    }

    // ---- context menus -----------------------------------------------------------------

    property Item menuChip: null

    function openMenu(chip) {
        hidePreview()
        menuChip = chip
        contextMenu.visualParent = chip
        contextMenu.openRelative()
    }

    PlasmaExtras.Menu {
        id: contextMenu
        placement: PlasmaExtras.Menu.TopPosedLeftAlignedPopup

        PlasmaExtras.MenuItem {
            text: i18n("Start New Instance")
            icon: "list-add"
            onClicked: tasksModel.requestNewInstance(root.taskIndex(root.menuChip.index))
        }
        PlasmaExtras.MenuItem {
            readonly property bool pinned: root.menuChip !== null && root.menuChip.model.HasLauncher === true
            visible: root.menuChip !== null && String(root.menuChip.model.LauncherUrlWithoutIcon || "").length > 0
            text: pinned ? i18n("Unpin from Task Manager") : i18n("Pin to Task Manager")
            icon: pinned ? "window-unpin" : "window-pin"
            onClicked: {
                const url = root.menuChip.model.LauncherUrlWithoutIcon
                if (pinned) tasksModel.requestRemoveLauncher(url)
                else tasksModel.requestAddLauncher(url)
            }
        }
        PlasmaExtras.MenuItem {
            visible: root.menuChip !== null && root.menuChip.audioStreams.length > 0
            text: root.menuChip !== null && root.menuChip.audioMuted ? i18n("Unmute") : i18n("Mute")
            icon: root.menuChip !== null && root.menuChip.audioMuted ? "audio-volume-high" : "audio-volume-muted"
            onClicked: root.toggleMute(root.menuChip)
        }
        PlasmaExtras.MenuItem {
            visible: root.menuChip !== null && !root.menuChip.isLauncher && !root.menuChip.isGroup
            text: root.menuChip !== null && root.menuChip.isMinimized ? i18n("Restore") : i18n("Minimize")
            icon: "window-minimize"
            onClicked: tasksModel.requestToggleMinimized(root.taskIndex(root.menuChip.index))
        }
        PlasmaExtras.MenuItem {
            visible: root.menuChip !== null && !root.menuChip.isLauncher && !root.menuChip.isGroup
            text: root.menuChip !== null && root.menuChip.model.IsMaximized === true ? i18n("Unmaximize") : i18n("Maximize")
            icon: "window-maximize"
            onClicked: tasksModel.requestToggleMaximized(root.taskIndex(root.menuChip.index))
        }
        PlasmaExtras.MenuItem {
            visible: root.menuChip !== null && !root.menuChip.isLauncher
            text: root.menuChip !== null && root.menuChip.isGroup ? i18n("Close All") : i18n("Close")
            icon: "window-close"
            onClicked: tasksModel.requestClose(root.taskIndex(root.menuChip.index))
        }
        PlasmaExtras.MenuItem {
            separator: true
        }
        PlasmaExtras.MenuItem {
            text: i18n("Configure Task Manager…")
            icon: "configure"
            onClicked: Plasmoid.internalAction("configure").trigger()
        }
    }

    // List of a group's windows ("Clicking grouped task: shows a textual list")
    PlasmaExtras.Menu {
        id: groupMenu
        placement: PlasmaExtras.Menu.TopPosedLeftAlignedPopup
    }

    Component {
        id: groupMenuItem
        PlasmaExtras.MenuItem {
            property int row: -1
            property int child: -1
            onClicked: tasksModel.requestActivate(root.taskIndex(row, child))
        }
    }

    function openGroupMenu(chip) {
        hidePreview()
        groupMenu.clearMenuItems()
        for (const w of windowsOf(chip)) {
            const item = groupMenuItem.createObject(groupMenu, {
                text: w.title, icon: w.icon, row: w.row, child: w.child
            })
            groupMenu.addMenuItem(item)
        }
        groupMenu.visualParent = chip
        groupMenu.openRelative()
    }

    // ---- rail ---------------------------------------------------------------------

    fullRepresentation: Item {
        id: rail

        readonly property int count: repeater.count
        readonly property real railLength: count * root.slotSize + Math.max(0, count - 1) * root.spacing
        // Free space on each side so a fully grown pill never leaves the applet
        readonly property int reserve: root.canExpand && root.cfg.reserveSpace && count > 0
            ? Math.ceil((root.cfg.maxLabelWidth + root.labelGap + root.labelEndPadding) / 2) : 0
        readonly property real mainLength: railLength + 2 * reserve
        readonly property real mainSize: root.vertical ? height : width
        // Alignment of the icons when the applet fills the free panel space
        readonly property real offset: root.cfg.fillSpace
            ? Math.max(0, (mainSize - mainLength) * ([0, 0.5, 1][root.cfg.alignment] ?? 0.5))
            : 0

        // Web values 56 / 110 / 28 px against a 37.6 px slot
        readonly property real fullRadius: root.slotSize * 1.5
        readonly property real fadeRadius: root.slotSize * 2.9
        readonly property real stickyBias: root.slotSize * 0.75
        readonly property bool reducedMotion: Kirigami.Units.longDuration <= 1

        property int stickyIndex: -1
        property Item hoveredChip: null

        Layout.fillWidth: !root.vertical && root.cfg.fillSpace
        Layout.fillHeight: root.vertical && root.cfg.fillSpace
        Layout.minimumWidth: root.vertical ? -1 : mainLength
        Layout.preferredWidth: root.vertical ? -1 : mainLength
        Layout.maximumWidth: root.vertical || root.cfg.fillSpace ? Number.POSITIVE_INFINITY : mainLength
        Layout.minimumHeight: root.vertical ? mainLength : -1
        Layout.preferredHeight: root.vertical ? mainLength : -1
        Layout.maximumHeight: !root.vertical || root.cfg.fillSpace ? Number.POSITIVE_INFINITY : mainLength

        // Position on the rail, honouring "new tasks appear on the left"
        function visualIndex(index) {
            return root.cfg.reverseMode ? count - 1 - index : index
        }

        function chips() {
            const list = []
            for (let i = 0; i < repeater.count; i++) {
                const c = repeater.itemAt(i)
                if (c) list.push(c)
            }
            return list
        }

        function chipAtPosition(position) {
            for (const c of chips()) {
                if (c.position === position) return c
            }
            return null
        }

        function mainCoord(px, py) {
            return root.vertical ? py : px
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
            for (const target of list) {
                let nudge = 0
                for (const other of list) {
                    if (other === target) continue
                    const half = other.expand * other.grow * 0.5
                    nudge += other.position < target.position ? half : -half
                }
                target.nudge = nudge
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
            const p = mainCoord(px, py)
            const list = chips()
            const dists = []
            let nearest = -1
            let nearestDist = Infinity

            for (let i = 0; i < list.length; i++) {
                const d = Math.abs(p - list[i].slotCenter)
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
            setHovered(under)
            kick()
        }

        function clearTargets() {
            stickyIndex = -1
            for (const c of chips()) c.target = 0
            setHovered(null)
            kick()
        }

        // Window previews follow the chip under the pointer
        function setHovered(chip) {
            if (chip === hoveredChip) return
            hoveredChip = chip
            if (!root.cfg.showPreviews) return
            if (chip && !chip.isLauncher) {
                previewHideTimer.stop()
                if (previewDialog.visible) root.showPreview(chip)
                else previewShowTimer.restart()
            } else {
                previewShowTimer.stop()
                if (previewDialog.visible) previewHideTimer.restart()
            }
        }

        Timer {
            id: previewShowTimer
            interval: 500
            onTriggered: {
                if (rail.hoveredChip && !pointer.pressed) root.showPreview(rail.hoveredChip)
            }
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

                readonly property int position: rail.visualIndex(index)
                readonly property bool isLauncher: model.IsLauncher === true
                readonly property bool isGroup: model.IsGroupParent === true
                readonly property bool isActive: model.IsActive === true
                readonly property bool isMinimized: model.IsMinimized === true
                readonly property bool demandsAttention: model.IsDemandingAttention === true

                readonly property var audioStreams: {
                    audio.revision // dependency: stream list and state
                    if (!root.cfg.audioIndicator || isLauncher) return []
                    return audio.streamsFor(Number(model.AppPid || 0), model.AppName, model.AppId)
                }
                readonly property bool audioMuted: audioStreams.length > 0 && audioStreams.every(s => s.muted)
                readonly property bool playingAudio: audioStreams.some(s => !s.corked)
                readonly property bool showAudioBadge: playingAudio || audioMuted

                readonly property string labelText: {
                    const app = model.AppName || model.display || ""
                    if (isLauncher) return app
                    if (isGroup) return app + "  ·  " + model.ChildCount
                    return root.cfg.labelSource === 0 ? (model.display || app) : app
                }
                readonly property real labelWidth: Math.min(Math.ceil(metrics.advanceWidth), root.cfg.maxLabelWidth)
                readonly property real grow: root.canExpand && labelText.length > 0
                    ? labelWidth + root.labelGap + root.labelEndPadding : 0
                readonly property real slotCenter: rail.offset + rail.reserve
                    + position * (root.slotSize + root.spacing) + root.slotSize / 2

                onGrowChanged: rail.syncNudges()
                onPositionChanged: rail.syncNudges()

                width: root.slotSize + expand * grow
                height: root.slotSize
                x: root.vertical ? (rail.width - root.slotSize) / 2 : slotCenter + nudge - width / 2
                y: root.vertical ? slotCenter - root.slotSize / 2 : (rail.height - root.slotSize) / 2
                z: 1 + expand * 20
                opacity: pointer.dragChip === chip ? 0.6 : 1

                // Audio badge hit test in rail coordinates
                function hitsAudioBadge(px, py) {
                    if (!showAudioBadge || !root.cfg.muteOnIndicatorClick) return false
                    const p = mapFromItem(rail, px, py)
                    const pad = 2
                    return p.x >= audioBadge.x - pad && p.x <= audioBadge.x + audioBadge.width + pad
                        && p.y >= audioBadge.y - pad && p.y <= audioBadge.y + audioBadge.height + pad
                }

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

                // Backdrop: theme-coloured pill behind the expanded label, lifted by a
                // soft drop shadow like a tooltip, so the label keeps theme contrast
                Rectangle {
                    anchors.fill: parent
                    radius: Math.round(root.slotSize * 0.22)
                    color: Kirigami.Theme.backgroundColor
                    border.width: 1
                    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
                    opacity: root.useBackdrop ? chip.expand * root.cfg.backdropOpacity / 100 : 0
                    visible: opacity > 0

                    layer.enabled: visible
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "black"
                        shadowOpacity: 0.32
                        shadowBlur: 0.6
                        blurMax: 16
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 2
                    }
                }

                // Icon, label and indicator share one layer with a contrast outline
                // (dilated silhouette + feathered edge), the way desktop icon labels
                // stay readable on any wallpaper
                Item {
                    id: content
                    anchors.fill: parent

                    layer.enabled: root.useShadow
                    layer.effect: OutlineEffect {
                        outlineColor: root.outlineColor
                        radius: root.cfg.outlineWidth
                        softness: root.cfg.outlineSoftness
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
                        x: icon.x + icon.width + chip.expand * root.labelGap
                        anchors.verticalCenter: parent.verticalCenter
                        width: chip.expand * chip.labelWidth
                        height: label.implicitHeight
                        clip: true
                        visible: chip.expand > 0 && root.canExpand

                        PlasmaComponents3.Label {
                            id: label
                            x: (1 - chip.expand) * -6
                            width: chip.labelWidth
                            text: chip.labelText
                            textFormat: Text.PlainText
                            wrapMode: Text.NoWrap
                            maximumLineCount: 1
                            elide: Text.ElideRight
                            font.weight: Legibility.fontWeights[root.cfg.labelFontWeight] ?? Font.DemiBold
                            font.pointSize: root.cfg.labelFontSize > 0 ? root.cfg.labelFontSize
                                                                       : Kirigami.Theme.defaultFont.pointSize
                            color: root.labelColor
                            opacity: chip.labelOpacity
                        }
                    }

                    // Running / active / attention indicator on the panel edge side
                    Rectangle {
                        readonly property bool emphasized: chip.isActive || chip.demandsAttention
                        readonly property int edge: Plasmoid.location
                        readonly property int length: emphasized ? Math.round(root.iconSize * 0.4) : (chip.isGroup ? 8 : 4)

                        visible: !chip.isLauncher
                        width: root.vertical ? 3 : length
                        height: root.vertical ? length : 3
                        radius: 1.5
                        x: edge === PlasmaCore.Types.LeftEdge ? 1
                         : edge === PlasmaCore.Types.RightEdge ? parent.width - width - 1
                         : icon.x + (icon.width - width) / 2
                        y: edge === PlasmaCore.Types.TopEdge ? 1
                         : root.vertical ? (parent.height - height) / 2
                         : parent.height - height - 1
                        color: chip.demandsAttention ? Kirigami.Theme.neutralTextColor
                             : chip.isActive ? Kirigami.Theme.highlightColor
                             : Kirigami.Theme.textColor
                        opacity: emphasized ? 1 : 0.5

                        Behavior on width {
                            NumberAnimation { duration: Kirigami.Units.shortDuration }
                        }
                        Behavior on height {
                            NumberAnimation { duration: Kirigami.Units.shortDuration }
                        }
                    }
                } // content

                // Playing / muted audio badge on a corner of the icon.
                // Styles: 0 accent, 1 theme (dark circle), 2 glyph only, 3 outline ring
                Item {
                    id: audioBadge
                    readonly property int style: root.cfg.audioBadgeStyle
                    readonly property int size: Math.max(12, Math.round(root.iconSize * ([0.34, 0.42, 0.52][root.cfg.audioBadgeSize] ?? 0.42)))
                    // 0 top right, 1 top left, 2 bottom right, 3 bottom left
                    readonly property int corner: root.cfg.audioBadgePosition
                    readonly property bool atLeft: corner === 1 || corner === 3
                    readonly property bool atBottom: corner === 2 || corner === 3
                    readonly property color textColor: Kirigami.Theme.textColor
                    // Transparent margin inside the outline layer: the shader clamps
                    // at the texture edge and would smear a ring into a square
                    readonly property int pad: Math.ceil(root.cfg.outlineWidth + root.cfg.outlineSoftness) + 1

                    visible: chip.showAudioBadge
                    width: size
                    height: size
                    x: atLeft ? Math.max(0, icon.x - size * 0.3) : icon.x + icon.width - size * 0.7
                    y: atBottom ? Math.min(parent.height - size, icon.y + icon.height - size * 0.75)
                                : Math.max(0, icon.y - size * 0.25)

                    Item {
                        anchors.fill: parent
                        anchors.margins: -audioBadge.pad

                        // Without a filled circle the glyph sits on the wallpaper, so it
                        // gets the same contrast outline as icons and labels
                        layer.enabled: root.useShadow && (audioBadge.style === 2 || audioBadge.style === 3)
                        layer.effect: OutlineEffect {
                            outlineColor: root.outlineColor
                            radius: root.cfg.outlineWidth
                            softness: root.cfg.outlineSoftness
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: audioBadge.pad
                            radius: width / 2
                            color: audioBadge.style === 0 ? Kirigami.Theme.highlightColor
                                 : audioBadge.style === 1 ? Kirigami.Theme.backgroundColor
                                 : "transparent"
                            border.width: audioBadge.style === 3 ? Math.max(1.5, audioBadge.size / 10)
                                        : (audioBadge.style === 2 ? 0 : 1)
                            border.color: audioBadge.style === 3 ? Kirigami.Theme.highlightColor
                                        : audioBadge.style === 0 ? Qt.rgba(0, 0, 0, 0.2)
                                        : Qt.rgba(audioBadge.textColor.r, audioBadge.textColor.g, audioBadge.textColor.b, 0.25)

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: Math.round(audioBadge.size * (audioBadge.style === 2 ? 0.95 : 0.7))
                                height: width
                                source: chip.audioMuted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                                color: audioBadge.style === 0 ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                                isMask: true
                            }
                        }
                    }
                }

            }
        }

        MouseArea {
            id: pointer
            anchors.fill: parent
            z: 1000
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

            property Item pressChip: null
            property Item dragChip: null
            property real pressCoord: 0
            property bool suppressClick: false
            property real wheelDelta: 0

            onPositionChanged: mouse => {
                if (pressChip && (mouse.buttons & Qt.LeftButton) && root.manualSort) {
                    const p = rail.mainCoord(mouse.x, mouse.y)
                    if (!dragChip && Math.abs(p - pressCoord) > Qt.styleHints.startDragDistance) {
                        dragChip = pressChip
                        root.hidePreview()
                    }
                    if (dragChip) {
                        reorderTo(p)
                        return
                    }
                }
                rail.pointAt(mouse.x, mouse.y)
            }
            onExited: rail.clearTargets()

            onPressed: mouse => {
                const c = rail.chipUnder(mouse.x, mouse.y)
                // Empty space: let Plasma show the default applet menu
                if (!c) {
                    mouse.accepted = false
                    return
                }
                suppressClick = false
                pressChip = mouse.button === Qt.LeftButton ? c : null
                pressCoord = rail.mainCoord(mouse.x, mouse.y)
                previewShowTimer.stop()
            }
            onReleased: {
                if (dragChip) {
                    tasksModel.syncLaunchers()
                    suppressClick = true
                }
                dragChip = null
                pressChip = null
            }
            onClicked: mouse => {
                if (suppressClick) return
                const c = rail.chipUnder(mouse.x, mouse.y)
                if (!c) return
                if (mouse.button === Qt.MiddleButton) {
                    root.middleClick(c)
                } else if (mouse.button === Qt.RightButton) {
                    root.openMenu(c)
                } else if (c.hitsAudioBadge(mouse.x, mouse.y)) {
                    root.toggleMute(c)
                } else {
                    root.hidePreview()
                    root.activate(c)
                }
            }

            onWheel: wheel => {
                if (root.cfg.wheelMode === 0) {
                    wheel.accepted = false
                    return
                }
                wheelDelta += wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                while (Math.abs(wheelDelta) >= 120) {
                    const step = wheelDelta > 0 ? -1 : 1
                    wheelDelta -= -step * 120
                    cycleWindows(step, rail.chipUnder(wheel.x, wheel.y))
                }
            }

            // Move the dragged task to the slot under the pointer
            function reorderTo(p) {
                const pitch = root.slotSize + root.spacing
                const slot = Math.round((p - rail.offset - rail.reserve - root.slotSize / 2) / pitch)
                const position = Math.max(0, Math.min(rail.count - 1, slot))
                const to = rail.visualIndex(position)
                if (to !== dragChip.index) tasksModel.move(dragChip.index, to)
            }

            // Scroll wheel: cycle through all windows, or through the hovered task's windows
            function cycleWindows(step, hovered) {
                const windows = []
                if (root.cfg.wheelMode === 2) {
                    if (!hovered || hovered.isLauncher) return
                    for (const w of root.windowsOf(hovered)) windows.push(w)
                } else {
                    const ordered = rail.chips().sort((a, b) => a.position - b.position)
                    for (const c of ordered) {
                        for (const w of root.windowsOf(c)) windows.push(w)
                    }
                }
                const candidates = windows.filter(w => !(root.cfg.wheelSkipMinimized && w.minimized))
                if (candidates.length === 0) return
                let current = candidates.findIndex(w =>
                    root.roleOf(w.row, w.child, TaskManager.AbstractTasksModel.IsActive) === true)
                const next = current < 0 ? 0 : (current + step + candidates.length) % candidates.length
                const w = candidates[next]
                tasksModel.requestActivate(root.taskIndex(w.row, w.child))
            }
        }

        // Dragging files over a task raises its window; dropping opens them with
        // that application, dropping .desktop files pins them as launchers
        DropArea {
            id: fileDrop
            anchors.fill: parent

            property Item target: null

            onEntered: drag => drag.accepted = drag.hasUrls
            onPositionChanged: drag => {
                const c = rail.chipUnder(drag.x, drag.y)
                if (c !== target) {
                    target = c
                    if (c && !c.isLauncher) dragActivateTimer.restart()
                    else dragActivateTimer.stop()
                }
            }
            onExited: {
                target = null
                dragActivateTimer.stop()
            }
            onDropped: drop => {
                dragActivateTimer.stop()
                const urls = drop.urls.map(u => String(u))
                const desktopFiles = urls.filter(u => u.endsWith(".desktop"))
                if (desktopFiles.length > 0) {
                    for (const u of desktopFiles) tasksModel.requestAddLauncher(u)
                } else if (target) {
                    tasksModel.requestOpenUrls(root.taskIndex(target.index), drop.urls)
                }
                target = null
                drop.accept()
            }

            Timer {
                id: dragActivateTimer
                interval: 600
                onTriggered: {
                    const t = fileDrop.target
                    if (t && !t.isActive) tasksModel.requestActivate(root.taskIndex(t.index))
                }
            }
        }
    }
}
