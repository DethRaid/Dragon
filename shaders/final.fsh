#version 120
#extension GL_ARB_shader_texture_lod : enable

#define SATURATION 2.25
#define CONTRAST 0.75

#define OFF     0
#define ON      1

#define FILM_GRAIN ON
#define FILM_GRAIN_STRENGTH 0.045

#define BLOOM               OFF
#define BLOOM_RADIUS        2

#define VINGETTE            OFF
#define VINGETTE_MIN        0.4
#define VINGETTE_MAX        0.65
#define VINGETTE_STRENGTH   0.15


#define MOTION_BLUR         OFF
#define MOTION_BLUR_SAMPLES 16
#define MOTION_BLUR_SCALE   0.25

const bool gdepthMipmapEnabled = true;
const bool gcolorMipmapEnabled = true;

const int   RGB32F                  = 0;

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D gdepthtex;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;

uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;

varying vec2 coord;
varying float floatTime;

float getSmoothness(in vec2 coord) {
    return texture2D(gaux2, coord).a;
}

vec3 getColorSample(in vec2 coord) {
    //float roughness = 1.0 - getSmoothness(coord);
    vec3 diffuse = texture2D(composite, coord).rgb;
    //vec3 specular = texture2DLod(gaux3, coord, roughness).rgb;
    return diffuse;
}

float luma(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

//actually texel to uv. Oops.
vec2 uvToTexel(int s, int t) {
    return vec2(s / viewWidth, t / viewHeight);
}

#if BLOOM == ON
void doBloom(inout vec3 color) {
    vec3 colorAccum = vec3(0);
    float weight[5] = float[] (0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);

    for(int i = -BLOOM_RADIUS; i <= BLOOM_RADIUS; i++) {
        for(int j = -BLOOM_RADIUS; j <= BLOOM_RADIUS; j++) {
            vec2 offset = vec2(j / viewWidth, i / viewHeight);
            colorAccum += texture2D(composite, coord + offset).rgb / length(offset);
        }
    }

    //for(int i = 1; i < 4; i++) {
    //    colorAccum += texture2DLod(gcolor, coord, i).rgb;// * log2(float(i));// * 0.25;
    //}

    color += colorAccum;
}
#endif

void correctColor(inout vec3 color) {
    color *= vec3(1.2, 1.2, 1.2);
}

void contrastEnhance(inout vec3 color) {
    vec3 intensity = vec3(luma(color));

    vec3 satColor = mix(intensity, color, SATURATION);
    vec3 conColor = mix(vec3(0.5, 0.5, 0.5), satColor, CONTRAST);
    color = conColor;
}

void doFilmGrain(inout vec3 color) {
    float noise = fract(sin(dot(coord * frameTimeCounter, vec2(12.8989, 78.233))) * 43758.5453);

    color += vec3(noise) * FILM_GRAIN_STRENGTH;
    color /= 1.0 + FILM_GRAIN_STRENGTH;
}

#if VINGETTE == ON
float vingetteAmt(in vec2 coord) {
    return smoothstep(VINGETTE_MIN, VINGETTE_MAX, length(coord - vec2(0.5, 0.5))) * VINGETTE_STRENGTH;
}
#endif

#if MOTION_BLUR == ON
vec2 getBlurVector() {
    mat4 curToPreviousMat = gbufferModelViewInverse * gbufferPreviousModelView * gbufferPreviousProjection;
    float depth = texture2D(gdepthtex, coord).x;
    vec2 ndcPos = coord * 2.0 - 1.0;
    vec4 fragPos = gbufferProjectionInverse * vec4(ndcPos, depth * 2.0 - 1.0, 1.0);
    fragPos /= fragPos.w;

    vec4 previous = curToPreviousMat * fragPos;
    previous /= previous.w;
    previous.xy = previous.xy * 0.5 + 0.5;

    return previous.xy - coord;
}

vec3 doMotionBlur() {
    vec2 blurVector = getBlurVector() * MOTION_BLUR_SCALE;
    vec4 result = texture2D(gaux1, coord);
    for(int i = 0; i < MOTION_BLUR_SAMPLES; i++) {
        vec2 offset = blurVector * (float(i) / float(MOTION_BLUR_SAMPLES - 1) - 0.5);
        result += texture2D(gaux1, coord + offset);
    }
    return result.rgb / float(MOTION_BLUR_SAMPLES);
}
#endif

vec3 reinhard_tonemap(in vec3 color, in float lWhite) {
    return (color * (1 + (color / (lWhite * lWhite)))) / (1 + color);
    float lumac = luma(color);

    float lumat = (lumac * (1 + (lumac / (lWhite * lWhite)))) / (1 + lumac);
    float scale = lumat / lumac;

    return color * scale;
}

vec3 burgess_tonemap(in vec3 color, in float exposure) {
    color /= exposure;  // Hardcoded Exposure Adjustment
    vec3 x = max(vec3(0), color - 0.004);
    return (x * (6.2 * x + .5)) / (x * (6.2 * x + 1.7) + 0.06);
}

vec3 uncharted_tonemap_math(in vec3 color) {
    const float A = 0.15;
    const float B = 0.50;
    const float C = 0.10;
    const float D = 0.20;
    const float E = 0.02;
    const float F = 0.30;

    return ((color * (A * color + C * B) + D * E) / (color * (A * color + B) + D * F)) - E / F;
}

vec3 uncharted_tonemap(in vec3 color, in float exposure_bias) {
    const float W = 11.2;

    vec3 curr = uncharted_tonemap_math(color * exposure_bias);
    vec3 white_scale = vec3(1.0) / uncharted_tonemap_math(vec3(W));

    return curr * white_scale;
}

vec3 doToneMapping(in vec3 color) {
    //return uncharted_tonemap(color, 1);
    //vec3 ret_color = reinhard_tonemap(color, 10);
    //ret_color = pow(ret_color, vec3(1.0 / 2.2));
    //return ret_color;

    return burgess_tonemap(color, 15);

}

void main() {
    vec3 color = vec3(0);
#if MOTION_BLUR == ON
    color = doMotionBlur();
#else
    color = getColorSample(coord);
#endif

#if BLOOM == ON
    doBloom(color);
#endif

    //color = texture2DLod(gdepth, coord, 0).rgb;

    color = doToneMapping(color);

    //correctColor(color);
    contrastEnhance(color);

#if FILM_GRAIN == ON
    doFilmGrain(color);
#endif

#if VINGETTE == ON
    color -= vec3(vingetteAmt(coord));
#endif

    gl_FragColor = vec4(color, 1);
    //gl_FragColor = vec4(texture2D(gaux4, coord / 2).rgb, 1.0);
}
