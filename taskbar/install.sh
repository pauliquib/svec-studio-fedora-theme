#!/bin/sh
set -e

cd "$(dirname "$0")"

kpackagetool6 -t Plasma/Applet -i package 2>/dev/null || kpackagetool6 -t Plasma/Applet -u package

echo "Installed. Add 'Svec Studio Taskbar' to a panel via Edit Mode -> Add Widgets."
echo "If it does not show up, run: systemctl --user restart plasma-plasmashell.service"
