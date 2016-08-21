#version 450 compatibility

#include "/lib/normalmapping.glsl"

#line 6

out vec4 color;
out vec2 uv;
out mat3 tbn_matrix;
out vec3 normal;

void main() {
    gl_Position = ftransform();

    uv = gl_MultiTexCoord0.st;
    color = gl_Color;

    normal = normalize(gl_NormalMatrix * gl_Normal);

    tbn_matrix = calculate_tbn_matrix(gl_Normal, gl_NormalMatrix);
}
