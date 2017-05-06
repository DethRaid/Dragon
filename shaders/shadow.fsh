#version 450

#include "/lib/normalmapping.glsl"

#line 6

uniform sampler2D tex;

in vec4 color;
in vec2 uv;
in mat3 tbn_matrix;
in vec3 normal;

layout(location = 0) out vec4 frag_color;
layout(location = 1) out vec3 frag_normal;

void main() {
    frag_color = texture(tex, uv) * color;
    frag_normal = normal * 0.5 + 0.5;
}
