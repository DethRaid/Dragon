#version 120

#define PI 3.14159265

attribute vec4 mc_Entity;

uniform float frameTimeCounter;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;
varying vec3 pos;

varying vec3 normal;
varying mat3 normalMatrix;
varying float isWater;

vec3 get_wave_displacement(in vec3 pos, in float steepness, in float amplitude, in vec2 direction, in float frequency, in float phase) {
    float qa = steepness * amplitude;
    float dot_factor = dot(frequency * direction, pos.xz) + phase * frameTimeCounter;
    float cos_factor = cos(dot_factor) * qa;
    float x = direction.x * cos_factor;
    float z = direction.y * cos_factor;
    float y = amplitude * sin(dot_factor);

    return vec3(x, y, z);
}

vec3 get_wave_normal(in vec3 pos, in float steepness, in float amplitude, in vec2 direction, in float frequency, in float phase) {
    float c = cos(frequency * dot(direction, pos.xz) + phase * frameTimeCounter);
    float s = cos(frequency * dot(direction, pos.xz) + phase * frameTimeCounter);
    float wa = frequency * amplitude;

    float x = direction.x * wa * c;
    float z = direction.y * wa * c;
    float y = steepness * wa * s;

    return vec3(x, y, z);
}

void main() {
    color = gl_Color;

    uv = gl_MultiTexCoord0.st;
    uvLight = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;

    vec4 position = gl_ModelViewMatrix * gl_Vertex;
    vec4 viewPos = gbufferModelViewInverse * position;
    vec3 worldPos = viewPos.xyz + cameraPosition;

    vec3 tangent = vec3( 0 );
    vec3 binormal = vec3( 0 );
    //We're working in a cube world. If one component of the normal is
    //greater than all the others, we know what direction the surface is
    //facing in
    if(gl_Normal.x > 0.5) {
        tangent = vec3(0, 0, 1);
    } else if(gl_Normal.x < -0.5) {
        tangent = vec3(0, 0, 1);
    } else if(gl_Normal.y > 0.5 ) {
        tangent = vec3(-1, 0, 0);
    } else if(gl_Normal.y < -0.5) {
        tangent = vec3(1, 0, 0);
    } else if(gl_Normal.z > 0.5) {
        tangent = vec3(1, 0, 0);
    } else if(gl_Normal.z < -0.5) {
        tangent = vec3(1, 0, 0);
    }

    binormal = cross(gl_Normal, tangent);

    normal = normalize(gl_NormalMatrix * gl_Normal);
    tangent = normalize(gl_NormalMatrix * tangent);
    binormal = normalize(gl_NormalMatrix * binormal);

    isWater = 0.0;
    if(mc_Entity.x == 8 || mc_Entity.x == 9) {
        isWater = 1.0;
        vec3 displacement = get_wave_displacement(worldPos, 0.25, 0.05, vec2(1, 0), 1, 1.5);
            displacement += get_wave_displacement(worldPos, 0.25, 0.05, vec2(0.5, 0.5), 1, 1.75);
            displacement += get_wave_displacement(worldPos, 0.25, 0.05, vec2(0.1, 0.5), 1, 1.25);
            displacement += get_wave_displacement(worldPos, 0.25, 0.05, vec2(0.5, 0.1), 1, 1.45);
        viewPos.xyz += displacement;

        normal = get_wave_normal(worldPos, 0.25, 0.05, vec2(1, 0), 1, 1.5);
        normal += get_wave_normal(worldPos, 0.25, 0.05, vec2(0.5, 0.5), 1, 1.75);
        normal += get_wave_normal(worldPos, 0.25, 0.05, vec2(0.1, 0.5), 1, 1.25);
        normal += get_wave_normal(worldPos, 0.25, 0.05, vec2(0.5, 0.1), 1, 1.45);
        normal = vec3(-normal.x, 1 - normal.y, -normal.z);
        normal = gl_NormalMatrix * normal;
    }

    gl_Position = gl_ProjectionMatrix * (gbufferModelView * viewPos);
    normalMatrix = mat3( tangent, binormal, normal );
}
