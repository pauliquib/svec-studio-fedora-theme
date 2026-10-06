// SPDX-License-Identifier: GPL-2.0-or-later
#include "previewwidget.h"

#include <KLocalizedString>

#include <QPainter>
#include <QPainterPath>

namespace {

QColor mix(const QColor &a, const QColor &b, qreal amount)
{
    return QColor::fromRgbF(a.redF() + (b.redF() - a.redF()) * amount,
                            a.greenF() + (b.greenF() - a.greenF()) * amount,
                            a.blueF() + (b.blueF() - a.blueF()) * amount);
}

qreal borderWidth(const QString &size)
{
    static const QHash<QString, qreal> widths{
        {QStringLiteral("Tiny"), 2},
        {QStringLiteral("Normal"), 3},
        {QStringLiteral("Large"), 5},
        {QStringLiteral("VeryLarge"), 7},
        {QStringLiteral("Huge"), 9},
        {QStringLiteral("VeryHuge"), 11},
        {QStringLiteral("Oversized"), 14},
    };
    return widths.value(size, 0); // Auto, None, NoSides
}

qreal titleHeight(const QString &buttonSize)
{
    static const QHash<QString, qreal> heights{
        {QStringLiteral("ButtonTiny"), 18},
        {QStringLiteral("ButtonSmall"), 21},
        {QStringLiteral("ButtonLarge"), 28},
        {QStringLiteral("ButtonVeryLarge"), 32},
    };
    return heights.value(buttonSize, 24);
}

qreal shadowExtent(const QString &size)
{
    static const QHash<QString, qreal> extents{
        {QStringLiteral("ShadowNone"), 0},
        {QStringLiteral("ShadowSmall"), 5},
        {QStringLiteral("ShadowMedium"), 9},
        {QStringLiteral("ShadowVeryLarge"), 18},
    };
    return extents.value(size, 13);
}

} // namespace

PreviewWidget::PreviewWidget(QWidget *parent)
    : QWidget(parent)
{
    setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Fixed);
}

void PreviewWidget::setSettings(const ThemeSettings &settings)
{
    m_settings = settings;
    update();
}

QSize PreviewWidget::sizeHint() const
{
    return {520, 230};
}

QSize PreviewWidget::minimumSizeHint() const
{
    return {360, 230};
}

void PreviewWidget::paintEvent(QPaintEvent *)
{
    const ThemeSettings &s = m_settings;
    QPainter p(this);
    p.setRenderHint(QPainter::Antialiasing);

    const QRectF area = QRectF(rect()).adjusted(0.5, 0.5, -0.5, -0.5);
    QPainterPath clip;
    clip.addRoundedRect(area, 8, 8);
    p.setClipPath(clip);

    // Wallpaper
    QLinearGradient wallpaper(area.topLeft(), area.bottomRight());
    wallpaper.setColorAt(0, QColor(27, 42, 74));
    wallpaper.setColorAt(1, QColor(66, 33, 78));
    p.fillRect(area, wallpaper);

    // Top panel: task icons, the active one marked with the accent, and a clock.
    const QRectF panel(area.left(), area.top(), area.width(), 26);
    p.fillRect(panel, s.panel);
    for (int i = 0; i < 5; ++i) {
        const QRectF icon(panel.left() + 10 + i * 24, panel.top() + 5, 16, 16);
        QColor c = s.panelText;
        c.setAlphaF(i == 1 ? 0.9 : 0.45);
        p.setPen(Qt::NoPen);
        p.setBrush(c);
        p.drawRoundedRect(icon, 4, 4);
        if (i == 1) {
            p.fillRect(QRectF(icon.left(), panel.bottom() - 2, icon.width(), 2), s.accent);
        }
    }
    p.setPen(s.panelText);
    QFont font = this->font();
    font.setPointSizeF(font.pointSizeF() * 0.85);
    p.setFont(font);
    p.drawText(panel.adjusted(0, 0, -10, 0), Qt::AlignRight | Qt::AlignVCenter, QStringLiteral("12:34"));

    const qreal w = area.width();
    const qreal h = area.height();
    drawWindow(p, QRectF(area.left() + w * 0.06, area.top() + 44, w * 0.52, h - 66), false);
    drawWindow(p, QRectF(area.left() + w * 0.36, area.top() + 70, w * 0.58, h - 84), true);
}

void PreviewWidget::drawWindow(QPainter &p, const QRectF &rect, bool active) const
{
    const ThemeSettings &s = m_settings;
    const QColor titleBar = active ? s.header : s.headerInactive;
    const QColor titleText = active ? s.titleText : s.titleTextInactive;
    const qreal radius = s.roundedCorners ? 6 : 0;
    const qreal side = borderWidth(s.borderSize);
    const qreal bottom = s.borderSize == QLatin1String("NoSides") ? 3 : side;
    const qreal title = titleHeight(s.buttonSize);

    QPainterPath frame;
    frame.addRoundedRect(rect, radius, radius);

    // Shadow: a few widening, fading layers.
    const qreal extent = shadowExtent(s.shadowSize) * (active ? 1.0 : 0.6);
    if (extent > 0) {
        p.setPen(Qt::NoPen);
        const int layers = 6;
        for (int i = layers; i > 0; --i) {
            const qreal grow = extent * i / layers;
            QColor c = s.shadowColor;
            c.setAlphaF(0.07 * (s.shadowStrength / 255.0));
            p.setBrush(c);
            p.drawRoundedRect(rect.adjusted(-grow, -grow * 0.6, grow, grow * 1.2), radius + grow, radius + grow);
        }
    }

    // The frame (title bar and borders) is one colour; the window content sits inside it.
    if (s.titleGradient) {
        QLinearGradient gradient(rect.topLeft(), QPointF(rect.left(), rect.top() + title));
        gradient.setColorAt(0, titleBar.lighter(118));
        gradient.setColorAt(1, titleBar);
        p.fillPath(frame, titleBar);
        QPainterPath top;
        top.addRect(QRectF(rect.left(), rect.top(), rect.width(), title));
        p.fillPath(frame.intersected(top), gradient);
    } else {
        p.fillPath(frame, titleBar);
    }

    const QRectF content = rect.adjusted(side, title, -side, -bottom);
    QPainterPath body;
    const qreal bodyRadius = side > 0 || bottom > 0 ? 0 : radius;
    body.addRoundedRect(content, bodyRadius, bodyRadius);
    if (bodyRadius > 0) {
        QPainterPath square;
        square.addRect(content.adjusted(0, 0, 0, -radius));
        body = body.united(square);
    }
    p.fillPath(body, s.windowBackground);

    // Content: a list with a selected row and, in the active window, an accent button.
    const QRectF view = content.adjusted(8, 8, -8, active ? -36 : -8);
    p.fillRect(view, s.viewBackground);
    QColor line = s.titleText;
    line.setAlphaF(0.25);
    for (int row = 0; row < 4; ++row) {
        const QRectF r(view.left() + 4, view.top() + 5 + row * 16, view.width() - 8, 13);
        if (r.bottom() > view.bottom()) {
            break;
        }
        if (row == 1) {
            QColor selection = s.accent;
            selection.setAlphaF(active ? 0.85 : 0.45);
            p.fillRect(r, selection);
        }
        p.fillRect(QRectF(r.left() + 5, r.center().y() - 1.5, r.width() * (0.35 + 0.12 * row), 3), line);
    }
    if (active) {
        const QRectF button(content.right() - 78, content.bottom() - 28, 70, 20);
        p.setPen(QPen(s.accent, 1.2));
        p.setBrush(mix(s.windowBackground, s.accent, 0.15));
        p.drawRoundedRect(button, 4, 4);
    }

    // Title text
    QFont font = p.font();
    font.setBold(active);
    p.setFont(font);
    p.setPen(titleText);
    const QString caption = active ? i18n("Active window") : i18n("Inactive window");
    const QRectF titleRect(rect.left() + 10, rect.top(), rect.width() - 82, title);
    Qt::Alignment align = Qt::AlignHCenter;
    if (s.titleAlignment == QLatin1String("AlignLeft")) {
        align = Qt::AlignLeft;
    } else if (s.titleAlignment == QLatin1String("AlignRight")) {
        align = Qt::AlignRight;
    }
    p.drawText(titleRect, align | Qt::AlignVCenter, caption);

    // Buttons: minimise, maximise, close
    const qreal y = rect.top() + title / 2;
    const qreal size = qMin(title * 0.32, 6.0);
    QPen glyph(titleText, 1.4);
    p.setBrush(Qt::NoBrush);
    p.setPen(glyph);
    qreal x = rect.right() - 58;
    p.drawLine(QPointF(x - size, y - size / 2), QPointF(x, y + size / 2));
    p.drawLine(QPointF(x, y + size / 2), QPointF(x + size, y - size / 2));
    x += 20;
    p.drawLine(QPointF(x - size, y + size / 2), QPointF(x, y - size / 2));
    p.drawLine(QPointF(x, y - size / 2), QPointF(x + size, y + size / 2));
    x += 20;
    if (s.outlineCloseButton) {
        p.setPen(Qt::NoPen);
        p.setBrush(titleText);
        p.drawEllipse(QPointF(x, y), size + 3.5, size + 3.5);
        glyph.setColor(titleBar);
        p.setBrush(Qt::NoBrush);
    }
    p.setPen(glyph);
    p.drawLine(QPointF(x - size * 0.8, y - size * 0.8), QPointF(x + size * 0.8, y + size * 0.8));
    p.drawLine(QPointF(x - size * 0.8, y + size * 0.8), QPointF(x + size * 0.8, y - size * 0.8));

    // Thin outline around the whole window, slightly lighter than the frame.
    if (s.outline) {
        p.setPen(QPen(mix(titleBar, titleText, active ? 0.22 : 0.14), 1));
        p.setBrush(Qt::NoBrush);
        p.drawPath(frame);
    }
}
