#version 120
#extension GL_ARB_shader_texture_lod : enable

#define SATURATION 1.0
#define CONTRAST 0.9

#define OFF     0
#define ON      1

#define REFLECTION_FILTER_SIZE 2

#define FILM_GRAIN OFF
#define FILM_GRAIN_STRENGTH 0.03

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

float getSmoothness(in vec2 coord) {
    return texture2D(gaux2, coord).a;
}

float getDepth(vec2 coord) {
    return texture2D(gdepthtex, coord).r;
}

vec3 getCameraSpacePosition(vec2 uv) {
	float depth = getDepth(uv);
	vec4 fragposition = gbufferProjectionInverse * vec4(uv.s * 2.0 - 1.0, uv.t * 2.0 - 1.0, 2.0 * depth - 1.0, 1.0);
		 fragposition /= fragposition.w;
	return fragposition.xyz;
}

float getDepthLinear(in sampler2D depthtex, in vec2 coord) {
    return 2.0 * near * far / (far + near - (2.0 * texture2D(depthtex, coord).r - 1.0) * (far - near));
}

float getDepthLinear(vec2 coord) {
    return getDepthLinear(gdepthtex, coord);
}

vec3 get_specular_color(in vec2 coord) {
    return texture2D(gcolor, coord).rgb;
}

float getMetalness(in vec2 coord) {
    return texture2D(gaux2, coord).b;
}

vec3 getNormal(in vec2 coord) {
    return normalize(texture2D(gaux4, coord).xyz * 2.0 - 1.0);
}

bool shouldSkipLighting(in vec2 coord) {
    return texture2D(gaux2, coord).r > 0.5;
}

vec3 get_reflection(in vec2 sample_coord) {
	/*vec2 recipres = vec2(1.0f / viewWidth, 1.0f / viewHeight);
    float depth = getDepthLinear(sample_coord);
    vec3 normal = getNormal(sample_coord);
    float roughness = 1.0 - getSmoothness(coord);
    roughness = pow(roughness, 4);

	vec4 light = vec4(0.0f);
	float weights = 0.0f;

    vec2 max_pos = vec2(REFLECTION_FILTER_SIZE) * recipres * 2;
    float max_len = sqrt(dot(max_pos, max_pos));

	for(float i = -REFLECTION_FILTER_SIZE; i <= REFLECTION_FILTER_SIZE; i += 1.0f) {
		for(float j = -REFLECTION_FILTER_SIZE; j <= REFLECTION_FILTER_SIZE; j += 1.0f) {
			vec2 offset = vec2(i, j) * recipres * roughness * 2;

            float dist_factor =  max_len - sqrt(dot(offset, offset));
            dist_factor /= max_len;

			float sampleDepth = getDepthLinear(sample_coord + offset * 2.0f);
			vec3 sampleNormal = getNormal(sample_coord + offset * 2.0f);
			float weight = clamp(1.0f - abs(sampleDepth - depth) / 2.0f, 0.0f, 1.0f);
			weight *= max(0.0f, dot(sampleNormal, normal));
            weight *= mix(0, 0.05, dist_factor);

			light += max(texture2DLod(gdepth, sample_coord + offset, 1), vec4(0)) * weight;
			weights += weight;
		}
	}

	light /= max(0.00001f, weights);*/

    vec4 light = texture2D(gdepth, sample_coord);

	return light.rgb;
}

vec3 getColorSample(in vec2 coord) {
    vec3 diffuse = texture2D(composite, coord).rgb;
    vec3 specular = get_reflection(coord);

    float smoothness = getSmoothness(coord);
    float metalness = getMetalness(coord);
    vec3 viewVector = normalize(getCameraSpacePosition(coord));
    vec3 normal = getNormal(coord);

    float vdoth = clamp(dot(-viewVector, normal), 0, 1);

    vec3 sColor = mix(vec3(0.14), get_specular_color(coord), vec3(metalness));
    vec3 fresnel = sColor + (vec3(1.0) - sColor) * pow(1.0 - vdoth, 5);

    if(shouldSkipLighting(coord)) {
        fresnel = vec3(0);
    }

    return mix(diffuse, specular, fresnel * smoothness);
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
    return color * vec3(0.65, 0.95, 1.0);
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
    return uncharted_tonemap(color / 75, 1);

    //vec3 ret_color = reinhard_tonemap(color / 500, 15);
    //ret_color = pow(ret_color, vec3(1.0 / 2.2));
    //return ret_color;

    //return burgess_tonemap(color, 800);

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

    color = correct_colors(color);

    //color = texture2D(gdepth, coord).rgb;

    color = doToneMapping(color);

    contrastEnhance(color);

#if FILM_GRAIN == ON
    doFilmGrain(color);
#endif

#if VINGETTE == ON
    color -= vec3(vingetteAmt(coord));
#endif

    gl_FragColor = vec4(color, 1);
    //gl_FragColor = vec4(texture2D(shadow, coord).rgb, 1.0);
}
