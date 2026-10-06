// SPDX-License-Identifier: GPL-2.0-or-later
#include "svec_colors_kcm.h"
#include "applier.h"
#include "presets.h"
#include "previewwidget.h"

#include <KColorButton>
#include <KConfig>
#include <KConfigGroup>
#include <KLocalizedString>
#include <KMessageWidget>
#include <KPluginFactory>

#include <QCheckBox>
#include <QComboBox>
#include <QDir>
#include <QFileDialog>
#include <QFileInfo>
#include <QFormLayout>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QInputDialog>
#include <QLabel>
#include <QMenu>
#include <QMessageBox>
#include <QPushButton>
#include <QScrollArea>
#include <QSignalBlocker>
#include <QSlider>
#include <QStandardPaths>
#include <QToolButton>
#include <QVBoxLayout>

namespace {

QString stateFile()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/svec-studio-colorsrc");
}

QColor desaturated(const QColor &c, qreal amount)
{
    const QColor grey = QColor::fromHsvF(0, 0, c.valueF());
    return QColor::fromRgbF(c.redF() + (grey.redF() - c.redF()) * amount,
                            c.greenF() + (grey.greenF() - c.greenF()) * amount,
                            c.blueF() + (grey.blueF() - c.blueF()) * amount);
}

QFormLayout *addGroup(QVBoxLayout *layout, const QString &title)
{
    auto *group = new QGroupBox(title);
    auto *form = new QFormLayout(group);
    form->setFieldGrowthPolicy(QFormLayout::FieldsStayAtSizeHint);
    layout->addWidget(group);
    return form;
}

QString percent(int strength)
{
    return i18nc("shadow strength in percent", "%1 %", qRound(strength * 100.0 / 255));
}

} // namespace

K_PLUGIN_CLASS_WITH_JSON(SvecColorsKcm, "kcm_svec_colors.json")

SvecColorsKcm::SvecColorsKcm(QObject *parent, const KPluginMetaData &data)
    : KCModule(qobject_cast<QWidget *>(parent), data)
{
    m_page = new QWidget(qobject_cast<QWidget *>(parent));
    auto *outer = new QVBoxLayout(m_page);
    outer->setContentsMargins(0, 0, 0, 0);

    auto *scroll = new QScrollArea(m_page);
    scroll->setFrameShape(QFrame::NoFrame);
    scroll->setWidgetResizable(true);
    outer->addWidget(scroll);
    auto *content = new QWidget(scroll);
    scroll->setWidget(content);
    auto *layout = new QVBoxLayout(content);

    // Other decorations ignore the Breeze settings, so say so instead of failing silently.
    KConfig kwinrc(QStringLiteral("kwinrc"));
    const QString decoration =
        KConfigGroup(&kwinrc, QStringLiteral("org.kde.kdecoration2")).readEntry("library", QStringLiteral("org.kde.breeze"));
    if (decoration != QLatin1String("org.kde.breeze")) {
        auto *warning = new KMessageWidget(i18n("The window decoration is not Breeze. Title bar colours still apply, "
                                                "but the border, outline and shadow settings only work with Breeze."),
                                           content);
        warning->setMessageType(KMessageWidget::Warning);
        warning->setCloseButtonVisible(false);
        layout->addWidget(warning);
    }

    // Saved themes
    auto *presetRow = new QHBoxLayout();
    presetRow->addWidget(new QLabel(i18n("Theme:"), content));
    m_presetCombo = new QComboBox(content);
    m_presetCombo->setMinimumWidth(200);
    presetRow->addWidget(m_presetCombo, 1);
    auto *saveAs = new QPushButton(QIcon::fromTheme(QStringLiteral("document-save-as")), i18n("Save As…"), content);
    m_deleteButton = new QPushButton(QIcon::fromTheme(QStringLiteral("edit-delete")), i18n("Delete"), content);
    auto *more = new QToolButton(content);
    more->setIcon(QIcon::fromTheme(QStringLiteral("application-menu")));
    more->setToolTip(i18n("Import and export"));
    more->setPopupMode(QToolButton::InstantPopup);
    auto *menu = new QMenu(more);
    menu->addAction(QIcon::fromTheme(QStringLiteral("document-import")), i18n("Import Theme…"), this, &SvecColorsKcm::importPreset);
    menu->addAction(QIcon::fromTheme(QStringLiteral("document-export")), i18n("Export Theme…"), this, &SvecColorsKcm::exportPreset);
    more->setMenu(menu);
    presetRow->addWidget(saveAs);
    presetRow->addWidget(m_deleteButton);
    presetRow->addWidget(more);
    layout->addLayout(presetRow);
    connect(m_presetCombo, &QComboBox::activated, this, &SvecColorsKcm::presetActivated);
    connect(saveAs, &QPushButton::clicked, this, &SvecColorsKcm::savePresetAs);
    connect(m_deleteButton, &QPushButton::clicked, this, &SvecColorsKcm::deletePreset);

    m_preview = new PreviewWidget(content);
    layout->addWidget(m_preview);

    // Basic: colours
    QFormLayout *form = addGroup(layout, i18n("Colours"));
    addColour(form, i18n("Accent:"), &ThemeSettings::accent);
    addColour(form, i18n("Panel:"), &ThemeSettings::panel);
    addColour(form, i18n("Title bar, active window:"), &ThemeSettings::header);

    // The inactive title bar can be derived from the active one in one click.
    auto *derive = new QToolButton(content);
    derive->setText(i18n("From Active"));
    derive->setToolTip(i18n("Derive from the active title bar"));
    derive->setPopupMode(QToolButton::InstantPopup);
    auto *deriveMenu = new QMenu(derive);
    const auto deriveWith = [this](QColor (*f)(const QColor &)) {
        m_settings.headerInactive = f(m_settings.header);
        showSettings(m_settings);
        settingsChanged();
    };
    deriveMenu->addAction(i18n("Darker"), this, [deriveWith] {
        deriveWith([](const QColor &c) {
            return c.darker(135);
        });
    });
    deriveMenu->addAction(i18n("Lighter"), this, [deriveWith] {
        deriveWith([](const QColor &c) {
            return c.lighter(125);
        });
    });
    deriveMenu->addAction(i18n("Faded"), this, [deriveWith] {
        deriveWith([](const QColor &c) {
            return desaturated(c, 0.6).darker(115);
        });
    });
    deriveMenu->addAction(i18n("Same as Active"), this, [deriveWith] {
        deriveWith([](const QColor &c) {
            return c;
        });
    });
    derive->setMenu(deriveMenu);
    addColour(form, i18n("Title bar, inactive windows:"), &ThemeSettings::headerInactive, derive);

    // Basic: borders
    form = addGroup(layout, i18n("Window Borders"));
    addChoice(form,
              i18n("Border size:"),
              {{QStringLiteral("Auto"), i18n("Theme default")},
               {QStringLiteral("None"), i18n("No borders")},
               {QStringLiteral("NoSides"), i18n("No side borders")},
               {QStringLiteral("Tiny"), i18n("Tiny")},
               {QStringLiteral("Normal"), i18n("Normal")},
               {QStringLiteral("Large"), i18n("Large")},
               {QStringLiteral("VeryLarge"), i18n("Very large")},
               {QStringLiteral("Huge"), i18n("Huge")},
               {QStringLiteral("VeryHuge"), i18n("Very huge")},
               {QStringLiteral("Oversized"), i18n("Oversized")}},
              &ThemeSettings::borderSize);
    addCheck(form, i18n("Thin outline around windows"), &ThemeSettings::outline);
    addCheck(form, i18n("Rounded corners"), &ThemeSettings::roundedCorners);
    addCheck(form, i18n("Borders on maximized windows"), &ThemeSettings::borderOnMaximized);
    auto *hint = new QLabel(i18n("Borders are drawn in the title bar colour."), content);
    hint->setEnabled(false);
    form->addRow(QString(), hint);

    // Advanced, collapsed unless the user opened it last time
    m_advancedToggle = new QToolButton(content);
    m_advancedToggle->setText(i18n("Advanced"));
    m_advancedToggle->setToolButtonStyle(Qt::ToolButtonTextBesideIcon);
    m_advancedToggle->setCheckable(true);
    m_advancedToggle->setAutoRaise(true);
    layout->addWidget(m_advancedToggle);

    m_advanced = new QWidget(content);
    auto *advancedLayout = new QVBoxLayout(m_advanced);
    advancedLayout->setContentsMargins(0, 0, 0, 0);
    layout->addWidget(m_advanced);

    form = addGroup(advancedLayout, i18n("Text and Backgrounds"));
    addColour(form, i18n("Title text, active window:"), &ThemeSettings::titleText);
    addColour(form, i18n("Title text, inactive windows:"), &ThemeSettings::titleTextInactive);
    addColour(form, i18n("Panel text:"), &ThemeSettings::panelText);
    addColour(form, i18n("Window background:"), &ThemeSettings::windowBackground);
    addColour(form, i18n("Lists and text fields:"), &ThemeSettings::viewBackground);

    form = addGroup(advancedLayout, i18n("Title Bar"));
    addChoice(form,
              i18n("Title alignment:"),
              {{QStringLiteral("AlignLeft"), i18n("Left")},
               {QStringLiteral("AlignCenter"), i18n("Centre")},
               {QStringLiteral("AlignCenterFullWidth"), i18n("Centre (full width)")},
               {QStringLiteral("AlignRight"), i18n("Right")}},
              &ThemeSettings::titleAlignment);
    addChoice(form,
              i18n("Button size:"),
              {{QStringLiteral("ButtonTiny"), i18n("Tiny")},
               {QStringLiteral("ButtonSmall"), i18n("Small")},
               {QStringLiteral("ButtonDefault"), i18n("Medium")},
               {QStringLiteral("ButtonLarge"), i18n("Large")},
               {QStringLiteral("ButtonVeryLarge"), i18n("Very large")}},
              &ThemeSettings::buttonSize);
    addCheck(form, i18n("Gradient on the title bar"), &ThemeSettings::titleGradient);
    addCheck(form, i18n("Circle around the close button"), &ThemeSettings::outlineCloseButton);

    form = addGroup(advancedLayout, i18n("Shadow"));
    addChoice(form,
              i18n("Size:"),
              {{QStringLiteral("ShadowNone"), i18n("None")},
               {QStringLiteral("ShadowSmall"), i18n("Small")},
               {QStringLiteral("ShadowMedium"), i18n("Medium")},
               {QStringLiteral("ShadowLarge"), i18n("Large")},
               {QStringLiteral("ShadowVeryLarge"), i18n("Very large")}},
              &ThemeSettings::shadowSize);
    auto *strengthRow = new QWidget(content);
    auto *strengthLayout = new QHBoxLayout(strengthRow);
    strengthLayout->setContentsMargins(0, 0, 0, 0);
    m_shadowStrength = new QSlider(Qt::Horizontal, strengthRow);
    m_shadowStrength->setRange(25, 255);
    m_shadowStrength->setMinimumWidth(180);
    m_shadowStrengthLabel = new QLabel(strengthRow);
    m_shadowStrengthLabel->setMinimumWidth(m_shadowStrengthLabel->fontMetrics().horizontalAdvance(QStringLiteral("100 %")));
    strengthLayout->addWidget(m_shadowStrength);
    strengthLayout->addWidget(m_shadowStrengthLabel);
    form->addRow(i18n("Strength:"), strengthRow);
    connect(m_shadowStrength, &QSlider::valueChanged, this, [this](int value) {
        m_settings.shadowStrength = value;
        m_shadowStrengthLabel->setText(percent(value));
        settingsChanged();
    });
    m_refreshers.append([this] {
        const QSignalBlocker blocker(m_shadowStrength);
        m_shadowStrength->setValue(m_settings.shadowStrength);
        m_shadowStrengthLabel->setText(percent(m_settings.shadowStrength));
    });
    addColour(form, i18n("Colour:"), &ThemeSettings::shadowColor);

    auto *fromSystem = new QPushButton(QIcon::fromTheme(QStringLiteral("view-refresh")), i18n("Take Values from the Current System"), m_advanced);
    fromSystem->setToolTip(i18n("Read the colours and borders the desktop is using right now, "
                                "for example after changing them on another settings page."));
    connect(fromSystem, &QPushButton::clicked, this, [this] {
        m_presetName.clear();
        showSettings(ThemeSettings::fromSystem());
        settingsChanged();
    });
    auto *fromSystemRow = new QHBoxLayout();
    fromSystemRow->addWidget(fromSystem);
    fromSystemRow->addStretch();
    advancedLayout->addLayout(fromSystemRow);

    layout->addStretch();

    const auto setExpanded = [this](bool expanded) {
        m_advanced->setVisible(expanded);
        m_advancedToggle->setArrowType(expanded ? Qt::DownArrow : Qt::RightArrow);
    };
    {
        KConfig state(stateFile());
        const bool expanded = KConfigGroup(&state, QStringLiteral("General")).readEntry("AdvancedExpanded", false);
        m_advancedToggle->setChecked(expanded);
        setExpanded(expanded);
    }
    connect(m_advancedToggle, &QToolButton::toggled, this, [setExpanded](bool expanded) {
        setExpanded(expanded);
        // A view preference, kept outside the Apply cycle.
        KConfig state(stateFile());
        KConfigGroup(&state, QStringLiteral("General")).writeEntry("AdvancedExpanded", expanded);
    });

    setButtons(Apply | Default);
}

QWidget *SvecColorsKcm::widget()
{
    return m_page;
}

KColorButton *SvecColorsKcm::addColour(QFormLayout *form, const QString &label, QColor ThemeSettings::*member, QWidget *extra)
{
    auto *button = new KColorButton(form->parentWidget());
    button->setAlphaChannelEnabled(false);
    button->setMinimumWidth(120);
    connect(button, &KColorButton::changed, this, [this, member](const QColor &colour) {
        m_settings.*member = colour;
        settingsChanged();
    });
    m_refreshers.append([this, button, member] {
        const QSignalBlocker blocker(button);
        button->setColor(m_settings.*member);
    });

    if (!extra) {
        form->addRow(label, button);
        return button;
    }
    auto *row = new QWidget(form->parentWidget());
    auto *rowLayout = new QHBoxLayout(row);
    rowLayout->setContentsMargins(0, 0, 0, 0);
    rowLayout->addWidget(button);
    rowLayout->addWidget(extra);
    form->addRow(label, row);
    return button;
}

QComboBox *SvecColorsKcm::addChoice(QFormLayout *form,
                                    const QString &label,
                                    const QList<std::pair<QString, QString>> &choices,
                                    QString ThemeSettings::*member)
{
    auto *combo = new QComboBox(form->parentWidget());
    for (const auto &[value, text] : choices) {
        combo->addItem(text, value);
    }
    connect(combo, &QComboBox::currentIndexChanged, this, [this, combo, member] {
        m_settings.*member = combo->currentData().toString();
        settingsChanged();
    });
    m_refreshers.append([this, combo, member] {
        const QSignalBlocker blocker(combo);
        combo->setCurrentIndex(qMax(0, combo->findData(m_settings.*member)));
    });
    form->addRow(label, combo);
    return combo;
}

QCheckBox *SvecColorsKcm::addCheck(QFormLayout *form, const QString &text, bool ThemeSettings::*member)
{
    auto *check = new QCheckBox(text, form->parentWidget());
    connect(check, &QCheckBox::toggled, this, [this, member](bool on) {
        m_settings.*member = on;
        settingsChanged();
    });
    m_refreshers.append([this, check, member] {
        const QSignalBlocker blocker(check);
        check->setChecked(m_settings.*member);
    });
    form->addRow(QString(), check);
    return check;
}

void SvecColorsKcm::showSettings(const ThemeSettings &settings)
{
    m_settings = settings;
    for (const auto &refresh : std::as_const(m_refreshers)) {
        refresh();
    }
    m_preview->setSettings(m_settings);
}

void SvecColorsKcm::settingsChanged()
{
    m_preview->setSettings(m_settings);
    syncPresetCombo();
    setNeedsSave(m_settings != m_applied);
}

void SvecColorsKcm::refreshPresets(const QString &select)
{
    m_presetName = select;
    {
        const QSignalBlocker blocker(m_presetCombo);
        m_presetCombo->clear();
        m_presetCombo->addItem(i18n("Custom"), QString());
        for (const QString &name : Presets::names()) {
            m_presetCombo->addItem(name, name);
        }
    }
    syncPresetCombo();
}

// Shows the theme the current settings came from, or "Custom" once they differ from it.
void SvecColorsKcm::syncPresetCombo()
{
    if (!m_presetName.isEmpty() && !(Presets::names().contains(m_presetName) && Presets::load(m_presetName) == m_settings)) {
        m_presetName.clear();
    }
    const QSignalBlocker blocker(m_presetCombo);
    m_presetCombo->setCurrentIndex(qMax(0, m_presetCombo->findData(m_presetName)));
    updatePresetButtons();
}

void SvecColorsKcm::updatePresetButtons()
{
    const bool user = !m_presetName.isEmpty() && Presets::isUserPreset(m_presetName);
    m_deleteButton->setEnabled(user);
    if (user && Presets::isBuiltin(m_presetName)) {
        m_deleteButton->setText(i18n("Restore"));
        m_deleteButton->setToolTip(i18n("Discard your changes and go back to the built-in version of this theme"));
    } else {
        m_deleteButton->setText(i18n("Delete"));
        m_deleteButton->setToolTip(m_presetName.isEmpty() || user ? QString() : i18n("Built-in themes cannot be deleted"));
    }
}

void SvecColorsKcm::presetActivated(int index)
{
    const QString name = m_presetCombo->itemData(index).toString();
    if (name.isEmpty()) {
        return;
    }
    m_presetName = name;
    showSettings(Presets::load(name));
    settingsChanged();
}

void SvecColorsKcm::savePresetAs()
{
    bool ok = false;
    const QString name = QInputDialog::getText(m_page,
                                               i18n("Save Theme"),
                                               i18n("Name of the theme:"),
                                               QLineEdit::Normal,
                                               m_presetName.isEmpty() ? i18n("My theme") : m_presetName,
                                               &ok)
                             .trimmed();
    if (!ok || name.isEmpty()) {
        return;
    }
    if (Presets::names().contains(name)
        && QMessageBox::question(m_page, i18n("Save Theme"), i18n("A theme called “%1” already exists. Replace it?", name)) != QMessageBox::Yes) {
        return;
    }
    if (!Presets::save(name, m_settings)) {
        QMessageBox::warning(m_page, i18n("Save Theme"), i18n("The theme could not be saved to %1.", Presets::userDir()));
        return;
    }
    refreshPresets(name);
}

void SvecColorsKcm::deletePreset()
{
    const QString name = m_presetName;
    if (name.isEmpty()) {
        return;
    }
    const bool builtin = Presets::isBuiltin(name);
    const QString question = builtin ? i18n("Discard your changes to “%1” and restore the built-in version?", name)
                                     : i18n("Delete the theme “%1”?", name);
    if (QMessageBox::question(m_page, i18n("Delete Theme"), question) != QMessageBox::Yes) {
        return;
    }
    Presets::remove(name);
    if (builtin) {
        // Select it before loading, otherwise the name is dropped as no longer matching.
        refreshPresets(QString());
        presetActivated(m_presetCombo->findData(name));
    } else {
        refreshPresets(QString());
    }
}

void SvecColorsKcm::importPreset()
{
    const QString path =
        QFileDialog::getOpenFileName(m_page, i18n("Import Theme"), QDir::homePath(), Presets::fileFilter());
    if (path.isEmpty()) {
        return;
    }
    const QString name = QFileInfo(path).completeBaseName();
    if (Presets::names().contains(name)
        && QMessageBox::question(m_page, i18n("Import Theme"), i18n("A theme called “%1” already exists. Replace it?", name)) != QMessageBox::Yes) {
        return;
    }
    if (!Presets::save(name, Presets::loadFile(path))) {
        QMessageBox::warning(m_page, i18n("Import Theme"), i18n("The theme could not be imported."));
        return;
    }
    refreshPresets(QString());
    presetActivated(m_presetCombo->findData(name));
}

void SvecColorsKcm::exportPreset()
{
    const QString base = m_presetName.isEmpty() ? i18n("My theme") : m_presetName;
    QString path = QFileDialog::getSaveFileName(m_page,
                                                i18n("Export Theme"),
                                                QDir::homePath() + QLatin1Char('/') + base + Presets::suffix(),
                                                Presets::fileFilter());
    if (path.isEmpty()) {
        return;
    }
    if (!path.endsWith(Presets::suffix())) {
        path += Presets::suffix();
    }
    if (!Presets::saveFile(path, m_settings)) {
        QMessageBox::warning(m_page, i18n("Export Theme"), i18n("The theme could not be written to %1.", path));
    }
}

void SvecColorsKcm::load()
{
    KConfig state(stateFile());
    ThemeSettings settings = ThemeSettings::fromSystem();
    if (state.hasGroup(QStringLiteral("Colors"))) {
        // Saved choices win; options added in later versions fall back to the system's values.
        settings.read(state);
    }
    m_applied = settings;
    showSettings(settings);
    refreshPresets(KConfigGroup(&state, QStringLiteral("General")).readEntry("Preset", QString()));
    setNeedsSave(false);
}

void SvecColorsKcm::save()
{
    KConfig state(stateFile());
    m_settings.write(state);
    KConfigGroup(&state, QStringLiteral("General")).writeEntry("Preset", m_presetName);
    state.sync();

    Applier::apply(m_settings);
    m_applied = m_settings;
    setNeedsSave(false);
}

void SvecColorsKcm::defaults()
{
    const QString breeze = QStringLiteral("Breeze Dark");
    m_presetName = Presets::names().contains(breeze) ? breeze : QString();
    showSettings(m_presetName.isEmpty() ? ThemeSettings() : Presets::load(m_presetName));
    settingsChanged();
}

#include "svec_colors_kcm.moc"
