/*
 * Full-screen feedback for drag to close: the screen dims as a task is pulled
 * toward its center, and an elegant red cross appears once releasing closes it.
 * A layer-shell overlay on Wayland, a frameless always-on-top window on X11;
 * transparent for input either way, so the panel keeps its pointer grab.
 */
import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell

Window {
    id: overlay

    // 0–1 on the way to the arming distance
    property real progress: 0
    property bool armed: false
    property bool active: false
    // Screen geometry in global coordinates
    property rect geometry: Qt.rect(0, 0, 0, 0)

    // Ghost of the dragged icon, held where the cursor grabbed it
    property var ghostIcon: null
    property real ghostSize: 48
    // Cursor in global coordinates and its offset from the icon center
    property point cursor: Qt.point(0, 0)
    property point grabOffset: Qt.point(0, 0)

    // Emitted once the overlay has faded out and can be destroyed
    signal finished()

    readonly property color accent: "#ff4757"
    readonly property int duration: Kirigami.Units.longDuration

    // Plays the closing flourish, then hides
    function confirm() {
        active = false
        confirmed = true
        suckAnimation.restart()
        hideTimer.restart()
    }

    function cancel() {
        active = false
        confirmed = false
        hideTimer.restart()
    }

    property bool confirmed: false
    // Dimming sets in after the first fifth of the way
    readonly property real dim: active ? Math.max(0, (Math.min(1, progress) - 0.2) / 0.8) * 0.38 + (armed ? 0.2 : 0) : 0

    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowTransparentForInput
         | Qt.WindowDoesNotAcceptFocus | Qt.Tool | Qt.BypassWindowManagerHint
    color: "transparent"
    // Not a child of the panel window: a transient layer surface misbehaves
    transientParent: null
    x: geometry.x
    y: geometry.y
    width: geometry.width
    height: geometry.height

    LayerShell.Window.scope: "chiptasks-close"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                               | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    onActiveChanged: {
        if (active) {
            hideTimer.stop()
            suckAnimation.stop()
            ghost.suck = 0
            confirmed = false
            for (const s of Qt.application.screens) {
                if (s.virtualX === geometry.x && s.virtualY === geometry.y) {
                    overlay.screen = s
                    break
                }
            }
            visible = true
        }
    }

    Timer {
        id: hideTimer
        interval: overlay.duration * 2
        onTriggered: {
            overlay.visible = false
            overlay.finished()
        }
    }

    // Dimmed backdrop with a soft vignette so the center stays the focus
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: overlay.dim

        Behavior on opacity {
            NumberAnimation { duration: overlay.duration; easing.type: Easing.OutCubic }
        }
    }

    // Vignette: clear center, darker edges
    Shape {
        anchors.fill: parent
        opacity: overlay.dim * 1.5
        preferredRendererType: Shape.CurveRenderer

        Behavior on opacity {
            NumberAnimation { duration: overlay.duration; easing.type: Easing.OutCubic }
        }

        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: overlay.width / 2
                centerY: overlay.height / 2
                centerRadius: Math.hypot(overlay.width, overlay.height) / 2
                focalX: centerX
                focalY: centerY
                GradientStop { position: 0.25; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.6) }
            }
            PathRectangle { width: overlay.width; height: overlay.height }
        }
    }

    // The cross: a hairline ring with a faint red glass fill and two rounded strokes
    Item {
        id: cross
        readonly property real size: Math.round(Math.min(overlay.width, overlay.height) * 0.11)

        anchors.centerIn: parent
        width: size
        height: size
        opacity: overlay.confirmed ? 0 : overlay.active ? (overlay.armed ? 1 : overlay.progress * 0.18) : 0
        scale: overlay.confirmed ? 1.35 : overlay.armed && overlay.active ? 1 : 0.72 + overlay.progress * 0.12

        Behavior on opacity {
            NumberAnimation { duration: overlay.duration; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation {
                duration: overlay.duration * (overlay.confirmed ? 1.4 : 1)
                easing.type: overlay.confirmed ? Easing.OutCubic : Easing.OutBack
                easing.overshoot: 2
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: overlay.accent
            shadowOpacity: 0.85
            shadowBlur: 1
            blurMax: 48
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(overlay.accent.r, overlay.accent.g, overlay.accent.b, 0.14)
            border.width: Math.max(1.5, cross.size / 60)
            border.color: Qt.rgba(overlay.accent.r, overlay.accent.g, overlay.accent.b, 0.75)
        }

        Repeater {
            model: [45, -45]
            delegate: Rectangle {
                required property int modelData
                anchors.centerIn: parent
                width: cross.size * 0.42
                height: Math.max(3, Math.round(cross.size * 0.045))
                radius: height / 2
                color: overlay.accent
                rotation: modelData
                antialiasing: true
            }
        }
    }


    // Ghost of the app icon, following the cursor at the grab point. Turns red
    // once armed and is drawn into the cross when the task closes.
    Item {
        id: ghost

        readonly property real cx: overlay.cursor.x - overlay.geometry.x - overlay.grabOffset.x
        readonly property real cy: overlay.cursor.y - overlay.geometry.y - overlay.grabOffset.y

        width: overlay.ghostSize
        height: overlay.ghostSize
        // 0–1 on the way into the cross after a confirmed close
        property real suck: 0

        x: cx + (overlay.width / 2 - cx) * suck - width / 2
        y: cy + (overlay.height / 2 - cy) * suck - height / 2
        opacity: overlay.confirmed || !overlay.active ? 0 : 0.55 + Math.min(1, overlay.progress) * 0.3
        scale: overlay.confirmed ? 0.2 : overlay.armed ? 0.92 : 1

        NumberAnimation {
            id: suckAnimation
            target: ghost
            property: "suck"
            from: 0
            to: 1
            duration: overlay.duration * 1.4
            easing.type: Easing.InCubic
        }

        Behavior on opacity {
            NumberAnimation { duration: overlay.duration * (overlay.confirmed ? 1.4 : 1); easing.type: Easing.InCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: overlay.duration * (overlay.confirmed ? 1.4 : 1); easing.type: Easing.OutCubic }
        }

        Kirigami.Icon {
            anchors.fill: parent
            source: overlay.ghostIcon

            layer.enabled: true
            layer.effect: MultiEffect {
                colorization: overlay.armed || overlay.confirmed ? 0.65 : 0
                colorizationColor: overlay.accent
                saturation: overlay.armed ? -0.3 : 0
                shadowEnabled: true
                shadowColor: overlay.armed ? overlay.accent : "black"
                shadowOpacity: overlay.armed ? 0.8 : 0.45
                shadowBlur: 0.8
                blurMax: 32
                shadowVerticalOffset: overlay.armed ? 0 : 4
                shadowHorizontalOffset: 0

                Behavior on colorization {
                    NumberAnimation { duration: overlay.duration }
                }
            }
        }
    }
}
