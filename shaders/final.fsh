#version 120
#extension GL_ARB_shader_texture_lod : enable

#define SATURATION 0.9
#define CONTRAST 0.9

#define OFF     0
#define ON      1

#define REFLECTION_FILTER_SIZE 2

#define FILM_GRAIN ON
#define FILM_GRAIN_STRENGTH 0.035

#define BLOOM               OFF
#define BLOOM_RADIUS        3

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
uniform sampler2D shadow;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;

uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float near;
uniform float frameTimeCounter;

varying vec2 coord;
varying float floatTime;

vec3 getColorSample(in vec2 coord) {
    return texture2D(gcolor, coord).rgb;
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
    vec2 screen_normalization = vec2(1) / vec2(viewWidth, viewHeight);
    vec3 colorAccum = vec3(0);
    vec2 max_sample = vec2(BLOOM_RADIUS, 0) * screen_normalization;
    float max_dist = sqrt(dot(max_sample, max_sample));

    for(int i = -BLOOM_RADIUS; i <= BLOOM_RADIUS; i++) {
        for(int j = -BLOOM_RADIUS; j <= BLOOM_RADIUS; j++) {
            vec2 offset = vec2(j, i) * screen_normalization;
            float weight = (max_dist - sqrt(dot(offset, offset))) / max_dist;

            colorAccum += getColorSample(coord + offset).rgb;// * weight;
        }
    }

    color += colorAccum;
    color /= pow(float(BLOOM_RADIUS * 2), 2);
}
#endif

vec3 correct_colors(in vec3 color) {
    return color * vec3(0.425, 0.9, 0.875);
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
    vec3 result = getColorSample(coord);
    for(int i = 0; i < MOTION_BLUR_SAMPLES; i++) {
        vec2 offset = blurVector * (float(i) / float(MOTION_BLUR_SAMPLES - 1) - 0.5);
        result += getColorSample(coord + offset);
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
    const float shoulder_strength = 0.15;
    const float linear_strength = 0.50;
    const float linear_angle = 0.10;
    const float toe_strength = 0.20;
    const float E = 0.02;
    const float F = 0.30;

    return ((color * (shoulder_strength * color + linear_angle * linear_strength) + toe_strength * E) / (color * (shoulder_strength * color + linear_strength) + toe_strength * F)) - E / F;
}

vec3 uncharted_tonemap(in vec3 color, in float W) {
    vec3 curr = uncharted_tonemap_math(color);
    vec3 white_scale = vec3(1.0) / uncharted_tonemap_math(vec3(W));

    return curr * white_scale;
}

vec3 doToneMapping(in vec3 color) {
    vec3 blurred_color = texture2DLod(gcolor, coord, 10).rgb;
    float luma = luma(blurred_color);
    float luma_log = max(log(luma) * 1.5, 0.5);
    luma_log = 11.5;
    return uncharted_tonemap(color / 75, luma_log);
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

    //color = texture2D(gcolor, coord).rgb;

    color = correct_colors(color);

    color = doToneMapping(color);

    contrastEnhance(color);

#if FILM_GRAIN == ON
    doFilmGrain(color);
#endif

#if VINGETTE == ON
    color -= vec3(vingetteAmt(coord));
#endif

    gl_FragColor = vec4(color, 1);
    //gl_FragColor = texture2D(gnormal, coord);
}
