#version 450

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

in vec2 coord;

layout(location=0) out vec4 finalColor;

vec3 uncharted_tonemap_math(in vec3 color) {
    const float shoulder_strength = 0.15;
    const float linear_strength = 0.50;
    const float linear_angle = 0.10;
    const float toe_strength = 0.20;
    const float E = 0.02;
    const float F = 0.30;

    return ((color * (shoulder_strength * color + linear_angle * linear_strength) + toe_strength * E) / (color * (shoulder_strength * color + linear_strength) + toe_strength * F)) - E / F;
}

vec3 uncharted_tonemap(in vec3 color, in float W) {
    vec3 curr = uncharted_tonemap_math(color);
    vec3 white_scale = vec3(1.0) / uncharted_tonemap_math(vec3(W));

    return curr * white_scale;
}

vec3 tonemap(in vec3 color) {
    float white_level = 11.5;
    return uncharted_tonemap(color / 75, white_level);
}

vec3 correct_colors(in vec3 color) {
    return color * vec3(0.425, 0.9, 0.9);
}

void main() {
    vec3 color = texture(colortex0, coord).rgb;
    color = correct_colors(color);
    color = tonemap(color);
    finalColor = vec4(color, 1.0);
}
