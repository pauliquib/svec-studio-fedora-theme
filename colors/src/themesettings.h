// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QColor>
#include <QString>

class KConfig;

// Everything the module controls. The defaults are the Breeze Dark values,
// so a fresh install looks exactly like stock Plasma.
struct ThemeSettings {
    // Basic colours
    QColor accent{61, 174, 233};
    QColor panel{32, 35, 38};
    QColor header{41, 44, 48};
    QColor headerInactive{32, 35, 38};

    // Window borders (the border itself is drawn in the title bar colour)
    QString borderSize = QStringLiteral("Auto"); // kwinrc value, "Auto" = theme default
    bool outline = true;
    bool roundedCorners = true;

    // Advanced: text and backgrounds
    QColor titleText{252, 252, 252};
    QColor titleTextInactive{161, 169, 177};
    QColor panelText{252, 252, 252};
    QColor windowBackground{32, 35, 38};
    QColor viewBackground{20, 22, 24};

    // Advanced: title bar
    QString titleAlignment = QStringLiteral("AlignCenterFullWidth");
    QString buttonSize = QStringLiteral("ButtonDefault");
    bool titleGradient = false;
    bool outlineCloseButton = false;
    bool borderOnMaximized = false;

    // Advanced: shadow
    QString shadowSize = QStringLiteral("ShadowLarge");
    int shadowStrength = 255;
    QColor shadowColor{0, 0, 0};

    // Keys missing from the file keep their current value.
    void read(KConfig &config);
    void write(KConfig &config) const;

    // What the system is using right now (kdeglobals, Plasma style, breezerc, kwinrc).
    static ThemeSettings fromSystem();

    // Short hashes used in the generated file names, so that a change of colour
    // also changes the name and Plasma really re-applies it.
    QString schemeFingerprint() const;
    QString panelFingerprint() const;

    bool operator==(const ThemeSettings &other) const = default;
};
