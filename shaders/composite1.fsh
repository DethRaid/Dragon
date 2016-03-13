#version 120
#extension GL_ARB_shader_texture_lod : enable

///////////////////////////////////////////////////////////////////////////////
//                              Unchangable Variables                        //
///////////////////////////////////////////////////////////////////////////////
const int   shadowMapResolution     = 4096;
const float shadowDistance          = 120.0;
const bool  generateShadowMipmap    = false;
const float shadowIntervalSize      = 4.0;
const bool  shadowHardwareFiltering = false;
const bool  shadowtexNearest        = true;

const int   noiseTextureResolution  = 64;

const float	sunPathRotation 		= -40.0f;
const float ambientOcclusionLevel   = 0.2;

const int 	R8 						= 0;
const int 	RG8 					= 0;
const int 	RGB8 					= 1;
const int 	RGB16 					= 2;
const int   RGBA16                  = 3;
const int   RGBA8                   = 4;
const int   RGB16F                  = 5;
const int   RGB32F                  = 6;
const int 	gcolorFormat 			= RGB16;
const int 	gdepthFormat 			= RGBA8;
const int 	gnormalFormat 			= RGBA16;
const int 	compositeFormat 		= RGB16F;
const int   gaux1Format             = RGBA16;
const int   gaux2Format             = RGBA8;
const int   shadowcolor0Format      = RGB8;
const int   shadowcolor1Format      = RGBA8;

///////////////////////////////////////////////////////////////////////////////
//                              Changable Variables                          //
///////////////////////////////////////////////////////////////////////////////

#define OFF            -1
#define HARD            0
#define SOFT            1
#define REALISTIC       2

#define PCF_FIXED       0
#define PCF_VARIABLE    1

#define PI              3.14159265
#define E               2.71828183

/*
 * Make this number bigger for softer PCSS shadows. A value of 13 or 12 makes
 * shadows about like you'd see on Earth, a value of 50 or 60 is closer to what
 * you'd see if the Earth's sun was as big in the sky as Minecraft's
 */
#define LIGHT_SIZE                  3

/*
 * Defined the minimum about of shadow blur when PCSS is enabled. A value of
 * 0.175 allows for reasonably hard shadows with a very minimal amount of
 * aliasing, a value of 0.45 almost completely removes aliasing but doesn't
 * allow hard shadows when the distance from the shadow caster to the shadow
 * receiver is very small
 */
#define MIN_PENUMBRA_SIZE           0.175

/*
 * The number of samples to use for PCSS's blocker search. A higher value allows
 * for higher quality shadows at the expense of framerate
 */
#define BLOCKER_SEARCH_SAMPLES_HALF 2

/*
 * The number of samples to use for shadow blurring. More samples means blurrier
 * shadows at the expense of framerate. A value of 5 is recommended
 */
#define PCF_SIZE_HALF               2

/*
 * If set to 1, a random rotation will be applied to the shadow filter to reduce
 * shadow banding. If set to 0, no rotation will be applied to the shadow filter,
 * resulting in ugly banding but giving you a few more frames per second.
 */
#define USE_RANDOM_ROTATION         1

/*
 * How to filter the shadows. HARD produces hard shadows with no blurring. PCF
 * produces soft shadows with a constant-size blur. PCSS produces contact-hardening
 * shadows with a variable-size blur. PCSS is the most realistic option but also
 * the slowest, HARD is the fastest at the expense of realism.
 */
#define SHADOW_MODE                 REALISTIC    // [OFF, HARD, SOFT, REALISTIC]

#define SHADOW_BIAS                 0.0065

#define WATER_FOG_DENSITY           0.25
#define WATER_FOG_COLOR             (vec3(50, 100, 103) / (255.0 * 3))

#define ATMOSPHERIC_DENSITY         0.025

#define MAX_RAY_LENGTH              10
#define MAX_DEPTH_DIFFERENCE        0.6     //How much of a step between the hit pixel and anything else is allowed?
#define RAY_STEP_LENGTH             0.8
#define NUM_DIFFUSE_RAYS            4
#define RAY_DEPTH_BIAS              0.05
#define RAY_GROWTH                  1.04

#define SSAO            true
#define SSAO_SAMPLES    16               //more samples = prettier
#define SSAO_STRENGTH   3.0             //bigger number = more SSAO
#define SSAO_RADIUS     250.0
#define SSAO_MAX_DEPTH  1.0

///////////////////////////////////////////////////////////////////////////////
//                              I need these                                 //
///////////////////////////////////////////////////////////////////////////////

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D gnormal;
uniform sampler2D gaux2;
uniform sampler2D gaux4;

uniform sampler2D shadow;
uniform sampler2D watershadow;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;
uniform sampler2D shadowcolor2;

uniform vec3 cameraPosition;

uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float near;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjectionInverse;

varying vec2 coord;

varying vec3 lightVector;
varying vec3 lightColor;
varying vec3 fogColor;
varying vec3 skyColor;
varying vec3 ambientColor;

/* DRAWBUFFERS:13 */

#include "/lib/wind.glsl"
#include "/lib/sky.glsl"

struct Pixel {
    vec4 position;
    vec4 screenPosition;
    vec3 color;
    vec3 normal;
    float metalness;
    float smoothness;
    float water;
    float sky;

    bool skipLighting;

    vec3 directLighting;
    vec3 torchLighting;
} curFrag;

struct World {
    vec3 lightDirection;
    vec3 lightColor;
};

///////////////////////////////////////////////////////////////////////////////
//                              Helper Functions                             //
///////////////////////////////////////////////////////////////////////////////
//Credit to Sonic Ether for depth, normal, and positions

float getDepth( vec2 coord) {
    return texture2D(gdepthtex, coord).r;
}

float getDepthLinear(in sampler2D depthtex, in vec2 coord) {
    return 2.0 * near * far / (far + near - (2.0 * texture2D(depthtex, coord).r - 1.0) * (far - near));
}

float getDepthLinear(vec2 coord) {
    return getDepthLinear(gdepthtex, coord);
}

vec4 getScreenSpacePosition() {
	float depth = getDepth(coord);
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0 - 1.0, coord.t * 2.0 - 1.0, 2.0 * depth - 1.0, 1.0);
		 fragposition /= fragposition.w;
	return fragposition;
}

vec4 getWorldSpacePosition(in vec4 screenSpacePosition) {
    vec4 pos = gbufferModelViewInverse * screenSpacePosition;
	pos.xyz += cameraPosition.xyz;
	return pos;
}

vec4 getWorldSpacePosition() {
	vec4 pos = getScreenSpacePosition();
	return getWorldSpacePosition(pos);
}

vec3 getColor(in vec2 coord) {
    return pow(texture2DLod(gcolor, coord, 0).rgb, vec3(2.2));
}

vec3 getColor() {
    return getColor(coord);
}

float getEmission(in vec2 coord) {
    return texture2D(gaux2, coord).r;
}

bool shouldSkipLighting() {
    return getEmission(coord) > 0.5;
}

float getWater() {
    return texture2D(gnormal, coord).a;
}

float getSky() {
    return texture2D(gdepth, coord).g;
}

float getSmoothness() {
    return pow(texture2D(gaux2, coord).a, 2.2);
}

vec3 getNormal() {
    return normalize(texture2D(gnormal, coord).xyz * 2.0 - 1.0);
}

float getMetalness() {
    return texture2D(gaux2, coord).b;
}

float getSkyLighting() {
    return texture2D(gdepth, coord).r;
}

vec3 get_gi(in vec2 coord) {
    return pow(texture2DLod(gaux4, coord, 2.0).rgb, vec3(2.2));
}

vec3 getNoise(in vec2 coord) {
    return texture2D(noisetex, coord.st * vec2(viewWidth / noiseTextureResolution, viewHeight / noiseTextureResolution)).rgb;
}

///////////////////////////////////////////////////////////////////////////////
//                              Lighting Functions                           //
///////////////////////////////////////////////////////////////////////////////

//from SEUS v8
vec3 calcShadowCoordinate(in vec4 pixelPos) {
    vec4 shadowCoord = pixelPos;
    shadowCoord.xyz -= cameraPosition;
    shadowCoord = shadowModelView * shadowCoord;
    shadowCoord = shadowProjection * shadowCoord;
    shadowCoord /= shadowCoord.w;

    shadowCoord.st = shadowCoord.st * 0.5 + 0.5;    //take it from [-1, 1] to [0, 1]
    float dFrag = (1 + shadowCoord.z) * 0.5 + 0.005;

    return vec3(shadowCoord.st, dFrag);
}

//I'm sorry this is so long, OSX doesn't support GLSL 120 arrays
vec2 poisson(int i) {
    if(i == 0) {
        return vec2(0.680375, -0.211234);
    } else if(i == 1) {
        return vec2(0.566198, 0.596880);
    } else if(i == 2) {
        return vec2(0.823295, -0.604897);
    } else if(i == 3) {
        return vec2(-0.329554, 0.536459);

    } else if(i == 4) {
        return vec2(-0.444451, 0.107940);
    } else if(i == 5) {
        return vec2(-0.045206, 0.257742);
    } else if(i == 6) {
        return vec2(-0.270431, 0.026802);
    } else if(i == 7) {
        return vec2(0.904459, 0.832390);

    } else if(i == 8) {
        return vec2(0.271423, 0.434594);
    } else if(i == 9) {
        return vec2(-0.716795, 0.213938);
    } else if(i == 10) {
        return vec2(-0.967399, -0.514226);
    } else if(i == 11) {
        return vec2(-0.725537, 0.608354);

    } else if(i == 12) {
        return vec2(-0.686642, -0.198111);
    } else if(i == 13) {
        return vec2(-0.740419, -0.782382);
    } else if(i == 14) {
        return vec2(0.997849, -0.563486);
    } else if(i == 15) {
        return vec2(0.025865, 0.678224);

    } else if(i == 16) {
        return vec2(0.225280, -0.407937);
    } else if(i == 17) {
        return vec2(0.275105, 0.048574);
    } else if(i == 18) {
        return vec2(-0.012834, 0.945550);
    } else if(i == 19) {
        return vec2(-0.414966, 0.542715);

    } else if(i == 20) {
        return vec2(0.053490, 0.539828);
    } else if(i == 21) {
        return vec2(-0.199543, 0.783059);
    } else if(i == 22) {
        return vec2(-0.433371, -0.295083);
    } else if(i == 23) {
        return vec2(0.615449, 0.838053);

    } else if(i == 24) {
        return vec2(-0.860489, 0.898654);
    } else if(i == 25) {
        return vec2(0.051991, -0.827888);
    } else if(i == 26) {
        return vec2(-0.615572, 0.326454);
    } else if(i == 27) {
        return vec2(0.780465, -0.302214);

    } else if(i == 28) {
        return vec2(-0.871657, -0.959954);
    } else if(i == 29) {
        return vec2(-0.084597, -0.873808);
    } else if(i == 30) {
        return vec2(-0.523440, 0.941268);
    } else if(i == 31) {
        return vec2(0.804416, 0.701840);
    }
}

int rand(vec2 seed) {
    return int(32 * fract(sin(dot(vec2(12.9898, 72.233), seed)) * 43758.5453));
}

//Implements the Percentage-Closer Soft Shadow algorithm, as defined by nVidia
//Implemented by DethRaid - github.com/DethRaid
float calcPenumbraSize(vec3 shadowCoord) {
	float dFragment = shadowCoord.z;
	float dBlocker = 0;
	float penumbra = 0;

	float temp;
	float numBlockers = 0;
    float searchSize = LIGHT_SIZE * (dFragment - 9.5) / dFragment;

    for(int i = -BLOCKER_SEARCH_SAMPLES_HALF; i <= BLOCKER_SEARCH_SAMPLES_HALF; i++) {
        for(int j = -BLOCKER_SEARCH_SAMPLES_HALF; j <= BLOCKER_SEARCH_SAMPLES_HALF; j++) {
            temp = texture2D(shadow, shadowCoord.st + (vec2(i, j) * searchSize / (shadowMapResolution * 5 * BLOCKER_SEARCH_SAMPLES_HALF))).r;
            if(dFragment - temp > 0.0015) {
                dBlocker += temp;// * temp;
                numBlockers += 1.0;
            }
        }
	}

    if(numBlockers > 0.1) {
		dBlocker /= numBlockers;
		penumbra = (dFragment - dBlocker) * LIGHT_SIZE / dFragment;
	}

    return max(penumbra, MIN_PENUMBRA_SIZE);
}

vec3 calcShadowing(in vec4 fragPosition) {
    vec3 shadowCoord = calcShadowCoordinate(fragPosition);

    if(shadowCoord.x > 1 || shadowCoord.x < 0 ||
        shadowCoord.y > 1 || shadowCoord.y < 0) {
        return vec3(1.0);
    }

    #if SHADOW_MODE == HARD
        float shadowDepth = texture2D(shadow, shadowCoord.st).r;
        return vec3(step(shadowCoord.z - shadowDepth, SHADOW_BIAS));

    #else
        float penumbraSize = 0.5;    // whoo magic number!

        #if SHADOW_MODE == REALISTIC
            penumbraSize = calcPenumbraSize(shadowCoord.xyz);
        #endif

        float numBlockers = 0.0;
        float numSamples = 0.0;

        #if USE_RANDOM_ROTATION
            float rotateAmount = getNoise(coord).r * 2.0f - 1.0f;

            mat2 kernelRotation = mat2(
                cos(rotateAmount), -sin(rotateAmount),
                sin(rotateAmount), cos(rotateAmount)
           );
        #endif

        vec3 shadow_color = vec3(0);

    	for(int i = -PCF_SIZE_HALF; i <= PCF_SIZE_HALF; i++) {
            for(int j = -PCF_SIZE_HALF; j <= PCF_SIZE_HALF; j++) {
                vec2 sampleCoord = vec2(j, i) / (shadowMapResolution * 0.25 * PCF_SIZE_HALF);
                sampleCoord *= penumbraSize;

                #if USE_RANDOM_ROTATION
                    sampleCoord = kernelRotation * sampleCoord;
                #endif

                float shadowDepth = texture2D(shadow, shadowCoord.st + sampleCoord).r;
                float visibility = step(shadowCoord.z - shadowDepth, SHADOW_BIAS);

                float waterDepth = texture2D(watershadow, shadowCoord.st + sampleCoord).r;
                float waterVisibility = step(shadowCoord.z - waterDepth, SHADOW_BIAS);

                vec3 colorSample = texture2D(shadowcolor0, shadowCoord.st + sampleCoord).rgb;
                float transparency = texture2D(shadowcolor1, shadowCoord.st + sampleCoord).a;

                colorSample = mix(colorSample, vec3(1.0), waterVisibility);
                colorSample = mix(vec3(0.0), colorSample, visibility);

                shadow_color += colorSample;

                numSamples++;
            }
    	}

        return vec3(shadow_color / numSamples);
    #endif
}

vec3 fresnel(vec3 specularColor, float hdotl) {
    return specularColor + (vec3(1.0) - specularColor) * pow(1.0f - hdotl, 5);
}

vec3 calcDirectLighting(in Pixel pixel) {
    //data that's super important to the shading algorithm
    vec3 albedo = pixel.color;
    vec3 normal = pixel.normal;
    float specularPower = pow(10 * pixel.smoothness + 1, 2);  //yeah
    float metalness = pixel.metalness;
    vec3 specularColor = pixel.color * metalness + (1 - metalness) * vec3(0.2);
    specularColor *= pixel.smoothness;

    //Other useful value
    vec3 viewVector = normalize(cameraPosition - pixel.position.xyz);
    viewVector = (gbufferModelView * vec4(viewVector, 0)).xyz;
    vec3 halfVector = normalize(lightVector + viewVector);
    float specularNormalization = (specularPower + 2.0) / 8.0;


    float ndotl = dot(normal, lightVector);
    float ndoth = dot(normal, halfVector);
    float vdoth = dot(viewVector, halfVector);

    ndotl = max(0, ndotl);
    ndoth = max(0, ndoth);

    //calculate diffuse lighting
    vec3 lambert = albedo * ndotl;

    vec3 fresnel = fresnel(specularColor, vdoth);

    //microfacet slope distribution
    //Or, how likely is it that microfacets are oriented toward the half vector
    float d = pow(ndoth, specularPower);

    vec3 specular = fresnel * specularNormalization * d * ndotl;

    lambert = (vec3(1.0) - specular) * lambert * (1 - metalness);

    //use skyLighting as a maximum amount of direct lighting
    vec3 directLighting = (lambert + specular) * lightColor * getSkyLighting();

    #if SHADOW_QUALITY != OFF
        directLighting *= calcShadowing(pixel.position);
    #endif
    //return vec3(getSkyLighting());
    return directLighting;
}

vec2 texelToScreen(vec2 texel) {
    float newx = texel.x / viewWidth;
    float newy = texel.y / viewHeight;
    return vec2(newx, newy);
}

float calculateDitherPattern() {
    const int[64] ditherPattern = int[64] ( 1, 49, 13, 61,  4, 52, 16, 64,
                                           33, 17, 45, 29, 36, 20, 48, 32,
                                            9, 57,  5, 53, 12, 60,  8, 56,
                                           41, 25, 37, 21, 44, 28, 40, 24,
                                            3, 51, 15, 63,  2, 50, 14, 62,
                                           35, 19, 47, 31, 34, 18, 46, 30,
                                           11, 59,  7, 55, 10, 58,  6, 54,
                                           43, 27, 39, 23, 42, 26, 38, 22);

    vec2 count = vec2(0.0f);
         count.x = floor(mod(coord.s * viewWidth, 8.0f));
         count.y = floor(mod(coord.t * viewHeight, 8.0f));

    int dither = ditherPattern[int(count.x) + int(count.y) * 8];

    return float(dither) / 64.0f;
}

vec3 calcTorchLighting(in Pixel pixel) {
    if(pixel.metalness > 0.5) {
        return vec3(0);
    }

    //determine if there is a gradient in the torch lighting
    float t1 = texture2D(gaux2, coord).g - texture2D(gaux2, coord + texelToScreen(vec2(1, 0))).g - 0.1;
    float t2 = texture2D(gaux2, coord).g - texture2D(gaux2, coord + texelToScreen(vec2(0, 1))).g - 0.1;
    t1 = max(t1, 0);
    t2 - max(t2, 0);
    float t3 = max(t1, t2);
    float torchMul = step(t3, 0.1);

    float torchFac = texture2D(gaux2, coord).g;
    //vec4 bouncedTorchColor = computeRaytracedLight(getCameraSpacePosition(coord).rgb, pixel.normal);
    vec3 torchColor = vec3(1, 0.6, 0.4); // mix(bouncedTorchColor.rgb, vec3(1, 0.6, 0.4), 0.0);//bouncedTorchColor.a);
    float torchIntensity = length(torchColor * torchFac);
    torchIntensity = pow(torchIntensity, 2);
    torchColor *= torchIntensity;
    return torchColor;
}

///////////////////////////////////////////////////////////////////////////////
//                              Main Functions                               //
///////////////////////////////////////////////////////////////////////////////

Pixel fillPixelStruct() {
    Pixel pixel;
    pixel.position =        getWorldSpacePosition();
    pixel.screenPosition =  getScreenSpacePosition();
    pixel.normal =          getNormal();
    pixel.color =           getColor();
    pixel.metalness =       getMetalness();
    pixel.smoothness =      getSmoothness();
    pixel.skipLighting =    shouldSkipLighting();
    pixel.water =           getWater();
    pixel.sky =             getSky();
    pixel.directLighting =  vec3(0);
    pixel.torchLighting =   vec3(0);

    return pixel;
}

/*!
 * \brief Calculates the amount of water fog at the given location
 */
void calculateWaterFog(inout Pixel pixel) {
    float water_distance = getDepthLinear(depthtex1, coord) - getDepthLinear(gdepthtex, coord);//getDepthLinear(coord, gdepthtex) - getDepthLinear(coord, depthtex1);

    float fog_amount = water_distance * WATER_FOG_DENSITY;
    fog_amount = clamp(fog_amount, 0.0, 1.0);

    pixel.color = mix(pixel.color, WATER_FOG_COLOR, fog_amount);
}

vec4 calc_volumetric_lighting(in vec3 worldPosition) {
    // Send a ray through the atmosphere, sampling the shadow at each position

    vec3 rayStart = getWorldSpacePosition(vec4(coord, 0, 1)).xyz;
    rayStart += vec3(-0.5, 0.0, 1.5);
    vec4 rayPos = vec4(rayStart, 1.0);
    vec3 viewVector = normalize(worldPosition - cameraPosition);
    vec3 direction =  viewVector * calculateDitherPattern() * 2;
    vec3 rayColor = vec3(0);
    float distanceToPixel = length(worldPosition - cameraPosition);
    float numSteps = 0;

    rayColor = vec3(distanceToPixel);
    float num_hit = 0;

    // Calculate VL for the first 70 units
    for(int i = 0; i < 10; i++) {
        rayPos.xyz += direction;

        vec3 shadowCoord = calcShadowCoordinate(rayPos);
        //shadowCoord.st += vec2(0.5 / shadowMapResolution);

        float shadowDepth = texture2D(shadow, shadowCoord.st).r;
        float visibility = step(shadowCoord.z - shadowDepth, SHADOW_BIAS);

        float waterDepth = texture2D(watershadow, shadowCoord.st).r;
        float waterVisibility = step(shadowCoord.z - waterDepth, SHADOW_BIAS);

        vec3 colorSample = texture2D(shadowcolor0, shadowCoord.st).rgb;
        float transparency = texture2D(shadowcolor1, shadowCoord.st).a;

        colorSample = mix(colorSample, vec3(1.0), waterVisibility);
        colorSample = mix(vec3(0.0), colorSample, visibility);
        rayColor += colorSample;

        numSteps += visibility;

        if(length(rayPos.xyz - rayStart) > distanceToPixel) {
            break;
        }
    }

    return vec4(rayColor * 0.01, numSteps * ATMOSPHERIC_DENSITY * 0.1);
}

vec3 calcLitColor(in Pixel pixel) {
    vec3 ambientColorCorrected = get_gi(coord) * (1.0 - pixel.metalness);
    ambientColorCorrected *= getSkyLighting();

    //return pixel.torchLighting;

    return pixel.color * pixel.directLighting +
           pixel.color * pixel.torchLighting +
           pixel.color * ambientColorCorrected;
}

float luma(in vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

void main() {
    curFrag = fillPixelStruct();

    if(curFrag.water > 0.5) {
        calculateWaterFog(curFrag);
    }

    if(curFrag.sky > 0.5) {
        vec3 viewVector = normalize(curFrag.position.xyz - cameraPosition);
        viewVector = (gbufferModelView * vec4(viewVector, 0)).xyz;
        curFrag.color = getSkyColor(viewVector, lightVector, skyColor, cameraPosition);
    }

    vec3 finalColor = vec3(0);

    if(!curFrag.skipLighting) {
        curFrag.directLighting = calcDirectLighting(curFrag);
        curFrag.torchLighting = calcTorchLighting(curFrag);

        finalColor = calcLitColor(curFrag);
    } else {
        finalColor = curFrag.color;
    }

    vec4 skyScattering = calc_volumetric_lighting(curFrag.position.xyz);

    gl_FragData[0] = skyScattering;
    gl_FragData[1] = vec4(finalColor, 1);

}
