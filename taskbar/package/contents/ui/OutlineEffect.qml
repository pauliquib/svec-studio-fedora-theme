/*
 * Contrast outline: the source's silhouette dilated by `radius` px with a
 * `softness` px feathered edge, drawn under the source (shaders/outline.frag).
 * Used as layer.effect; property names match the shader uniforms.
 */
import QtQuick

ShaderEffect {
    property point texelSize: Qt.point(1 / Math.max(1, width), 1 / Math.max(1, height))
    property color outlineColor: "black"
    property real radius: 1.4
    property real softness: 1.9

    fragmentShader: Qt.resolvedUrl("../shaders/outline.frag.qsb")
}
