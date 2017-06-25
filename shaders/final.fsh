#version 450

#define SATURATION 1.75
#define CONTRAST 1.0

const bool colortex7MipmapEnabled = true;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;

in vec2 coord;

uniform float viewWidth;
uniform float viewHeight;

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

vec3 reinhartd_tonemap(in vec3 color, in float W) {
    return color / (color + vec3(W));
}

vec3 tonemap(in vec3 color) {
    float white_level = 50;
    //return uncharted_tonemap(color / 75, white_level);
    return reinhartd_tonemap(color / white_level, 1);
}

vec3 correct_colors(in vec3 color) {
    return color * vec3(1.0, 1.0, 0.785);
}

float luma(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec3 contrast_enhance(inout vec3 color) {
    vec3 intensity = vec3(luma(color));

    vec3 satColor = mix(intensity, color, SATURATION);
    vec3 conColor = mix(vec3(0.5, 0.5, 0.5), satColor, CONTRAST);
    return conColor;
}

vec3 get_bloom() {
    vec2 half_texel = vec2(0.5) / vec2(viewWidth, viewHeight);
    vec2 bloom_coord = coord - half_texel;
    return texture(colortex7, bloom_coord, 0).rgb
         + 0.5 * texture(colortex7, bloom_coord, 2).rgb
         + 0.25 * texture(colortex7, bloom_coord, 4).rgb
         + 0.125 * texture(colortex7, bloom_coord, 6).rgb;
}

void main() {
    vec3 color = texture(colortex0, coord).rgb;
    //color = texture(colortex1, coord * 0.5 + vec2(0, 0.5)).rgb;
    color = correct_colors(color);
    color = tonemap(color);
    color = contrast_enhance(color);
    finalColor = vec4(color, 1.0);

}
