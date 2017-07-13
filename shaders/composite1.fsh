#version 120
#extension GL_ARB_shader_texture_lod : enable

// 970 performance:
// extrems: 0 - 3
// low 50 - 65
// medium 47 - 50
// high 35 - 40
// ultra 10 - 30

///////////////////////////////////////////////////////////////////////////////
//                              Unchangable Variables                        //
///////////////////////////////////////////////////////////////////////////////
const int   shadowMapResolution     = 4096;	// [1024 2048 4096]
const int   noiseTextureResolution  = 256;

const float ambientOcclusionLevel   = 0.2;
const bool gnormalMipmapEnabled = true;

const int 	R8 						= 0;
const int   R32                     = 0;
const int 	RG8 					= 0;
const int 	RGB8 					= 1;
const int 	RGB16 					= 2;
const int   RGBA16                  = 3;
const int   RGBA8                   = 4;
const int   RGB16F                  = 5;
const int   RGB32F                  = 6;
const int   RGBA16F                 = 5;
const int 	gcolorFormat 			= RGB32F;
const int   gdepthtexFormat         = R32;
const int 	gnormalFormat 			= RGB32F;
const int 	compositeFormat 		= RGB32F;
const int   gaux1Format             = RGBA8;
const int   gaux2Format             = RGBA8;
const int   gaux3Format             = RGBA8;
const int   gaux4Format             = RGB16;
const int   shadowcolor0Format      = RGB8;
const int   shadowcolor1Format      = RGBA8;

const bool gdepthMipmapEnabled      = true;
const bool shadowMipmapEnabled      = true;

///////////////////////////////////////////////////////////////////////////////
//                              Changable Variables                          //
///////////////////////////////////////////////////////////////////////////////

#define OFF             -1
#define ON              0

#define PI              3.14159

#define WATER_FOG_DENSITY           0.95
#define WATER_FOG_COLOR             (vec3(49, 67, 53) / (255.0 * 3))

//#define VOLUMETRIC_LIGHTING

#define ATMOSPHERIC_DENSITY         0.5

#define GI_FILTER_SIZE              5
#define GI_SCALE                    1

// Lighting things
#define RAYTRACED_LIGHT
#define MAX_RAY_LENGTH          16.0	// [8.0 10.0 12.0 16.0 32.0]
#define MIN_DEPTH_DIFFERENCE    1.25
#define RAY_STEP_LENGTH         0.25
#define RAY_DEPTH_BIAS          0.05
#define RAY_GROWTH              1.05
#define NUM_DIFFUSE_RAYS        4		// [1 2 4 8 16 32]

#define SHADOW_BIAS                 0.00525

#define LIGHT_SIZE                  25
#define MIN_PENUMBRA_SIZE           0.0
#define BLOCKER_SEARCH_SAMPLES_HALF 3   // [1 2 3 4 5]
#define PCF_SIZE_HALF               3   // [1 2 3 4 5]
#define USE_RANDOM_ROTATION

/*
 * How to filter the shadows. HARD produces hard shadows with no blurring. PCF
 * produces soft shadows with a constant-size blur. PCSS produces contact-hardening
 * shadows with a variable-size blur. PCSS is the most realistic option but also
 * the slowest, HARD is the fastest at the expense of realism.
 */

//#define HARD_SHADOWS
//#define SOFT_SHADOWS
#define REALISTIC_SHADOWS
//#define HYBRID_RAYTRACED_SHADOWS
#define HRS_RAY_LENGTH              0.8
#define HRS_RAY_STEPS               100
#define HRS_BIAS                    0.02
#define HRS_DEPTH_CORRECTION        0.01


///////////////////////////////////////////////////////////////////////////////
//                              I need these                                 //
///////////////////////////////////////////////////////////////////////////////

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D gnormal;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;

uniform sampler2D shadow;
uniform sampler2D shadowtex1;
uniform sampler2D watershadow;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

uniform sampler2D noisetex;

uniform vec3 cameraPosition;

uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float near;
uniform float frameTimeCounter;

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

varying vec2 gi_lookup_coord[GI_FILTER_SIZE * GI_FILTER_SIZE];

// TODO: 342
/* DRAWBUFFERS:342 */

struct Pixel {
    vec4 position;
    vec3 color;
    vec3 normal;
    float metalness;
    float smoothness;
    float water;
    float sky;

    bool skipLighting;
    bool is_leaf;

    vec3 directLighting;
    vec3 shadow;
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

float getDepth(vec2 coord) {
    return texture2DLod(gdepthtex, coord, 0).r;
}

float getDepthLinear(sampler2D depthtex, vec2 coord) {
    return 2.0 * near * far / (far + near - (2.0 * texture2D(depthtex, coord).r - 1.0) * (far - near));
}

float getDepthLinear(vec2 coord) {
    return getDepthLinear(gdepthtex, coord);
}

vec4 get_viewspace_position(in vec2 coord) {
float depth = getDepth(coord);
	vec4 fragposition = gbufferProjectionInverse * vec4(coord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
		 fragposition /= fragposition.w;
	return fragposition;
}

vec4 get_viewspace_position() {
    return get_viewspace_position(coord);
}

vec4 getWorldSpacePosition(in vec4 screenSpacePosition) {
    vec4 pos = gbufferModelViewInverse * screenSpacePosition;
	pos.xyz += cameraPosition.xyz;
	return pos;
}

vec4 getWorldSpacePosition() {
	vec4 pos = get_viewspace_position();
	return getWorldSpacePosition(pos);
}

vec4 worldspace_to_viewspace(in vec4 position_worldspace) {
	vec4 pos = gbufferModelView * position_worldspace;
	return pos;
}

vec4 viewspace_to_worldspace(in vec4 position_viewspace) {
	vec4 pos = gbufferModelViewInverse * position_viewspace;
	return pos;
}

vec4 worldspace_to_shadowspace(in vec4 position_worldspace) {
	vec4 pos = shadowProjection * shadowModelView * position_worldspace;
	return pos /= pos.w;
}

vec3 calcShadowCoordinate(in vec4 pixelPos) {
    pixelPos.xyz -= cameraPosition;
    vec4 shadowCoord = worldspace_to_shadowspace(pixelPos);

    shadowCoord.st = shadowCoord.st * 0.5 + 0.5;    //take it from [-1, 1] to [0, 1]
    float dFrag = shadowCoord.z * 0.5 + 0.505;

    return vec3(shadowCoord.st, dFrag);
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
    return texture2D(gaux3, coord).a;
}

float getSky() {
    return texture2D(gaux3, coord).g;
}

float getSmoothness() {
    return pow(texture2D(gaux2, coord).a, 2.2);
}

vec3 getNormal(in vec2 coord) {
    return normalize(texture2D(gaux4, coord).xyz * 2.0 - 1.0);
}

vec3 getNormal() {
    return getNormal(coord);
}

float getMetalness() {
    return texture2D(gaux2, coord).b;
}

float getSkyLighting() {
    return texture2D(gaux3, coord).r;
}

bool getIsLeaf() {
    return texture2D(gaux3, coord).b > 0.5;
}

vec3 getNoise(in vec2 coord) {
    return texture2D(noisetex, coord.st * vec2(viewWidth / noiseTextureResolution, viewHeight / noiseTextureResolution)).rgb;
}

vec3 get_3d_noise(in vec2 coord) {
    coord *= vec2(viewWidth, viewHeight);
    coord /= noiseTextureResolution;

    return texture2D(noisetex, coord).xyz * 2.0 - 1.0;
}

vec2 get_sky_coord(in vec3 direction) {
    float lon = atan(direction.z, direction.x);
    if(direction.z < 0) {
        lon = 2 * PI - atan(-direction.z, direction.x);
    }

    float lat = acos(direction.y);

    const vec2 rads = vec2(1.0 / (PI * 2.0), 1.0 / PI);
    vec2 sphereCoords = vec2(lon, lat) * rads;
    sphereCoords.y = 1.0 - sphereCoords.y;

    return sphereCoords;
}

vec3 bilateral_upsample(in vec2 sample_coord, in sampler2D texture) {
	vec2 recipres = vec2(1.0f / viewWidth, 1.0f / viewHeight);
    float depth = getDepthLinear(sample_coord);
    vec3 normal = getNormal(sample_coord);

	vec4 light = vec4(0.0f);
	float weights = 0.0f;

    for(int i = 0; i < GI_FILTER_SIZE * GI_FILTER_SIZE; i++) {
        vec2 gi_coord = gi_lookup_coord[i];
        float sampleDepth = getDepthLinear(gi_coord);
        vec3 sampleNormal = getNormal(gi_coord);
        float weight = clamp(1.0f - abs(sampleDepth - depth) / 2.0f, 0.0f, 1.0f);
        weight *= max(0.0f, dot(sampleNormal, normal) * 2.0f - 1.0f);

        light += texture2DLod(texture, gi_coord, 1) * weight;
        weights += weight;
    }

	light /= max(0.00001f, weights);
    weights = 0;

	if (weights < 0.01f) {
		light = texture2DLod(texture, sample_coord * (1.0f / exp2(GI_SCALE)), 2);
	}

	return light.rgb;
}

/*
 * \brief Performs a bilaterial filter on the GI texture
 */
vec3 get_gi(in vec2 sample_coord) {
	return bilateral_upsample(sample_coord, gnormal);
}

///////////////////////////////////////////////////////////////////////////////
//                              Lighting Functions                           //
///////////////////////////////////////////////////////////////////////////////

vec3 fresnel(vec3 specularColor, float hdotl) {
    return specularColor + (vec3(1.0) - specularColor) * pow(1.0f - hdotl, 5);
}

/*!
 * \brief Calculates the lighting from the sky cubemap in the given direction. Considers both specular and diffuse terms
 *
 * \param direction The normalized direction to get the lighting from. Should be in world space
 * \param specular_color The fragment's specular color
 * \param normal The normalized world-space normal vector
 * \param eye_vector The normalized world-space eye vector
 * \param specular_power The specular power, unpacked from the roughness
 */
vec3 calc_lighting_from_direction(in vec3 direction, in vec3 normal, in float metalness, in float lod) {
    // Get the diffuse component blurred so we get lighting from a large part of the cubemap. This isn't super accurate but it should be good enough for Minecraft
    vec2 sun_coord = get_sky_coord(direction);
    vec3 sky_light_diffuse = texture2D(gdepth, sun_coord, lod).rgb;
    //normal = normal.yzx;

    // Calculate diffuse light from sky
    float ndotl = dot(normal, direction);
    ndotl = clamp(ndotl, 0., 1.);

    vec3 sky_lambert = ndotl * sky_light_diffuse;

    return sky_lambert;
}

/*
 * Shadowing code
 */

//Implements the Percentage-Closer Soft Shadow algorithm, as defined by nVidia
//Implemented by DethRaid - github.com/DethRaid
float calcPenumbraSize(vec3 shadowCoord) {
	float dFragment = shadowCoord.z;
	float dBlocker = 0;
	float penumbra = 0;

	float temp;
	float numBlockers = 0;
    float searchSize = LIGHT_SIZE * (dFragment - 1) / dFragment;

    for(int i = -BLOCKER_SEARCH_SAMPLES_HALF; i <= BLOCKER_SEARCH_SAMPLES_HALF; i++) {
        for(int j = -BLOCKER_SEARCH_SAMPLES_HALF; j <= BLOCKER_SEARCH_SAMPLES_HALF; j++) {
            vec2 sample_coord = shadowCoord.st + (vec2(i, j) * searchSize / (shadowMapResolution * 5 * BLOCKER_SEARCH_SAMPLES_HALF));
            temp = texture2DLod(shadowtex1, sample_coord, 2).r;
            if(dFragment - temp > 0.0015) {
                dBlocker += temp;
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

#ifdef SOFT_SHADOWS
#endif

vec3 calc_shadowing(in vec4 fragPosition, in float slope_shadow_bias) {
    vec3 shadowCoord = calcShadowCoordinate(fragPosition);

    if(shadowCoord.x > 1 || shadowCoord.x < 0 ||
        shadowCoord.y > 1 || shadowCoord.y < 0) {
        return vec3(1.0);
    }

    #ifdef HARD_SHADOWS
        float shadowDepth = texture2D(shadowtex1, shadowCoord.st).r;
        return vec3(step(shadowCoord.z - shadowDepth, SHADOW_BIAS + slope_shadow_bias));

    #else
        float penumbraSize = 0.5;    // whoo magic number!

        #ifdef REALISTIC_SHADOWS
            penumbraSize = calcPenumbraSize(shadowCoord.xyz);
        #endif

        float numBlockers = 0.0;
        float numSamples = 0.0;

        #ifdef USE_RANDOM_ROTATION
            float rotateAmount = get_3d_noise(coord).r * 2.0f - 1.0f;

            mat2 kernelRotation = mat2(
                cos(rotateAmount), -sin(rotateAmount),
                sin(rotateAmount), cos(rotateAmount)
           );
        #endif

        vec3 shadow_color = vec3(0);

    	for(int i = -PCF_SIZE_HALF; i <= PCF_SIZE_HALF; i++) {
            for(int j = -PCF_SIZE_HALF; j <= PCF_SIZE_HALF; j++) {
                vec2 sampleCoord = vec2(j, i) / (shadowMapResolution * 2 *  PCF_SIZE_HALF);
                sampleCoord *= penumbraSize;

                #ifdef USE_RANDOM_ROTATION
                    sampleCoord = kernelRotation * sampleCoord;
                #endif

                float shadowDepth = texture2DLod(shadowtex1, shadowCoord.st + sampleCoord, 0).r;
                float visibility = step(shadowCoord.z - shadowDepth, SHADOW_BIAS);

                float waterDepth = texture2DLod(watershadow, shadowCoord.st + sampleCoord, 0).r;
                float waterVisibility = step(shadowCoord.z - waterDepth, SHADOW_BIAS);

                vec3 colorSample = texture2D(shadowcolor0, shadowCoord.st + sampleCoord).rgb;

                colorSample = mix(colorSample, vec3(1.0), waterVisibility);
                colorSample = mix(vec3(0.0), colorSample, visibility);

                shadow_color += colorSample;

                numSamples++;
            }
    	}

        shadow_color /= numSamples;

        return shadow_color;
    #endif
}

/*
 * \brief
 */
vec3 calcDirectLighting(inout Pixel pixel) {
    vec3 viewVector = normalize(cameraPosition - pixel.position.xyz);
    float specularPower = pow(10 * pixel.smoothness + 1, 2);  //yeah
    vec3 specularColor = pixel.color * pixel.metalness + (1 - pixel.metalness) * vec3(0.2);
    specularColor *= pixel.smoothness;

    vec3 light_vector_worldspace = viewspace_to_worldspace(vec4(lightVector, 0)).xyz;

    // Calculate the main light lighting from the light position and whatnot
    // Leaves and flowers and whatnot are lit consistently and are noly darkened by the shadow
    vec3 sun_lighting = vec3(clamp(dot(light_vector_worldspace, vec3(0, 1, 0)), 0, 1));
    vec3 sky_specular = vec3(0);
    if(!pixel.is_leaf) {
        sun_lighting = calc_lighting_from_direction(light_vector_worldspace, pixel.normal, pixel.metalness, 3) * 0.5;
    } else {
        sun_lighting = calc_lighting_from_direction(light_vector_worldspace, vec3(0, 1, 0), pixel.metalness, 3) * 0.5;
    }

    // Calculate specular light from the sky
    // Get the specular component blurred by the pixel's roughness
    vec3 specular_direction = reflect(viewVector, pixel.normal);
    specular_direction *= -1;

    vec3 half_vector = normalize(specular_direction + viewVector);
    float vdoth = dot(viewVector, half_vector);
    vdoth = max(0, vdoth);
    vec3 fresnel_color = fresnel(specularColor, vdoth);

    float specular_normalization = specularPower * 0.125 + 0.25;
    sky_specular = fresnel_color * pixel.smoothness;


    float slope_shadow_bias = clamp(dot(pixel.normal, light_vector_worldspace), 0, 1) * 0.5;
    pixel.shadow = calc_shadowing(pixel.position, slope_shadow_bias);
    sun_lighting *= pixel.shadow;

    // Mix the specular and diffuse light together
    sun_lighting = (vec3(1.0) - sky_specular) * sun_lighting * (1.0 - pixel.metalness);

    return sun_lighting * 0.025;
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

#ifdef RAYTRACED_LIGHT
vec2 get_coord_from_viewspace(in vec4 position) {
    vec4 ndc_position = gbufferProjection * position;
    ndc_position /= ndc_position.w;
    return ndc_position.xy * 0.5 + 0.5;
}

vec3 cast_screenspace_ray(in vec3 origin, in vec3 direction) {
    vec3 curPos = origin;
    vec2 curCoord = get_coord_from_viewspace(vec4(curPos, 1));
    direction = normalize(direction) * RAY_STEP_LENGTH;
    #ifdef DITHER_REFLECTION_RAYS
        direction *= calculateDitherPattern();
    #endif
    bool forward = true;
    bool can_collect = true;

    //The basic idea here is the the ray goes forward until it's behind something,
    //then slowly moves forward until it's in front of something.
    for(int i = 0; i < MAX_RAY_LENGTH / RAY_STEP_LENGTH; i++) {
        curPos += direction;
        curCoord = get_coord_from_viewspace(vec4(curPos, 1));
        if(curCoord.x < 0 || curCoord.x > 1 || curCoord.y < 0 || curCoord.y > 1) {
            //If we're here, the ray has gone off-screen so we can't reflect anything
            return vec3(-1);
        }
        if(length(curPos - origin) > MAX_RAY_LENGTH) {
            return vec3(-1);
        }
        float worldDepth = get_viewspace_position(curCoord).z;
        float rayDepth = curPos.z;
        float depthDiff = (worldDepth - rayDepth);
        float maxDepthDiff = max(sqrt(dot(direction, direction)) + RAY_DEPTH_BIAS, MIN_DEPTH_DIFFERENCE);
        if(depthDiff > 0 && depthDiff < maxDepthDiff) {
            vec3 travelled = origin - curPos;
            return vec3(curCoord, sqrt(dot(travelled, travelled)));
        }
        direction *= RAY_GROWTH;
    }
    //If we're here, we couldn't find anything to reflect within the alloted number of steps
    return vec3(-1);
}

vec4 raytrace_light(in vec2 coord) {
	vec3 light = vec3(0);
    float hit_emissive = 0;
	for(int i = 0; i < NUM_DIFFUSE_RAYS; i++) {
	    vec3 position_viewspace = get_viewspace_position(coord).xyz;
		vec3 normal = getNormal(coord);
		vec3 noise = get_3d_noise(coord * i * frameTimeCounter);
		vec3 ray_direction = normalize(noise * 0.35 + normal);
		vec3 hit_uv = cast_screenspace_ray(position_viewspace, ray_direction);

		float emission = getEmission(hit_uv.st);
        if(emission > 0.1 && hit_uv.z > 0) {
		    float ndotl = max(0, dot(normal, ray_direction));
		    float falloff = max(1, pow(hit_uv.z, 2));
		    light += texture2D(gcolor, hit_uv.st).rgb * emission * ndotl / falloff;
        }
        hit_emissive += emission;
	}

	return vec4(light / float(NUM_DIFFUSE_RAYS), min(hit_emissive, 1.f));
}
#endif

vec3 calcTorchLighting(in Pixel pixel) {
    if(pixel.metalness > 0.5) {
        return vec3(0);
    }

    vec4 raytrace_result = vec4(0);
    #ifdef RAYTRACED_LIGHT
    raytrace_result = raytrace_light(coord);
    #endif

    float torchFac = texture2D(gaux2, coord).g;
    vec3 torchColor = vec3(1, 0.4, 0.4);
    float torchIntensity = length(torchColor) * torchFac;
    //torchIntensity = pow(torchIntensity, 2);
    torchColor *= torchIntensity;
    raytrace_result.a = 0;

    return  mix(torchColor, raytrace_result.rgb, raytrace_result.a) * 600;
}

vec3 get_ambient_lighting(in Pixel pixel) {
    vec3 sample_normal = pixel.normal;

    const float sky_lod_level = 8;

    vec3 sky_diffuse = vec3(0);
    // Add in lighting from the parts around the sun
    // Fade it out by the amount of sky lighting
    vec3 sky_sample_1_pos = vec3(1, 0, 0);
    sky_diffuse += calc_lighting_from_direction(sky_sample_1_pos, sample_normal, pixel.metalness, sky_lod_level);
    vec3 sky_sample_2_pos = vec3(-1, 0, 0);
    sky_diffuse += calc_lighting_from_direction(sky_sample_2_pos, sample_normal, pixel.metalness, sky_lod_level);
    vec3 sky_sample_3_pos = vec3(0, 1, 0);
    sky_diffuse += calc_lighting_from_direction(sky_sample_3_pos, sample_normal, pixel.metalness, sky_lod_level);
    vec3 sky_sample_4_pos = vec3(0, -1, 0);
    sky_diffuse += calc_lighting_from_direction(sky_sample_4_pos, sample_normal, pixel.metalness, sky_lod_level);
    vec3 sky_sample_5_pos = vec3(0, 0, 1);
    sky_diffuse += calc_lighting_from_direction(sky_sample_5_pos, sample_normal, pixel.metalness, sky_lod_level);
    vec3 sky_sample_6_pos = vec3(0, 0, -1);
    sky_diffuse += calc_lighting_from_direction(sky_sample_6_pos, sample_normal, pixel.metalness, sky_lod_level);

    return sky_diffuse * getSkyLighting();
}

///////////////////////////////////////////////////////////////////////////////
//                              Main Functions                               //
///////////////////////////////////////////////////////////////////////////////

Pixel fillPixelStruct() {
    Pixel pixel;
    pixel.position =        getWorldSpacePosition();
    pixel.normal =          viewspace_to_worldspace(vec4(getNormal(), 0.0)).xyz;
    pixel.color =           getColor();
    pixel.metalness =       getMetalness();
    pixel.smoothness =      getSmoothness();
    pixel.skipLighting =    shouldSkipLighting();
    pixel.is_leaf =         getIsLeaf();
    pixel.water =           getWater();
    pixel.sky =             getSky();
    pixel.directLighting =  vec3(0);
    pixel.torchLighting =   vec3(0);
    pixel.shadow =          vec3(1);

    //if(abs(pixel.normal.z) > 0.75 || abs(pixel.normal.x) > 0.75) {
    //    pixel.normal.y *= -1;
    //}

    return pixel;
}

/*!
 * \brief Calculates the amount of water fog at the given location
 */
float calculateWaterFog(in Pixel pixel) {
    float water_distance = getDepthLinear(depthtex1, coord) - getDepthLinear(gdepthtex, coord);
    water_distance = pow(water_distance, 0.0625);

    float fog_amount = water_distance * WATER_FOG_DENSITY;
    fog_amount = clamp(fog_amount, 0.0, 1.0);

    return fog_amount;
}

/*
 * \brief Returns the worldspace vector to the pixel that the refraction ray should hit
 */
vec3 calc_refraction_for_wavelength(in vec3 view_vector, in vec3 normal, in float ior, in float water_depth) {
    vec3 refract_direction = refract(view_vector, normal, ior);

    vec3 refraction_vector = dot(view_vector * water_depth, refract_direction) * refract_direction;

    return refraction_vector;
}

vec3 calc_refraction(in vec3 view_vector, in vec3 normal, in vec3 ior) {
    // Get the distacnce through the water
    float water_distance = getDepthLinear(depthtex1, coord) - getDepthLinear(gdepthtex, coord);

    vec3 red_vector = calc_refraction_for_wavelength(view_vector, normal, ior.r, water_distance);
    vec3 blue_coord = calc_refraction_for_wavelength(view_vector, normal, ior.g, water_distance);
    vec3 green_coord = calc_refraction_for_wavelength(view_vector, normal, ior.b, water_distance);

    vec3 red_position = view_vector + cameraPosition + red_vector;
    vec2 red_coord = (gbufferProjection * (gbufferModelView * vec4(red_position, 1))).st * 0.5 + 0.5;

    return texture2D(gcolor, red_coord).rgb;

    float red = texture2D(gcolor, red_coord).r;
    float green = texture2D(gcolor, red_coord).g;
    float blue = texture2D(gcolor, red_coord).b;

    return vec3(red, green, blue);
}

#ifdef VOLUMETRIC_LIGHTING
vec4 calc_volumetric_lighting(in vec2 vl_coord) {
    // Send a ray through the atmosphere, sampling the shadow at each position

    vec3 world_position = getWorldSpacePosition(vec4(vl_coord, getDepthLinear(vl_coord), 1)).xyz;
    vec3 rayStart = getWorldSpacePosition(vec4(vl_coord, 0, 1)).xyz;
    rayStart += vec3(-0.5, 0.0, 1.5);
    vec4 rayPos = vec4(rayStart, 1.0);
    vec3 viewVector = normalize(world_position - cameraPosition);
    float distanceToPixel = sqrt(dot(viewVector, viewVector));
    vec3 direction = viewVector * calculateDitherPattern() * 2;
    vec3 rayColor = vec3(0);
    float numSteps = 0;

    rayColor = vec3(distanceToPixel);
    float num_hit = 0;

    // Calculate VL for the first 70 units
    for(int i = 0; i < 10; i++) {
        rayPos.xyz += direction;

        vec3 shadowCoord = calcShadowCoordinate(rayPos);
        //shadowCoord.st += vec2(0.5 / shadowMapResolution);

        float shadowDepth = texture2DLod(shadow, shadowCoord.st, 3.2).r;
        float visibility = step(shadowCoord.z - shadowDepth, SHADOW_BIAS);

        float waterDepth = texture2DLod(watershadow, shadowCoord.st, 3.2).r;
        float waterVisibility = step(shadowCoord.z - waterDepth, SHADOW_BIAS);

        vec3 colorSample = texture2D(shadowcolor0, shadowCoord.st).rgb;

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
#endif

vec3 calcLitColor(in Pixel pixel) {
    vec3 light_vector_worldspace = viewspace_to_worldspace(vec4(lightVector, 0)).xyz;
    vec3 gi = get_gi(coord) * (1.0 - pixel.metalness) * calc_lighting_from_direction(light_vector_worldspace, light_vector_worldspace, 0, 0);
    vec3 ambient_lighting = get_ambient_lighting(pixel);

    return (pixel.directLighting + pixel.torchLighting + ambient_lighting + gi) * pixel.color * 0.5;
}

float luma(in vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

void main() {
    curFrag = fillPixelStruct();
    vec3 viewVector = normalize(curFrag.position.xyz - cameraPosition);

    if(curFrag.water > 0.5) {
        // RGB = 570, 540, 440
        vec3 refraction_color = curFrag.color; // calc_refraction(viewVector, curFrag.normal, vec3(1.333, 1.3334, 1.3374));
        float fog_amount = calculateWaterFog(curFrag);
        curFrag.color = mix(refraction_color, WATER_FOG_COLOR, fog_amount);
        //curFrag.color = refraction_color;
    }

    if(curFrag.sky > 0.5) {
        vec2 sky_coord = get_sky_coord(viewVector);
        curFrag.color = texture2DLod(gdepth, sky_coord, 0).rgb;
    }

    vec3 finalColor = vec3(0);

    if(!curFrag.skipLighting) {
        curFrag.directLighting = calcDirectLighting(curFrag);
        curFrag.torchLighting = calcTorchLighting(curFrag);

        finalColor = calcLitColor(curFrag);
    } else {
        finalColor = curFrag.color;

        if(curFrag.sky < 0.5) {
            finalColor *= 10000;
        }
    }

    vec2 vl_coord = coord * 2.0;
    vec4 skyScattering = vec4(0);
    #ifdef VOLUMETRIC_LIGHTING
    if(vl_coord.x < 1 && vl_coord.y < 1) {
        skyScattering = calc_volumetric_lighting(vl_coord);
        vec3 light_vector_worldspace = viewspace_to_worldspace(vec4(lightVector, 0)).xyz;
        skyScattering.rgb *= calc_lighting_from_direction(light_vector_worldspace, light_vector_worldspace, 0, 0);
    }
    #endif

    gl_FragData[0] = vec4(finalColor, 1);
    gl_FragData[1] = skyScattering;
    gl_FragData[2] = vec4(curFrag.shadow, 1.0);
}
