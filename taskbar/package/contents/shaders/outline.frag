// Outline (dilated silhouette) with a feathered edge, drawn under the source:
// the desktop-label technique that keeps icons and text readable on any background.
// Compile with: qsb --qt6 -o outline.frag.qsb outline.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 texelSize;      // one logical pixel in texture coordinates
    vec4 outlineColor;   // straight (non-premultiplied) colour with alpha
    float radius;        // solid outline width in logical pixels
    float softness;      // feathered edge beyond the solid outline
};

layout(binding = 1) uniform sampler2D source;

void main()
{
    vec4 src = texture(source, qt_TexCoord0);

    // Dilate the alpha channel: the maximum over rings around the pixel
    float solid = 0.0;
    float feather = 0.0;
    const int steps = 16;
    for (int i = 0; i < steps; ++i) {
        float angle = 6.2831853 * float(i) / float(steps);
        vec2 dir = vec2(cos(angle), sin(angle)) * texelSize;
        solid = max(solid, texture(source, qt_TexCoord0 + dir * radius).a);
        solid = max(solid, texture(source, qt_TexCoord0 + dir * radius * 0.5).a);
        feather = max(feather, texture(source, qt_TexCoord0 + dir * (radius + softness * 0.5)).a);
        feather = max(feather, texture(source, qt_TexCoord0 + dir * (radius + softness)).a * 0.5);
    }
    float a = max(solid, feather * 0.6) * outlineColor.a;
    vec4 outline = vec4(outlineColor.rgb * a, a);

    // Source (premultiplied) over the outline
    fragColor = (src + outline * (1.0 - src.a)) * qt_Opacity;
}
