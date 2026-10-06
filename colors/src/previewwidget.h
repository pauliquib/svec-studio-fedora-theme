// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include "themesettings.h"

#include <QWidget>

// A small drawn mock-up of the desktop: the top panel, an inactive window behind
// and an active one in front, so changes are visible before they are applied.
class PreviewWidget : public QWidget
{
    Q_OBJECT

public:
    explicit PreviewWidget(QWidget *parent = nullptr);

    void setSettings(const ThemeSettings &settings);

    QSize sizeHint() const override;
    QSize minimumSizeHint() const override;

protected:
    void paintEvent(QPaintEvent *event) override;

private:
    void drawWindow(QPainter &p, const QRectF &rect, bool active) const;

    ThemeSettings m_settings;
};
