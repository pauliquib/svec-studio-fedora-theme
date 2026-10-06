// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include "themesettings.h"

#include <KCModule>

#include <functional>

class KColorButton;
class PreviewWidget;
class QCheckBox;
class QComboBox;
class QFormLayout;
class QLabel;
class QPushButton;
class QSlider;
class QToolButton;
class QWidget;

// One place for the system's accent, panel and window colours and the window
// borders. The current choice is kept in ~/.config/svec-studio-colorsrc;
// named themes (presets) can be saved, imported and exported.
class SvecColorsKcm : public KCModule
{
    Q_OBJECT

public:
    SvecColorsKcm(QObject *parent, const KPluginMetaData &data);

    void load() override;
    void save() override;
    void defaults() override;
    QWidget *widget() override;

private:
    KColorButton *addColour(QFormLayout *form, const QString &label, QColor ThemeSettings::*member, QWidget *extra = nullptr);
    QComboBox *addChoice(QFormLayout *form, const QString &label, const QList<std::pair<QString, QString>> &choices, QString ThemeSettings::*member);
    QCheckBox *addCheck(QFormLayout *form, const QString &text, bool ThemeSettings::*member);

    void showSettings(const ThemeSettings &settings);
    void settingsChanged();
    void refreshPresets(const QString &select);
    void syncPresetCombo();
    void updatePresetButtons();

    void presetActivated(int index);
    void savePresetAs();
    void deletePreset();
    void importPreset();
    void exportPreset();

    QWidget *m_page = nullptr;
    PreviewWidget *m_preview = nullptr;
    QComboBox *m_presetCombo = nullptr;
    QPushButton *m_deleteButton = nullptr;
    QToolButton *m_advancedToggle = nullptr;
    QWidget *m_advanced = nullptr;
    QSlider *m_shadowStrength = nullptr;
    QLabel *m_shadowStrengthLabel = nullptr;

    // Widgets refresh from the settings through these, so adding an option is one line.
    QList<std::function<void()>> m_refreshers;

    ThemeSettings m_settings; // what the widgets show
    ThemeSettings m_applied; // what was last loaded or saved
    QString m_presetName; // preset the current settings came from, if unchanged
};
