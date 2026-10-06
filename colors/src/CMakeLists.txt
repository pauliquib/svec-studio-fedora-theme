# QWidget-based modules are listed by System Settings from this namespace;
# plain "systemsettings" is for QML modules only.
kcoreaddons_add_plugin(kcm_svec_colors INSTALL_NAMESPACE "plasma/kcms/systemsettings_qwidgets")

target_sources(kcm_svec_colors PRIVATE
    svec_colors_kcm.cpp
    themesettings.cpp
    applier.cpp
    presets.cpp
    previewwidget.cpp
)

target_link_libraries(kcm_svec_colors
    Qt6::Core Qt6::Gui Qt6::Widgets Qt6::DBus
    KF6::I18n KF6::CoreAddons KF6::ConfigCore KF6::ConfigGui KF6::WidgetsAddons KF6::KCMUtils
)

# Lets KRunner and the application launcher find the module.
kcmutils_generate_desktop_file(kcm_svec_colors)
