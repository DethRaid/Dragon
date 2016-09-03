#version 450

/*!
 * \brief Responsible for rendering clouds, GI, VL, and raytraced block lighting
 *
 * Renders effects in world space, because that's honestly the most convenient
 */

#include "/lib/space_conversion.glsl"
#include "/lib/shadow_functions.glsl"
#include "/lib/noise_reduction.glsl"
#include "/lib/sky.glsl"

#line 15

const int RGB32F        = 0;

const int gdepthFormat  = RGB32F;

// How many VL samples should we take for each pixel?
#define VL_DISTANCE         20
#define NUM_VL_SAMPLES      15
#define ATMOSPHERIC_DENSITY 0.005

#define GI_FILTER_SIZE_HALF 5

#define CLOUD_PLANE_START   128
#define CLOUD_PLANE_END     160

uniform sampler2D colortex2;
uniform sampler2D colortex6;
uniform sampler2D gdepthtex;

in vec2 coord;
in vec3 sun_direction_worldspace;

layout(location=0) out vec4 sky;
layout(location=1) out vec4 dataTex;

// TODO: 01
/* DRAWBUFFERS:01 */

/*!
 * \brief Getermines the color of the volumetric lighting froma given direction
 *
 * Assumes that the volumetric light starts at the eye
 *
 * \param coord The UV coord of the texels to get the volumetric light for
 * \return The color the the VL in the RGB, and the density at that point in the A
 */
vec4 get_atmosphere(in vec2 vl_coord) {
    // Setup for VL ray
    float tex_depth = texture(gdepthtex, vl_coord).r;
    float dist_to_end = exp_to_linear_depth(tex_depth);
    float vl_step_dist = dist_to_end / NUM_VL_SAMPLES;

    vec3 ray_pos = cameraPosition;
    vec4 pixel_pos = viewspace_to_worldspace(get_viewspace_position(vl_coord, tex_depth));
    vec3 ray_delta_unit = normalize(pixel_pos.xyz - cameraPosition);
    vec3 ray_delta = ray_delta_unit * vl_step_dist * get_dither_8x8(vl_coord);

    // Accumulators
    vec3 vl_color = vec3(0);
    float total_density = 0;
    float density_per_step = ATMOSPHERIC_DENSITY * vl_step_dist;

    // Add one step to the ray to avoid gross artifacts
    ray_pos += ray_delta;

    for(int i = 0; i < NUM_VL_SAMPLES; i++) {
        vec3 light_amount = get_shadow_color(ray_pos);
        vl_color += light_amount;

        ray_pos += ray_delta; 
        total_density += density_per_step;
    }

    vec3 sky_lookup_vector = normalize(vec3(ray_delta_unit.x, 0, ray_delta_unit.z));
    vec2 sky_coord = get_sky_coord(sky_lookup_vector);
    vec3 sky_color = texture(colortex2, sky_coord).rgb;

    return vec4(vl_color * sky_color * total_density / NUM_VL_SAMPLES, total_density);
}

/*!
 * \brief Uses Reflectance Shadow Mapping (http://www.klayge.org/material/3_12/GI/rsm.pdf) algorithm
 */
vec3 get_gi(in vec2 gi_coord) {
    float tex_depth = texture(gdepthtex, gi_coord).r;
    vec4 world_position = viewspace_to_worldspace(get_viewspace_position(gi_coord, tex_depth));

    vec3 shadow_coord = get_shadow_coord(world_position.xyz);
    if(shadow_coord.x < 0 || shadow_coord.x > 1.0 || shadow_coord.y < 0 || shadow_coord.y > 1) {
        // If we're not in the shadow map, we can't have any GI
        return vec3(0);
    }

    vec3 x = world_position.xyz;

    vec3 n = viewspace_to_worldspace(vec4(texture(colortex6, gi_coord).xyz * 2.0 - 1.0, 0.0)).xyz;
    n -= cameraPosition;
    n = normalize(n);

    float e = 0;

    for(int i = -GI_FILTER_SIZE_HALF; i <= GI_FILTER_SIZE_HALF; i++) {
        for(int j = -GI_FILTER_SIZE_HALF; j <= GI_FILTER_SIZE_HALF; j++) {
            vec2 offset = vec2(j, i) / shadowMapResolution;
            float shadow_depth = texture(shadowtex0, shadow_coord.st + offset).r;

            vec4 sample_pos = shadowModelViewInverse * shadowProjectionInverse * vec4(vec3(shadow_coord.xy + offset, shadow_depth) * 2.0 - 1.0, 1.0); 
            sample_pos /= sample_pos.w;
            sample_pos.xyz += cameraPosition;
            
            vec3 xp = sample_pos.xyz;

            vec4 normal_point = texture(shadowcolor1, shadow_coord.st + offset) * 2.0f - 1.0f;
            normal_point.w = 0.0f;
            normal_point = (shadowModelViewInverse * normal_point);
            vec3 np = normalize(normal_point.xyz);

            vec3 dir = x - xp;
            e += max(0, dot(np, dir)) * max(0, dot(n, -dir)) / pow(length(dir), 2);
        }
    }

    return vec3(e) / (GI_FILTER_SIZE_HALF * GI_FILTER_SIZE_HALF * 4);
}

vec4 get_sky(in vec2 sky_coord) {
    // Step from the cloud plane start to the cloud plane end, accumulating cloud density and cloud coloring

}

void main() {
    if(coord.x > 0.5 && coord.y < 0.5) {
        vec2 gi_coord = coord * 2.0 - vec2(1.0, 0.0);
        dataTex = vec4(get_gi(gi_coord), 1);

    } else if(coord.x < 0.5 && coord.y < 0.5) {
        vec2 vl_coord = coord * 2.0;
        dataTex = vec4(get_atmosphere(vl_coord), 1.0);
    }    
}
