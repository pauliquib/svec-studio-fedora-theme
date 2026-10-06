// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

struct ThemeSettings;

namespace Applier
{
// Generates the colour scheme and Plasma style, writes the Breeze and KWin
// settings, applies everything and removes generated files that are no longer used.
void apply(const ThemeSettings &settings);
}
