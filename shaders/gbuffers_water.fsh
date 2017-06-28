#version 120

#include "/lib/wind.glsl"

#define PI 3.14159
#define WAVE_SPEED  0.000085

uniform sampler2D diffuse;
uniform sampler2D lightmap;

uniform mat4 gbufferModelView;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 pos;

varying vec3 normal;
varying mat3 normalMatrix;
varying float isWater;
varying float windSpeed;

vec3 getNoiseTexSample(in vec2 coord) {
    return texture2D(noisetex, coord).xyz;
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

vec3 getWaveNormal() {
    vec2 sampleCoord = pos.xz * (1.0 / 2048.0);
    vec3 newNormal = vec3(0.0);
    float windAmount = getWindAmount(pos);

    // Take a bunch of wave smples, fading in the smaller ones when there's more wind
    vec3 wave1 = get_wave_normal(pos, -0.2,  0.005,  vec2(1, 100),   1.0, 1.15);// * (windAmount * 5 / WIND_STRENGTH);
    vec3 wave6 = get_wave_normal(pos, 0.2,   0.0025, vec2(1, 100),   1.0, 1.75);// * (windAmount * 5 / WIND_STRENGTH);
    vec3 wave2 = get_wave_normal(pos, 0.3,   0.005,  vec2(2.5, 259), 1.9, 1.35) * min((windAmount * 2.5 / WIND_STRENGTH), 1.0);
    vec3 wave3 = get_wave_normal(pos, -0.15, 0.005,  vec2(2.3, 260), 2.1, 1.45) * min((windAmount * 1.25 / WIND_STRENGTH), 1.0);
    vec3 wave4 = get_wave_normal(pos, 0.25,  0.0025, vec2(5, 510),   4.0, 1.4) * min((windAmount * 0.75 / WIND_STRENGTH), 1.0);
    vec3 wave5 = get_wave_normal(pos, -0.23, 0.005,  vec2(1, 10),    4.2, 1.56) * min((windAmount * 0.375 / WIND_STRENGTH), 1.0);

    //newNormal.xz *= 0.01;
    newNormal = wave1 + wave6 +  wave2 + wave3 + wave4 + wave5;

    newNormal = normalize(newNormal);

    return normalMatrix * newNormal;
}

void main() {
    mat3 nMat = mat3(gbufferModelView);

    vec3 wNormal = normal;
    vec4 matColor = color * texture2D(diffuse, uv);

    if(isWater > 0.9) {
        //wNormal = getWaveNormal();
        matColor = vec4(0.0, 0.412, 0.58, 0.11);
    }

    gl_FragData[0] = matColor;
    gl_FragData[6] = vec4(1.0, 0.0, 0.0, 1.0);
    gl_FragData[7] = vec4(wNormal * 0.5 + 0.5, isWater);
    gl_FragData[5] = vec4(0, texture2D( lightmap, uvLight ).r, 0, 0.9);
}
