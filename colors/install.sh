#!/bin/sh
# Builds and installs Panel & Window Colours. Run it from a normal terminal: sudo asks for a password.
#   ./install.sh              build and install
#   ./install.sh --uninstall  remove the installed files
set -e

cd "$(dirname "$0")"

# Files from earlier versions: plugins in directories System Settings does not search
# and presets with the old .svectheme suffix.
OLD_PLUGINS="/usr/lib64/plugins/plasma/kcms/systemsettings/kcm_svec_colors.so
/usr/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_svec_colors.so
/usr/share/svec-studio-colors/presets/Breeze Dark.svectheme
/usr/share/svec-studio-colors/presets/Svec Studio.svectheme
/usr/share/svec-studio-colors/presets/Midnight.svectheme
/usr/share/svec-studio-colors/presets/Graphite.svectheme"

if [ "$1" = "--uninstall" ]; then
    if [ -f build/install_manifest.txt ]; then
        xargs -d '\n' sudo rm -f < build/install_manifest.txt
    fi
    echo "$OLD_PLUGINS" | xargs -d '\n' sudo rm -f
    kbuildsycoca6 >/dev/null 2>&1 || true
    echo "Uninstalled. Your generated colour scheme and Plasma style stay in ~/.local/share."
    exit 0
fi

cmake -B build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"
echo "$OLD_PLUGINS" | xargs -d '\n' sudo rm -f
sudo cmake --install build
kbuildsycoca6 >/dev/null 2>&1 || true

echo "Installed. Open System Settings -> Colours & Themes -> Panel & Window Colours."
echo "If System Settings was open, close it completely and start it again."
