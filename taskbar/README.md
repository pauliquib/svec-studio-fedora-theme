# Svec Studio Taskbar for KDE Plasma 6

[![Plasma 6](https://img.shields.io/badge/KDE%20Plasma-6.x-1d99f3?logo=kde&logoColor=white)](https://kde.org/plasma-desktop/)
[![QML](https://img.shields.io/badge/QML-Qt%206-41cd52?logo=qt&logoColor=white)](https://doc.qt.io/qt-6/qtqml-index.html)
[![License: GPL v2+](https://img.shields.io/badge/license-GPL--2.0--or--later-blue)](LICENSE)

An icon-only task manager for the Plasma panel. There is no background and there are no labels,
only icons. When you hover an icon, it smoothly grows into a pill that shows the window title.
Neighbouring icons slide aside so they are never covered.

The motion is a port of the app rail in the header of [svec-elektro.cz](https://svec-elektro.cz),
moved from HTML/CSS/JS to QML.

## Features

- Icons only. The applet draws no background of its own.
- The hovered icon expands to show the **window title** or the **application name** (configurable).
- The motion is continuous across the whole rail, not a per-icon hover:
  - the closest icon wins and stays sticky while you read its label;
  - icons fade out with distance;
  - neighbours are nudged outward by half of the growth.
- Full task manager built on the same `TasksModel` as the stock Plasma one:
  - pinned launchers and window grouping;
  - filters for the current desktop, screen and activity.
- Indicator under the icon: a short line for the active window, an orange line for a window that
  demands attention, and a dot for running windows.
- **Left click** activates a window. Clicking the active window minimizes it, and clicking a group
  cycles through its windows.
- **Middle click** starts a new instance.
- **Right click** opens a menu with pin/unpin, minimize/restore, close and the applet settings.
- Respects the Plasma animation speed. With animations disabled, the change is instant.
- The motion uses real frame time, so it runs at the same speed on 60 Hz and 144 Hz screens.

## Installation

```sh
git clone https://github.com/pauliquib/svec-studio-taskbar.git
cd svec-studio-taskbar
./install.sh
```

Then add **Svec Studio Taskbar** to a panel: Edit Mode → Add Widgets. You will probably want to
remove the stock Task Manager from that panel.

To update, run `git pull && ./install.sh`. To uninstall, run `kpackagetool6 -t Plasma/Applet -r org.psvec.chiptasks`.

### Fully transparent panel

Enable **Hide the background of the panel hosting this widget** in the settings. Only the panel
that contains the widget loses its background, blur and shadow. Other panels are not affected,
and turning the option off brings the background back.

It works by setting the panel containment's `backgroundHints` to `NoBackground`. The Plasma shell
(`Panel.qml`) then skips drawing the panel frame, so no extra widget or theme is needed.

## Configuration

| Option | Default |
|---|---|
| Label on hover: window title / application name | window title |
| Maximum label width | 240 px |
| Icon size (0 = derived from panel thickness) | 0 |
| Group windows of the same application | on |
| Only windows from the current desktop / this panel's screen | on / on |
| Clicking the active window minimizes it | on |
| Highlight background on hover | on |
| Labels in the system accent colour | off |
| Reserve space for the expansion (labels never overflow the applet edge) | on |
| Hide the background of the panel hosting this widget | off |

## How the expansion works

Each icon sits in a **fixed slot**. The chip is centered on that slot and grows symmetrically, so the icon
never jumps. A single value per chip, `expand` (0–1), drives everything:

```
chip width    = slot + expand × grow        grow = measured label width + gap + end padding
label clip    = expand × labelWidth         label opacity = 0.25 + expand × 0.9
pill tint     = expand × 10 % text colour
neighbour     ± expand × grow / 2           (left ones move left, right ones move right)
```

The **target** of each chip comes from the pointer position:

1. The distance from the pointer to every slot center is measured (fixed centers, not the moving chips).
2. Up to `1.5 × slot` the chip is fully expanded. It then fades out with a smoothstep until
   `2.9 × slot`.
3. The previous winner is **sticky**. It keeps the label until another slot is closer by more than
   `0.75 × slot`. This lets you move across a long label without flicker.
4. The chip directly under the pointer, including its expanded label area, always wins.

On every frame, `expand` moves toward the target. It moves quickly when opening (rate 0.22) and more
slowly when closing (0.12), normalised to real frame time. The animation stops once everything has
settled.

The original web implementation is `bindChipMotion()` in `js/web-apps-render.js` and `.app-chip` in
`css/site.css` of svec-elektro.cz. The ratios are kept the same: slot 2.35 rem, icon 1.85 rem,
gap 0.45 rem, radii 56/110/28 px.

## Limitations

- The labels expand only in horizontal panels. Vertical panels show icons without expansion.
- No drag-and-drop reordering, window thumbnails or minimize-to-icon animation yet.

## License

GPL-2.0-or-later, see [LICENSE](LICENSE).
