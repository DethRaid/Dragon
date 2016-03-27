#version 120
#extension GL_ARB_shader_texture_lod : enable

#define SATURATION 1.1
#define CONTRAST 0.8

#define FILM_GRAIN
#define FILM_GRAIN_STRENGTH 0.045

//#define BLOOM
#define BLOOM_RADIUS 9

//#define VINGETTE
#define VINGETTE_MIN        0.4
#define VINGETTE_MAX        0.65
#define VINGETTE_STRENGTH   0.15


//#define MOTION_BLUR
#define MOTION_BLUR_SAMPLES 16
#define MOTION_BLUR_SCALE   0.25

//Some defines to make my life easier
#define NORTH   0
#define SOUTH   1
#define WEST    2
#define EAST    3

const bool gdepthMipmapEnabled = true;

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

void doBloom(inout vec3 color) {
    vec3 colorAccum = vec3(0);
    int numSamples = 0;

    for(int i = 1; i < 4; i++) {
        colorAccum += texture2DLod(gaux1, coord, i).rgb;
    }

    vec2 halfTexel = vec2(0.5 / viewWidth, 0.5 / viewHeight);
    for(float i = -BLOOM_RADIUS; i <= BLOOM_RADIUS; i += 4) {
        for(float j = -BLOOM_RADIUS; j <= BLOOM_RADIUS; j += 4) {
            vec2 samplePos = coord + uvToTexel(int(j), int(i)) + halfTexel;
            vec3 sampledColor = getColorSample(samplePos).rgb;
            float emission = texture2D(gaux2, samplePos).r;
            float lumaSample = sampledColor.r;
            float bloomPow = float(abs(i) * abs(j));
            lumaSample = pow(lumaSample, bloomPow);
            colorAccum += sampledColor * (lumaSample * emission);
            numSamples++;
        }
    }
    color += colorAccum / numSamples;
}

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

#ifdef VINGETTE
float vingetteAmt(in vec2 coord) {
    return smoothstep(VINGETTE_MIN, VINGETTE_MAX, length(coord - vec2(0.5, 0.5))) * VINGETTE_STRENGTH;
}
#endif

#ifdef MOTION_BLUR
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

vec3 doToneMapping(in vec3 color) {
    //return unchartedTonemap(color);
    float lumac = luma(color);
    float lWhite = 5;

    float lumat = (lumac * (1 + (lumac / (lWhite * lWhite)))) / (1 + lumac);
    float scale = lumat / lumac;
    return color * scale;
}

void main() {
    vec3 color = vec3(0);
#ifdef MOTION_BLUR
    color = doMotionBlur();
#else
    color = getColorSample(coord);
#endif

#ifdef BLOOM
    doBloom(color);
#endif

//color = texture2DLod(gdepth, coord, 0).rgb;

color = doToneMapping(color);

//correctColor(color);
contrastEnhance(color);

#ifdef FILM_GRAIN
    doFilmGrain(color);
#endif

#ifdef VINGETTE
    color -= vec3(vingetteAmt(coord));
#endif

    gl_FragColor = vec4(color, 1);
    //gl_FragColor = vec4(, 1.0);
}
