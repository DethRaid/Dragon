#version 120

#include "lib/normalmapping.glsl"

attribute vec4 mc_Entity;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 normal;
varying mat3 tbnMatrix;
varying vec3 view_vector;

varying float is_leaf;
varying float is_lava;

void main() {
    color = gl_Color;
    uv = gl_MultiTexCoord0.st;
    uvLight = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;

    mat4 projection = gl_ProjectionMatrix;
    //projection[0][0] *= 0.5;  // Tried changing FOV for reflections. MC had too much frustram culling for it to be useful though :(

    gl_Position = projection * gl_ModelViewMatrix * gl_Vertex;;

    normal = normalize(gl_NormalMatrix * gl_Normal);

    is_leaf = 0;
    if(mc_Entity.x == 18) {
        is_leaf = 1.0;
    }

    is_lava = 0;
    if(mc_Entity.x == 10 || mc_Entity.x == 11) {
        is_lava = 1.0;
    }

    tbnMatrix = calculate_tbn_matrix();

    // Calculate the view vector for POM
    view_vector = normalize(tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz);
}
