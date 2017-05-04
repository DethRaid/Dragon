#version 120

#include "/lib/normalmapping.glsl"

#line 6

attribute vec4 mc_Entity;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 cameraPosition;

varying vec4 color;
varying vec2 uv;
varying mat3 tbn_matrix;
varying vec3 eye_vector;
varying float is_lava;

void main() {
    gl_Position = ftransform();
    uv = gl_MultiTexCoord0.st;
    color = gl_Color;

    tbn_matrix = calculate_tbn_matrix(gl_Normal, gl_NormalMatrix);
    eye_vector = (gbufferProjectionInverse * gl_Position).xyz;

    is_lava = 0;
    if(mc_Entity.x == 10 || mc_Entity.x == 11) {
        is_lava = 1.0;
    }
}
