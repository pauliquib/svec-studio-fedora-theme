// SPDX-License-Identifier: GPL-2.0-or-later
#include "themesettings.h"

#include <KConfig>
#include <KConfigGroup>

#include <QCryptographicHash>
#include <QFile>
#include <QStandardPaths>

namespace {

QString colourKey(const QColor &c)
{
    return QStringLiteral("%1,%2,%3").arg(c.red()).arg(c.green()).arg(c.blue());
}

QString hash(const QStringList &parts)
{
    const QByteArray data = parts.join(QLatin1Char(';')).toUtf8();
    return QString::fromLatin1(QCryptographicHash::hash(data, QCryptographicHash::Md5).toHex().left(8));
}

// Breeze stores its enums by name; anything else (an old numeric value) is ignored.
QString readName(const KConfigGroup &group, const char *key, const QString &fallback, const QString &prefix)
{
    const QString value = group.readEntry(key, fallback);
    return value.startsWith(prefix) ? value : fallback;
}

} // namespace

void ThemeSettings::read(KConfig &config)
{
    const KConfigGroup colours(&config, QStringLiteral("Colors"));
    accent = colours.readEntry("Accent", accent);
    panel = colours.readEntry("Panel", panel);
    header = colours.readEntry("Header", header);
    headerInactive = colours.readEntry("HeaderInactive", headerInactive);
    titleText = colours.readEntry("TitleText", titleText);
    titleTextInactive = colours.readEntry("TitleTextInactive", titleTextInactive);
    panelText = colours.readEntry("PanelText", panelText);
    windowBackground = colours.readEntry("WindowBackground", windowBackground);
    viewBackground = colours.readEntry("ViewBackground", viewBackground);

    const KConfigGroup deco(&config, QStringLiteral("Decoration"));
    borderSize = deco.readEntry("BorderSize", borderSize);
    outline = deco.readEntry("Outline", outline);
    roundedCorners = deco.readEntry("RoundedCorners", roundedCorners);
    titleAlignment = deco.readEntry("TitleAlignment", titleAlignment);
    buttonSize = deco.readEntry("ButtonSize", buttonSize);
    titleGradient = deco.readEntry("TitleGradient", titleGradient);
    outlineCloseButton = deco.readEntry("OutlineCloseButton", outlineCloseButton);
    borderOnMaximized = deco.readEntry("BorderOnMaximized", borderOnMaximized);
    shadowSize = deco.readEntry("ShadowSize", shadowSize);
    shadowStrength = qBound(25, deco.readEntry("ShadowStrength", shadowStrength), 255);
    shadowColor = deco.readEntry("ShadowColor", shadowColor);
}

void ThemeSettings::write(KConfig &config) const
{
    KConfigGroup colours(&config, QStringLiteral("Colors"));
    colours.writeEntry("Accent", accent);
    colours.writeEntry("Panel", panel);
    colours.writeEntry("Header", header);
    colours.writeEntry("HeaderInactive", headerInactive);
    colours.writeEntry("TitleText", titleText);
    colours.writeEntry("TitleTextInactive", titleTextInactive);
    colours.writeEntry("PanelText", panelText);
    colours.writeEntry("WindowBackground", windowBackground);
    colours.writeEntry("ViewBackground", viewBackground);

    KConfigGroup deco(&config, QStringLiteral("Decoration"));
    deco.writeEntry("BorderSize", borderSize);
    deco.writeEntry("Outline", outline);
    deco.writeEntry("RoundedCorners", roundedCorners);
    deco.writeEntry("TitleAlignment", titleAlignment);
    deco.writeEntry("ButtonSize", buttonSize);
    deco.writeEntry("TitleGradient", titleGradient);
    deco.writeEntry("OutlineCloseButton", outlineCloseButton);
    deco.writeEntry("BorderOnMaximized", borderOnMaximized);
    deco.writeEntry("ShadowSize", shadowSize);
    deco.writeEntry("ShadowStrength", shadowStrength);
    deco.writeEntry("ShadowColor", shadowColor);
    config.sync();
}

ThemeSettings ThemeSettings::fromSystem()
{
    ThemeSettings s;

    KConfig globals(QStringLiteral("kdeglobals"));
    const KConfigGroup general(&globals, QStringLiteral("General"));
    const QList<int> accent = general.readEntry("AccentColor", QList<int>{});
    if (accent.size() >= 3) {
        s.accent = QColor(accent[0], accent[1], accent[2]);
    }
    const KConfigGroup header(&globals, QStringLiteral("Colors:Header"));
    s.header = header.readEntry("BackgroundNormal", s.header);
    s.titleText = header.readEntry("ForegroundNormal", s.titleText);
    const KConfigGroup headerInactive = header.group(QStringLiteral("Inactive"));
    s.headerInactive = headerInactive.readEntry("BackgroundNormal", s.headerInactive);
    s.titleTextInactive = headerInactive.readEntry("ForegroundNormal", s.titleTextInactive);
    const KConfigGroup window(&globals, QStringLiteral("Colors:Window"));
    s.windowBackground = window.readEntry("BackgroundNormal", s.windowBackground);
    const KConfigGroup view(&globals, QStringLiteral("Colors:View"));
    s.viewBackground = view.readEntry("BackgroundNormal", s.viewBackground);

    // The panel follows the colour scheme unless the Plasma style brings its own colours.
    s.panel = s.windowBackground;
    s.panelText = window.readEntry("ForegroundNormal", s.panelText);
    KConfig plasmarc(QStringLiteral("plasmarc"));
    const QString theme = KConfigGroup(&plasmarc, QStringLiteral("Theme")).readEntry("name", QStringLiteral("default"));
    const QString themeColours =
        QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("plasma/desktoptheme/%1/colors").arg(theme));
    if (!themeColours.isEmpty()) {
        KConfig colours(themeColours, KConfig::SimpleConfig);
        const KConfigGroup themeWindow(&colours, QStringLiteral("Colors:Window"));
        s.panel = themeWindow.readEntry("BackgroundNormal", s.panel);
        s.panelText = themeWindow.readEntry("ForegroundNormal", s.panelText);
    }

    KConfig breeze(QStringLiteral("breezerc"));
    const KConfigGroup common(&breeze, QStringLiteral("Common"));
    s.outline = common.readEntry("OutlineEnabled", s.outline);
    s.roundedCorners = common.readEntry("RoundedCorners", s.roundedCorners);
    s.outlineCloseButton = common.readEntry("OutlineCloseButton", s.outlineCloseButton);
    s.shadowSize = readName(common, "ShadowSize", s.shadowSize, QStringLiteral("Shadow"));
    s.shadowStrength = qBound(25, common.readEntry("ShadowStrength", s.shadowStrength), 255);
    s.shadowColor = common.readEntry("ShadowColor", s.shadowColor);
    const KConfigGroup windeco(&breeze, QStringLiteral("Windeco"));
    s.titleAlignment = readName(windeco, "TitleAlignment", s.titleAlignment, QStringLiteral("Align"));
    s.buttonSize = readName(windeco, "ButtonSize", s.buttonSize, QStringLiteral("Button"));
    s.titleGradient = windeco.readEntry("DrawBackgroundGradient", s.titleGradient);
    s.borderOnMaximized = windeco.readEntry("DrawBorderOnMaximizedWindows", s.borderOnMaximized);

    KConfig kwinrc(QStringLiteral("kwinrc"));
    const KConfigGroup deco(&kwinrc, QStringLiteral("org.kde.kdecoration2"));
    if (!deco.readEntry("BorderSizeAuto", true)) {
        s.borderSize = deco.readEntry("BorderSize", QStringLiteral("Normal"));
    }
    return s;
}

QString ThemeSettings::schemeFingerprint() const
{
    // The accent is part of it: plasma-apply-colorscheme only re-tints with a new
    // accent when it is asked to apply a scheme that is not already active.
    return hash({colourKey(accent), colourKey(header), colourKey(headerInactive), colourKey(titleText),
                 colourKey(titleTextInactive), colourKey(windowBackground), colourKey(viewBackground)});
}

QString ThemeSettings::panelFingerprint() const
{
    return hash({colourKey(panel), colourKey(panelText)});
}
