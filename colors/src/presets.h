// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QString>
#include <QStringList>

struct ThemeSettings;

// Named colour themes stored as small INI files (*.colortheme). Built-in presets
// live in /usr/share/svec-studio-colors/presets, the user's own ones in
// ~/.local/share/svec-studio-colors/presets and take precedence on equal names.
namespace Presets
{
QString suffix();
// File dialog filter; also accepts files exported by earlier versions.
QString fileFilter();
QString userDir();

QStringList names();
bool isUserPreset(const QString &name);
bool isBuiltin(const QString &name);

// Starts from the defaults, so a preset only needs the keys it changes.
ThemeSettings load(const QString &name);
ThemeSettings loadFile(const QString &path);
bool save(const QString &name, const ThemeSettings &settings);
bool saveFile(const QString &path, const ThemeSettings &settings);
bool remove(const QString &name);
}
