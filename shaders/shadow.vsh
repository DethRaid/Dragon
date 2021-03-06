#version 120

#define SHADOW_MAP_BIAS 0.8

#define view_from_model gbufferModelView

attribute vec4 mc_Entity;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;

uniform float near;
uniform float far;

varying vec4 color;
varying vec2 uv;
varying vec3 normal;
varying float isTransparent;

float getIsTransparent(in float materialId) {
    if(materialId > 159.5 && materialId < 160.5) {   // stained glass pane
        return 1.0;
    }
    if(materialId == 95.0) {    // stained glass
        return 1.0;
    }
    if(materialId == 79.0) {    // ice
        return 1.0;
    }
    if(materialId == 102.0) {   // Glass pane
        return 1.0;
    }
    if(materialId == 8.0) {     // flowing water
        return 1.0;
    }
    if(materialId == 9.0) {     // water
        return 1.0;
    }
    if(materialId == 20.0) {    // glass
        return 1.0;
    }
    if(materialId == 90.0) {    // portal
        return 1.0;
    }
    return 0.0;
}

vec3 get_wave_displacement(in vec3 pos, in float steepness, in float amplitude, in vec2 direction, in float frequency, in float phase) {
    float qa = steepness * amplitude;
    float dot_factor = dot(frequency * direction, pos.xz) + phase * frameTimeCounter;
    float cos_factor = cos(dot_factor) * qa;
    float x = direction.x * cos_factor;
    float z = direction.y * cos_factor;
    float y = amplitude * sin(dot_factor);

    return vec3(x, y + amplitude, z);
}

void main() {
    gl_Position = ftransform();

    uv = gl_MultiTexCoord0.st;
    color = gl_Color;

    normal = normalize(gl_NormalMatrix * gl_Normal);

    isTransparent = getIsTransparent(mc_Entity.x);

    if(mc_Entity.x == 8.0 || mc_Entity.x == 9.0) {     // water
        vec4 position = gl_ModelViewMatrix * gl_Vertex;
        vec4 viewPos = gbufferModelViewInverse * position;
        vec3 worldPos = viewPos.xyz + cameraPosition;
        vec3 displacement = get_wave_displacement(worldPos, 0.25, 0.05, vec2(1, 0), 1, 1.5);
            displacement += get_wave_displacement(worldPos, 0.25, 0.05, vec2(0.5, 0.5), 1, 1.75);
            displacement += get_wave_displacement(worldPos, 0.25, 0.05, vec2(0.1, 0.5), 1, 1.25);
            displacement += get_wave_displacement(worldPos, 0.25, 0.05, vec2(0.5, 0.1), 1, 1.45);
        viewPos.xyz += displacement;
        viewPos.z -= 0.05;
    }
}
