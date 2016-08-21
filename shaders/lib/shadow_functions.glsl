#ifndef SHADOE_FUNCTIONS_GLSL
#define SHADOW_FUNCTIONS_GLSL

#include "/lib/space_conversion.glsl"

#line 2007

/*!
 * \brief Defines a number of functions to use with shadows
 */

#define PCF_SIZE_HALF 3
#define SHADOW_BIAS 0.0025

/*SHADOWFOV:45*/
const int shadowMapResolution = 2048;
const bool shadowHardwareFiltering = false;
const bool shadowHardwareFiltering0 = false;
const bool shadowHardwareFiltering1 = false;
const bool generateShadowMipmap = false;
const bool shadowtexMipmap = false;
const bool shadowtexMipmap0 = false;
const bool shadowtexMipmap1 = false;

uniform sampler2D shadowtex0;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

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
vec3 get_shadow_color(in vec3 world_position) {
    vec3 shadow_coord = get_shadow_coord(world_position);

    if(shadow_coord.x > 1 || shadow_coord.x < 0 ||
        shadow_coord.y > 1 || shadow_coord.y < 0) {
        // Shadow coord out of range? Let's bail out of here
        return vec3(1.0);
    }

    float shadow_depth = texture(shadowtex0, shadow_coord.st).r;
    return vec3(step(shadow_coord.z - shadow_depth, SHADOW_BIAS));
}

#endif
