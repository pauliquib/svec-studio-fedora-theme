// SPDX-License-Identifier: GPL-2.0-or-later
#include "presets.h"
#include "themesettings.h"

#include <KConfig>
#include <KLocalizedString>

#include <QCollator>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

namespace {

const QString kPresetDir = QStringLiteral("svec-studio-colors/presets");

QStringList presetDirs()
{
    return QStandardPaths::locateAll(QStandardPaths::GenericDataLocation, kPresetDir, QStandardPaths::LocateDirectory);
}

// Earlier versions used the .svectheme suffix; rename the user's files once.
void migrateLegacyFiles()
{
    QDir dir(Presets::userDir());
    const QStringList legacy = dir.entryList({QStringLiteral("*.svectheme")}, QDir::Files);
    for (const QString &file : legacy) {
        const QString renamed = QFileInfo(file).completeBaseName() + Presets::suffix();
        if (!dir.exists(renamed)) {
            dir.rename(file, renamed);
        }
    }
}

QString fileName(const QString &name)
{
    QString safe = name;
    safe.replace(QLatin1Char('/'), QLatin1Char('-'));
    return safe + Presets::suffix();
}

} // namespace

namespace Presets
{

QString suffix()
{
    return QStringLiteral(".colortheme");
}

QString userDir()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QLatin1Char('/') + kPresetDir;
}

QString fileFilter()
{
    return i18n("Colour themes (*%1 *.svectheme)", suffix());
}

QStringList names()
{
    migrateLegacyFiles();
    QStringList result;
    for (const QString &dir : presetDirs()) {
        const QStringList files = QDir(dir).entryList({QLatin1Char('*') + suffix()}, QDir::Files);
        for (const QString &file : files) {
            const QString name = QFileInfo(file).completeBaseName();
            if (!result.contains(name)) {
                result.append(name);
            }
        }
    }
    QCollator collator;
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(result.begin(), result.end(), collator);
    return result;
}

bool isUserPreset(const QString &name)
{
    return QFile::exists(userDir() + QLatin1Char('/') + fileName(name));
}

bool isBuiltin(const QString &name)
{
    const QString user = QDir(userDir()).canonicalPath();
    for (const QString &dir : presetDirs()) {
        if (QDir(dir).canonicalPath() != user && QFile::exists(dir + QLatin1Char('/') + fileName(name))) {
            return true;
        }
    }
    return false;
}

ThemeSettings load(const QString &name)
{
    // locate() returns the user's copy first.
    return loadFile(QStandardPaths::locate(QStandardPaths::GenericDataLocation, kPresetDir + QLatin1Char('/') + fileName(name)));
}

ThemeSettings loadFile(const QString &path)
{
    ThemeSettings settings;
    if (!path.isEmpty()) {
        KConfig config(path, KConfig::SimpleConfig);
        settings.read(config);
    }
    return settings;
}

bool save(const QString &name, const ThemeSettings &settings)
{
    QDir().mkpath(userDir());
    return saveFile(userDir() + QLatin1Char('/') + fileName(name), settings);
}

bool saveFile(const QString &path, const ThemeSettings &settings)
{
    QFile::remove(path);
    KConfig config(path, KConfig::SimpleConfig);
    settings.write(config);
    return QFile::exists(path);
}

bool remove(const QString &name)
{
    return QFile::remove(userDir() + QLatin1Char('/') + fileName(name));
}

}
