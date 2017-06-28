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
varying float is_emissive;

void main() {
    color = gl_Color;
    uv = gl_MultiTexCoord0.st;
    uvLight = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;

    mat4 projection = gl_ProjectionMatrix;
    //projection[0][0] *= 0.5;  // Tried changing FOV for reflections. MC had too much frustram culling for it to be useful though :(

    gl_Position = projection * gl_ModelViewMatrix * gl_Vertex;;

    normal = normalize(gl_NormalMatrix * gl_Normal);

    is_leaf = 0;
    if(mc_Entity.x == 18    // leaves
    || mc_Entity.x == 6     // saplings
    || mc_Entity.x == 31    // grass
    || mc_Entity.x == 38    // flowers
    || mc_Entity.x == 39    // brown mushroom
    || mc_Entity.x == 40    // red mushroom
    || mc_Entity.x == 59    // wheat
    || mc_Entity.x == 83    // sugar cane
    || mc_Entity.x == 106   // vines
    || mc_Entity.x == 111   // lilly pad
    || mc_Entity.x == 115   // nether wart
    || mc_Entity.x == 141   // carrots
    || mc_Entity.x == 142   // potatoes
    || mc_Entity.x == 161   // more leaves
    || mc_Entity.x == 175   // more flowers and grasses
    || mc_Entity.x == 207   // beetroot block
    ) {
        is_leaf = 1.0;
    }

    is_emissive = 0;
    if(mc_Entity.x == 10 || mc_Entity.x == 11 || mc_Entity.x == 89) {
        is_emissive = 1.0;
    }

    tbnMatrix = calculate_tbn_matrix();

    // Calculate the view vector for POM
    view_vector = normalize(tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz);
}
