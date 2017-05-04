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
#include "/lib/noise.glsl"

#line 16

const int RGB16F        = 0;
const int RGB32F        = 1;

const int gcolorFormat  = RGB32F;
const int gdepthFormat  = RGB32F;

// How many VL samples should we take for each pixel?
#define VL_DISTANCE             20
#define NUM_VL_SAMPLES          15
#define ATMOSPHERIC_DENSITY     0.005

#define GI_FILTER_SIZE_HALF     15

#define CLOUD_PLANE_START       128
#define CLOUD_PLANE_END         160
#define NUM_CLOUD_STEPS         8

#define NUM_LIGHT_RAYS          1
#define LIGHT_RAY_STEP_DIST     0.1
#define LIGHT_RAY_STEP_GROW     1.05
#define LIGHT_RAY_MAX_STEPS     100
#define LIGHT_RAY_DEPTH_BIAS    0.05

#define PI                      3.14159265

uniform sampler2D colortex2;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;

uniform sampler2D gdepthtex;

in vec2 coord;
in vec3 sun_direction_worldspace;
in vec3 light_direction_viewspace;

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

    vec3 sky_lookup_vector = mix(ray_delta_unit, vec3(0, 1, 0), min(1, ray_pos.y / 256.0f));
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

    vec3 e = vec3(0);

    for(int i = -GI_FILTER_SIZE_HALF; i <= GI_FILTER_SIZE_HALF; i++) {
        for(int j = -GI_FILTER_SIZE_HALF; j <= GI_FILTER_SIZE_HALF; j++) {
            vec2 offset = vec2(j, i) / shadowMapResolution;
            float shadow_depth = texture(shadowtex0, shadow_coord.st + offset).r;

            vec4 sample_pos = shadowModelViewInverse * shadowProjectionInverse * vec4(vec3(shadow_coord.xy + offset, shadow_depth) * 2.0 - 1.0, 1.0);
            sample_pos /= sample_pos.w;
            sample_pos.xyz += cameraPosition;

            vec3 xp = sample_pos.xyz;

            vec3 normal_point = texture(shadowcolor1, shadow_coord.st + offset).xyz * 2.0f - 1.0f;
            normal_point = mat3(shadowModelViewInverse) * normal_point;
            vec3 np = normalize(normal_point);

            vec2 light_hitting_p_pos = get_sky_coord(sun_direction_worldspace);
            vec3 light_hitting_p = texture(colortex2, light_hitting_p_pos, 9).rgb;
            vec3 p_albedo = texture(shadowcolor0, shadow_coord.st + offset).rgb;
            vec3 flux = light_hitting_p * p_albedo * max(0, dot(np, sun_direction_worldspace));

            vec3 dir = x - xp;
            e += flux * max(0, dot(np, dir)) * max(0, dot(n, -dir)) / pow(length(dir), 2);
        }
    }

    return e / (GI_FILTER_SIZE_HALF * GI_FILTER_SIZE_HALF * 4);
}

/*!
 * \brief Determines the UV coordinate where the ray hits
 *
 * If the returned value is not in the range [0, 1] then nothing was hit.
 * NOTHING!
 * Note that origin and direction are assumed to be in viewspace
 */
vec3 cast_screenspace_ray(in vec3 origin, in vec3 direction) {
    vec3 curPos = origin;
    vec2 curCoord = get_coord_from_viewspace(vec4(curPos, 1));
    direction = normalize(direction) * LIGHT_RAY_STEP_DIST;
    #ifdef DITHER_REFLECTION_RAYS
        direction *= mix(0.75, 1.0, calculateDitherPattern());
    #endif
    bool forward = true;
    bool can_collect = true;

    //The basic idea here is the the ray goes forward until it's behind something,
    //then slowly moves forward until it's in front of something.
    for(int i = 0; i < LIGHT_RAY_MAX_STEPS; i++) {
        curPos += direction;
        curCoord = get_coord_from_viewspace(vec4(curPos, 1));
        if(curCoord.x < 0 || curCoord.x > 1 || curCoord.y < 0 || curCoord.y > 1) {
            //If we're here, the ray has gone off-screen so we can't reflect anything
            return vec3(-1);
        }
        float depth = texture(gdepthtex, curCoord).r;
        vec3 worldDepth = get_viewspace_position(curCoord, exp_to_linear_depth(depth)).xyz;
        float depthDiff = (worldDepth.z - curPos.z);
        float maxDepthDiff = sqrt(dot(direction, direction)) + LIGHT_RAY_DEPTH_BIAS;
        if(depthDiff > 0 && depthDiff < maxDepthDiff) {
            vec3 travelled = origin - curPos;
            return vec3(curCoord, sqrt(dot(travelled, travelled)));
            direction = -1 * normalize(direction) * 0.15;
            forward = false;
        }
        direction *= LIGHT_RAY_STEP_GROW;
    }
    //If we're here, we couldn't find anything to reflect within the alloted number of steps
    return vec3(-1);
}

/*!
 * \brief Sends screenspace rays out to get the lighting contribution of lit blocks
 *
 * \param light_coord The uv coord to calculate raytraced light for
 * \return The hit color. The w component of the return value tells us what percentage of rays were able to resolve
 */
vec4 get_raytraced_light(vec2 light_coord) {
    float tex_depth = texture(gdepthtex, light_coord).r;
    vec4 viewspace_position = get_viewspace_position(light_coord, tex_depth);

    vec3 tex_normal = texture(colortex6, light_coord).xyz * 2.0 - 1.0;
    vec3 ray_direction = vec3(0);
    vec3 ray_color = vec3(0);
    float num_hit_rays = 0;

    for(int i = 0; i < NUM_LIGHT_RAYS; i++) {
        vec3 noise = normalize(vec3(
            get3DNoise(light_coord.xyx * (i + 500)), 
            get3DNoise(light_coord.yxy * (i + 1000)), 
            get3DNoise(light_coord.xxy * (i + 1500))
            )) * 2.0 - 1.0;
        ray_direction = normalize(tex_normal + noise * 0.35);

        vec3 hit_coord = cast_screenspace_ray(viewspace_position.xyz, ray_direction);
        if(hit_coord.x < 0 || hit_coord.y < 0) {
            continue;
        }
        num_hit_rays++;
        
        return vec4(hit_coord, 1);

        vec3 hit_color = texture(colortex4, hit_coord.st).rgb;
        float ndotl_ray = dot(tex_normal, ray_direction);
        float hit_coord_is_light = texture(colortex5, hit_coord.st).b;
        if(hit_coord_is_light < 0.5) {
            vec3 hit_normal = texture(colortex6, hit_coord.st).xyz * 2.0 - 1.0;
            float hit_ndotl = max(0, dot(hit_normal, light_direction_viewspace));
            hit_color *= hit_ndotl;
        }

        ray_color += hit_color * ndotl_ray;
    }

    return vec4(ray_color, num_hit_rays) / float(NUM_LIGHT_RAYS);
}

/*vec3 raytrace_light(in vec2 coord) {
	vec3 light = vec3(0);
	vec3 position_viewspace = get_viewspace_position(coord).xyz;
	vec3 normal = get_normal(coord);
	for(int i = 0; i < NUM_LIGHT_RAYS; i++) {
		vec3 noise = get_3d_noise(coord * i);
		vec3 ray_direction = normalize(noise * 0.35 + normal);
		vec3 hit_uv = cast_screenspace_ray(position_viewspace, ray_direction);
		hit_uv.z *= 0.5;

		float ndotl = max(0, dot(normal, ray_direction));
		float falloff = max(1, pow(hit_uv.z, 1));
		float emission =  get_emission(hit_uv.st);
		light += texture2D(gcolor, hit_uv.st).rgb * emission * ndotl / falloff;
	}

	return light * 2 / float(NUM_LIGHT_RAYS);
}*/

vec4 get_sky(in vec2 sky_coord) {
    // Step from the cloud plane start to the cloud plane end, accumulating cloud density and cloud coloring
    float depth = texture2D(gdepthtex, coord).r;
    vec4 view_position = get_viewspace_position(coord, depth);
    vec4 world_position = viewspace_to_worldspace(view_position);
    world_position.xyz -= cameraPosition;

    vec3 ray_direction = normalize(world_position.xyz);

    float iterations_to_start = CLOUD_PLANE_START / ray_direction.y;
    vec3 ray_start = ray_direction * iterations_to_start;

    float iterations_to_end = CLOUD_PLANE_END / ray_direction.y;
    vec3 ray_end = ray_direction * iterations_to_end;

    vec3 ray_step = (ray_end - ray_start) / NUM_CLOUD_STEPS;
    vec3 ray_pos = ray_start;

    vec3 cloud_color = vec3(0);

    for(int i = 0; i < NUM_CLOUD_STEPS; i++) {
        cloud_color += vec3(get3DNoise(ray_pos));

        ray_pos += ray_step;
    }

    vec2 sky_lookup_coord = get_sky_coord(ray_direction);
    vec3 sky_color = texture(colortex2, sky_lookup_coord).rgb;

    return vec4(cloud_color / NUM_CLOUD_STEPS, 1.0);
}

void main() {
    if(coord.x > 0.5 && coord.y < 0.5) {
        vec2 gi_coord = coord * 2.0 - vec2(1.0, 0.0);
        dataTex = vec4(get_gi(gi_coord), 1);

    } else if(coord.x < 0.5 && coord.y < 0.5) {
        vec2 vl_coord = coord * 2.0;
        dataTex = get_atmosphere(vl_coord);

    } else if(coord.x < 0.5 && coord.y > 0.5) {
        vec2 light_coord = coord * 2.0 - vec2(0, 1);
        dataTex = get_raytraced_light(light_coord);
    }

    sky = get_sky(coord);
}
