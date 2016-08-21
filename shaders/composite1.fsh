#version 450 compatibility

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

// How many VL samples should we take for each pixel?
#define VL_DISTANCE         20
#define NUM_VL_SAMPLES      15
#define ATMOSPHERIC_DENSITY 0.025

uniform sampler2D gdepthtex;

uniform float near;
uniform float far;

uniform vec3 sunPosition;
uniform vec3 moonPosition;

in vec2 coord;
in vec3 sun_direction_worldspace;

/*DRAWBUFFERS:1*/

float exp_to_linear_depth(in float depth_value) {
    return 2.0 * near * far / (far + near - (2.0 * depth_value - 1.0) * (far - near));
}

/*!
 * \brief Getermines the color of the volumetric lighting froma given direction
 *
 * Assumes that the volumetric light starts at the eye
 *
 * \param coord The UV coord of the texels to get the volumetric light for
 * \return The color the the VL in the RGB, and the density at that point in the A
 */
vec4 get_vl_color(in vec2 vl_coord) {
    // Setup for VL ray
    float world_depth = texture(gdepthtex, vl_coord).r;
    float dist_to_end = exp_to_linear_depth(world_depth);
    float vl_step_dist = dist_to_end / NUM_VL_SAMPLES;

    vec3 ray_pos = cameraPosition;
    vec4 pixel_pos = viewspace_to_worldspace(get_viewspace_position(vl_coord, world_depth));
    vec3 ray_delta_unit = normalize(pixel_pos.xyz - cameraPosition);
    vec3 ray_delta = ray_delta_unit * vl_step_dist * get_dither_8x8(vl_coord);

    vec3 vl_color = vec3(0);
    float total_density = 0;
    float density_per_step = ATMOSPHERIC_DENSITY * vl_step_dist;
    float distance_travelled = 0;
    float distance_delta = length(ray_delta);

    // Setup for atmospheric scattering
    float alpha = max(dot(ray_delta_unit, sun_direction_worldspace), 0.0);

	float rayleigh_factor = phase(alpha, -0.01) * RAYLEIGH_BRIGHTNESS;
	float mie_factor = phase(alpha, MIE_DISTRIBUTION) * MIE_BRIGHTNESS;
	float spot = smoothstep(0.0, 15.0, phase(alpha, 0.9995)) * SUNSPOT_BRIGHTNESS;

	vec3 eye_position = worldspace_to_skyspace(cameraPosition);
	float eye_depth = atmospheric_depth(eye_position, ray_delta_unit);

	float eye_extinction = horizon_extinction(eye_position, ray_delta_unit, SURFACE_HEIGHT - 0.15);

    // Add one step to the ray to avoid gross artifacts
    ray_pos += ray_delta;

    for(int i = 0; i < NUM_VL_SAMPLES; i++) {
        vec3 light_amount = get_shadow_color(ray_pos);
        if(length(light_amount) > 0.001) {

            vl_color += light_amount;
     
            vec3 sky_position = worldspace_to_skyspace(world_position);
            float extinction = horizon_extinction(sky_position, sun_direction_worldspace, SURFACE_HEIGHT - 0.35);
            float sample_depth = atmospheric_depth(sky_position, sun_direction_worldspace);

            vec3 influx = absorb(sample_depth, vec3(SUNSPOT_BRIGHTNESS), SCATTER_STRENGTH) * extinction;

            mie_collected += absorb(distance, influx, MIE_STRENGTH);
		    rayleigh_collected += absorb(sample_distance, Kr * influx, RAYLEIGH_STRENGTH);
        }

        ray_pos += ray_delta; 
        total_density += density_per_step;
        distance_travelled += distance_delta;
    }
    
	rayleigh_collected = (rayleigh_collected * eye_extinction * pow(eye_depth, RAYLEIGH_COLLECTION_POWER)) / STEP_COUNT;
	mie_collected = (mie_collected * eye_extinction * pow(eye_depth, MIE_COLLECTION_POWER)) / STEP_COUNT;

	vec3 color = (spot * mie_collected) + (mie_factor * mie_collected) + (rayleigh_factor * rayleigh_collected);

    return vec4(vl_color * color / NUM_VL_SAMPLES, total_density);
}

 void main() {
     float depth = texture2D(gdepthtex, coord).r;
     vec4 view_position = get_viewspace_position(coord, depth);
     vec4 world_position = viewspace_to_worldspace(view_position);

     vec3 shadow_color = get_shadow_color(world_position.xyz) * 0.8;

     vec4 vl = get_vl_color(coord);

     gl_FragData[0] = vec4(mix(shadow_color, vl.rgb, vl.a), 1.0);
 }
