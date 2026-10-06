cmake_minimum_required(VERSION 3.16)
project(kcm_svec_colors VERSION 0.2.0 LANGUAGES CXX)

set(QT_MIN_VERSION 6.6.0)
set(KF_MIN_VERSION 6.0.0)

find_package(ECM ${KF_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

# Install the plugin where Qt (and so System Settings) looks for it,
# e.g. /usr/lib64/qt6/plugins instead of /usr/lib64/plugins.
if(NOT DEFINED KDE_INSTALL_USE_QT_SYS_PATHS)
    set(KDE_INSTALL_USE_QT_SYS_PATHS ON CACHE BOOL "Install plugins into the Qt plugin directory")
endif()

include(FeatureSummary)
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS Core Gui Widgets DBus)
find_package(KF6 ${KF_MIN_VERSION} REQUIRED COMPONENTS
    I18n
    CoreAddons
    Config
    ConfigWidgets
    WidgetsAddons
    KCMUtils
)

add_definitions(-DTRANSLATION_DOMAIN=\"kcm_svec_colors\")

add_subdirectory(src)

install(DIRECTORY presets/ DESTINATION ${KDE_INSTALL_DATADIR}/svec-studio-colors/presets FILES_MATCHING PATTERN "*.colortheme")

feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)
