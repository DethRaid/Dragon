#version 450

#include "/lib/sky.glsl"

#line 6

// TODO: 0
/* DRAWBUFFERS:0 */

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;

layout(location = 0) out vec3 diffuse_out;

in vec2 coord;
in vec2 sun_coord;
in vec3 light_direction_viewspace;

void main() {
    vec3 albedo = texture(colortex4, coord).rgb;
    vec3 N = texture(colortex6, coord).xyz * 2.0 - 1.0;
    float ndotl = max(0, dot(N, light_direction_viewspace));

    vec3 light_color = texture(colortex2, sun_coord).rgb;

    diffuse_out = albedo * ndotl * light_color;
}
