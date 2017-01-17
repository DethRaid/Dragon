#version 120
#extension GL_ARB_shader_texture_lod : enable

const bool compositeClear = false;

uniform sampler2D gdepthtex;
uniform sampler2D gdepth;
uniform sampler2D composite;

uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float near;

uniform mat4 gbufferProjectionInverse;

varying vec2 coord;

// TODO: Ensure that this is always 03
/* DRAWBUFFERS:03 */

float getDepth(vec2 coord) {
    return texture2D(gdepthtex, coord).r;
}

float getDepthLinear(in sampler2D depthtex, in vec2 coord) {
    return 2.0 * near * far / (far + near - (2.0 * texture2D(depthtex, coord).r - 1.0) * (far - near));
}

float getDepthLinear(vec2 coord) {
    return getDepthLinear(gdepthtex, coord);
}

void main() {
    // Current ray batch color
    vec3 color = texture2D(gdepth, coord).rgb;
    color = max(color, vec3(0));

    // Previous ray batches
    vec3 previousColor = texture2D(composite, coord).rgb;

    vec3 final_color = previousColor;//(color + previousColor) * 0.5;

    gl_FragData[0] = vec4(final_color, 1.0);
    gl_FragData[1] = vec4(1, 1, 1, 1.0);

}
