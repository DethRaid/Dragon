#ifndef SHADOE_FUNCTIONS_GLSL
#define SHADOW_FUNCTIONS_GLSL

#include "/lib/space_conversion.glsl"
#include "/lib/noise.glsl"

#line 2007

/*!
 * \brief Defines a number of functions to use with shadows
 */

#define LIGHT_SIZE                  5
#define MIN_PENUMBRA_SIZE           0.01
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
#define SHADOW_MAP_BIAS             0.8
//#define HYBRID_RAYTRACED_SHADOWS
#define HRS_RAY_LENGTH              0.8
#define HRS_RAY_STEPS               100
#define HRS_BIAS                    0.02
#define HRS_DEPTH_CORRECTION        0.01

#define SHADOW_BIAS                 0.0025

/*SHADOWFOV:45*/
const int shadowMapResolution = 4096;
const bool shadowHardwareFiltering = false;
const bool shadowHardwareFiltering0 = false;
const bool shadowHardwareFiltering1 = false;
const bool generateShadowMipmap = false;
const bool shadowtexMipmap = false;
const bool shadowtexMipmap0 = false;
const bool shadowtexMipmap1 = false;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;
uniform sampler2D watershadow;

uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjectionInverse;

/*!
 * \brief Converts a vec4 from worldspace into shadowspace
 */
vec4 worldspace_to_shadowspace(in vec4 position_worldspace) {
    position_worldspace.xyz -= cameraPosition;
	vec4 pos = shadowProjection * shadowModelView * position_worldspace;
	return pos /= pos.w;
}

/*! 
 * \brief Calculates the shadow coord at the given world position
 *
 * \param world_position The worldspace position to get the shadow coordinate ar
 * \return The shadow coordinate. The UV shadow map coordinate is in the X and Y components, the shadowspace depth is
 * in the Z 
 */
vec3 get_shadow_coord(in vec3 world_position) {
    vec3 shadow_coord = worldspace_to_shadowspace(vec4(world_position, 1.0)).xyz;
    return shadow_coord * 0.5 + 0.5;
}

//Implements the Percentage-Closer Soft Shadow algorithm, as defined by nVidia
//Implemented by DethRaid - github.com/DethRaid
float calcPenumbraSize(vec3 shadowCoord) {
	float dFragment = shadowCoord.z;
	float dBlocker = 0;
	float penumbra = MIN_PENUMBRA_SIZE;

	float temp;
	float num_blockers = 0;
    float search_size = 2 * LIGHT_SIZE * (dFragment - 1) / dFragment;

    for(int i = -BLOCKER_SEARCH_SAMPLES_HALF; i <= BLOCKER_SEARCH_SAMPLES_HALF; i++) {
        for(int j = -BLOCKER_SEARCH_SAMPLES_HALF; j <= BLOCKER_SEARCH_SAMPLES_HALF; j++) {
            vec2 sample_coord = shadowCoord.st + (vec2(i, j) * search_size / (shadowMapResolution * 5 * BLOCKER_SEARCH_SAMPLES_HALF));
            temp = textureLod(shadowtex1, sample_coord, 2).r;
            if(dFragment - temp > 0.0015) {
                dBlocker += temp;
                num_blockers += 1.0;
            }
        }
	}

    if(num_blockers > 0.1) {
		dBlocker /= num_blockers;
		penumbra = (dFragment - dBlocker) * LIGHT_SIZE / dFragment;
	}

    return max(penumbra, MIN_PENUMBRA_SIZE);
}

/*!
 * \brief Calculates the color of the shadow at a given place in the world
 *
 * Returns a vec3 and not a float so that it can be used for colored shadows
 *
 * Impliments hard shadows right now, becuase hard shadows are easy
 *
 * \param world_position The worldspace position to get the shadow color at
 * \return The color of the shadow at the given point
 */
vec3 get_shadow_color(in vec3 world_position, vec2 coord) {
    vec3 shadow_coord = get_shadow_coord(world_position);

    if(shadow_coord.x > 1 || shadow_coord.x < 0 ||
        shadow_coord.y > 1 || shadow_coord.y < 0) {
        // Shadow coord out of range? Let's bail out of here
        return vec3(1.0);
    }

#ifdef HARD_SHADOWS
    float shadow_depth = texture(shadowtex0, shadow_coord.st).r;
    return vec3(step(shadow_coord.z - shadow_depth, SHADOW_BIAS));

#else
    float penumbra_size = 0.5;

#ifdef REALISTIC_SHADOWS
    penumbra_size = calcPenumbraSize(shadow_coord) * 0.4;
#endif

    float num_blockers = 0.0;
    float num_samples = 0.0;

#ifdef USE_RANDOM_ROTATION
    float rotate_amount = get3DNoise(coord.yxy).r * 2.0 - 1.0;

    mat2 kernel_rotation = mat2(
        cos(rotate_amount), -sin(rotate_amount),
        sin(rotate_amount), cos(rotate_amount)
   );
#endif

    vec3 shadow_color = vec3(0);

    for(int i = -PCF_SIZE_HALF; i <= PCF_SIZE_HALF; i++) {
        for(int j = -PCF_SIZE_HALF; j <= PCF_SIZE_HALF; j++) {
            vec2 sample_coord = vec2(j, i) / (shadowMapResolution * 0.25 * PCF_SIZE_HALF);
            sample_coord *= penumbra_size;

        #ifdef USE_RANDOM_ROTATION
            sample_coord = kernel_rotation * sample_coord;
        #endif

            float shadow_depth = textureLod(shadowtex1, shadow_coord.st + sample_coord, 0).r;
            float visibility = step(shadow_coord.z - shadow_depth, SHADOW_BIAS);

            float water_depth = textureLod(watershadow, shadow_coord.st + sample_coord, 0).r;
            float water_visibility = step(shadow_coord.z - water_depth, SHADOW_BIAS);

            vec3 color_dample = texture(shadowcolor0, shadow_coord.st + sample_coord).rgb;

            color_dample = mix(color_dample, vec3(1.0), water_visibility);
            color_dample = mix(vec3(0.0), color_dample, visibility);

            shadow_color += color_dample;

            num_samples++;
        }
    }

    shadow_color /= num_samples;

#ifdef HYBRID_RAYTRACED_SHADOWS
    if(length(fragPosition.xyz - cameraPosition) < 8.7) {
        vec2 raytraced_shadow = calc_raytraced_shadows(get_viewspace_position().xyz, lightVector);
        shadow_color = min(raytraced_shadow.xxx, shadow_color);
    }
#endif

    return shadow_color;
#endif
}

#endif
