#version 120
#extension GL_ARB_shader_texture_lod : enable

/*!
 * \brief Computes GI and the skybox
 */

#define GLOBAL_ILLUMINATION

// GI variables
#define GI_SAMPLE_RADIUS 50
#define GI_QUALITY 8	// [2 4 8 16]

#define SHADOW_MAP_BIAS 0.8

// Lighting things
//#define RAYTRACED_LIGHT
#define MAX_RAY_LENGTH          16.0	// [8.0 10.0 12.0 16.0 32.0]
#define MIN_DEPTH_DIFFERENCE    1.25
#define RAY_STEP_LENGTH         0.25
#define RAY_DEPTH_BIAS          0.05
#define RAY_GROWTH              1.05
#define NUM_DIFFUSE_RAYS        4		// [1 2 4 8 16 32]
//#define DITHER_REFLECTION_RAYS

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
#define SHADOW_MAP_BIAS             0.8
//#define HYBRID_RAYTRACED_SHADOWS
#define HRS_RAY_LENGTH              0.8
#define HRS_RAY_STEPS               100
#define HRS_BIAS                    0.02
#define HRS_DEPTH_CORRECTION        0.01

#define SHADOW_BIAS                 0.00525

// Sky options
#define RAYLEIGH_BRIGHTNESS			3.3
#define MIE_BRIGHTNESS 				0.1
#define MIE_DISTRIBUTION 			0.63
#define STEP_COUNT 					15.0
#define SCATTER_STRENGTH			0.028
#define RAYLEIGH_STRENGTH			0.139
#define MIE_STRENGTH				0.0264
#define RAYLEIGH_COLLECTION_POWER	0.81
#define MIE_COLLECTION_POWER		0.39

#define SUNSPOT_BRIGHTNESS			500
#define MOONSPOT_BRIGHTNESS			25

#define SKY_SATURATION				1.5

#define SURFACE_HEIGHT				0.98

#define CLOUDS_START 				512

#define PI 3.14159

const int RGB32F					= 0;
const int RGB16F					= 1;

const int   shadowMapResolution     = 1024;	// [1024 2048 4096]
const float shadowDistance          = 120.0;
const bool  generateShadowMipmap    = false;
const float shadowIntervalSize      = 4.0;
const bool  shadowHardwareFiltering = false;
const bool  shadowtexNearest        = true;
const float	sunPathRotation 		= -10.0f;

const int   noiseTextureResolution  = 64;
const int 	gdepthFormat			= RGB32F;
const int	gnormalFormat			= RGB16F;

uniform sampler2D gcolor;
uniform sampler2D gdepthtex;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;

uniform sampler2D shadowtex1;
uniform sampler2D watershadow;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

uniform sampler2D noisetex;

uniform float viewWidth;
uniform float viewHeight;

uniform vec3 cameraPosition;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform vec3 sunPosition;
uniform vec3 moonPosition;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

varying vec2 coord;
varying vec3 lightVector;
varying vec3 lightColor;
varying vec3 ambientColor;

varying vec3 fogColor;
varying vec3 skyColor;

// TODO: 21
/* DRAWBUFFERS:21 */

vec3 get_normal(in vec2 coord) {
	return texture2DLod(gaux4, coord, 0).xyz * 2.0 - 1.0;
}

float get_depth(in vec2 coord) {
	return texture2D(gdepthtex, coord.st).x;
}

vec4 get_viewspace_position(in vec2 coord) {
    float depth = get_depth(coord);
    vec4 pos = gbufferProjectionInverse * vec4(vec3(coord.st, depth) * 2.0 - 1.0, 1.0);
	return pos / pos.w;
}

vec4 viewspace_to_worldspace(in vec4 position_viewspace) {
	vec4 pos = gbufferModelViewInverse * position_viewspace;
	return pos;
}

vec4 worldspace_to_shadowspace(in vec4 position_worldspace) {
	vec4 pos = shadowProjection * shadowModelView * position_worldspace;
	return pos /= pos.w;
}

vec3 get_3d_noise(in vec2 coord) {
    coord *= vec2(viewWidth, viewHeight);
    coord /= noiseTextureResolution;

    return texture2D(noisetex, coord).xyz * 2.0 - 1.0;
}

float get_leaf(in vec2 coord) {
	return texture2D(gaux3, coord).b;
}

/*
 * Global Illumination
 *
 * Calculates bounces diffuse light
 */

vec4 distort_shadow_coord(in vec4 shadow_coord) {
	vec2 pos = abs(shadow_coord.xy * 1.165);
	float dist = pow(pow(pos.x, 8) + pow(pos.y, 8), 1.0 / 8.0);
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;

	shadow_coord.xy *= 1.0f / distortFactor;
	shadow_coord.z /= 4.0;
 	shadow_coord = shadow_coord * 0.5 + 0.5;

	return shadow_coord;
}

vec3 calculate_gi(in vec2 gi_coord, in vec4 position_viewspace, in vec3 normal) {
 	float NdotL = dot(normal, lightVector);

 	vec3 normal_shadowspace = (shadowModelView * gbufferModelViewInverse * vec4(normal, 0.0)).xyz;

 	vec4 position = viewspace_to_worldspace(position_viewspace);
 		 position = worldspace_to_shadowspace(position);

 	vec3 light = vec3(0.0);
 	int samples	= 0;

 	for(int y = -GI_QUALITY; y <= GI_QUALITY; y++) {
	 	for(int x = -GI_QUALITY; x <= GI_QUALITY; x++) {
	 		vec2 offset = vec2(x, y) * GI_SAMPLE_RADIUS;
	 		//offset += get_3d_noise(gi_coord).xy * 25;
	 		offset /= 2 * shadowMapResolution;

			vec4 shadowmap_coord = position;
			shadowmap_coord.xy += offset;
			shadowmap_coord = distort_shadow_coord(position);

	 		vec3 sample_pos = vec3(shadowmap_coord.st, 0.0);
	 		sample_pos.z	= texture2DLod(shadowtex1, sample_pos.st, 0).x;

	 		vec3 sample_dir      = normalize(sample_pos.xyz - position.xyz);
	 		vec3 normal_shadow	 = normalize(texture2DLod(shadowcolor1, sample_pos.st, 0).xyz * 2.0 - 1.0);
			//normal_shadow.xy *= -1;

	        vec3 light_strength              = vec3(max(0, dot(normal_shadow, vec3(0, 0, 1))));
	 		float received_light_strength	 = max(0.0, dot(normal_shadowspace, sample_dir));
	 		float transmitted_light_strength = max(0.0, dot(normal_shadow, -sample_dir));

			//return vec3(received_light_strength / 500);

	 		float falloff = length(sample_pos.xyz - position.xyz) * 5;
	        falloff = pow(falloff, 4);
			falloff = max(1.0, falloff);

	 		vec3 sample_color = pow(texture2DLod(shadowcolor0, sample_pos.st, 0.0).rgb, vec3(1));
			//return sample_color / 1000;
	        vec3 flux = sample_color * light_strength;

	 		//light += flux * transmitted_light_strength * received_light_strength / falloff;
			light += vec3(transmitted_light_strength);
	 	}
	}

 	light /= pow(GI_QUALITY * 2 + 1, 1.0);

 	return light / 15;
}

/*
 * Begin sky rendering code
 *
 * Taken from http://codeflow.org/entries/2011/apr/13/advanced-webgl-part-2-sky-rendering/
 */

float phase(float alpha, float g) {
	float a = 3.0 * (1.0 - g * g);
	float b = 2.0 * (2.0 + g * g);
    float c = 1.0 + alpha * alpha;
    float d = pow(1.0 + g * g - 2.0 * g * alpha, 1.5);
    return (a / b) * (c / d);
}

vec3 get_eye_vector(in vec2 coord) {
	const vec2 coord_to_long_lat = vec2(2.0 * PI, PI);
	coord.y -= 0.5;
	vec2 long_lat = coord * coord_to_long_lat;
	float longitude = long_lat.x;
	float latitude = long_lat.y - (2.0 * PI);

	float cos_lat = cos(latitude);
	float cos_long = cos(longitude);
	float sin_lat = sin(latitude);
	float sin_long = sin(longitude);

	return normalize(vec3(cos_lat * cos_long, cos_lat * sin_long, sin_lat));
}

float atmospheric_depth(vec3 position, vec3 dir) {
	float a = dot(dir, dir);
    float b = 2.0 * dot(dir, position);
    float c = dot(position, position) - 1.0;
    float det = b * b - 4.0 * a * c;
    float detSqrt = sqrt(det);
    float q = (-b - detSqrt) / 2.0;
    float t1 = c / q;
    return t1;
}

float horizon_extinction(vec3 position, vec3 dir, float radius) {
	float u = dot(dir, -position);
    if(u < 0.0) {
        return 1.0;
    }

    vec3 near = position + u*dir;

    if(sqrt(dot(near, near)) < radius) {
        return 0.0;

    } else {
        vec3 v2 = normalize(near)*radius - position;
        float diff = acos(dot(normalize(v2), dir));
        return smoothstep(0.0, 1.0, pow(diff * 2.0, 3.0));
    }
}

vec3 Kr = vec3(0.18867780436772762, 0.4978442963618773, 0.6616065586417131);	// Color of nitrogen

vec3 absorb(float dist, vec3 color, float factor) {
	return color - color * pow(Kr, vec3(factor / dist));
}

float rand(vec2 c){
    return fract(sin(dot(c.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

// From https://gist.github.com/patriciogonzalezvivo/670c22f3966e662d2f83
float noise(vec2 p, float freq ){
    float unit = viewWidth/freq;
    vec2 ij = floor(p/unit);
    vec2 xy = mod(p,unit)/unit;
    //xy = 3.*xy*xy-2.*xy*xy*xy;
    xy = .5*(1.-cos(PI*xy));
    float a = rand((ij+vec2(0.,0.)));
    float b = rand((ij+vec2(1.,0.)));
    float c = rand((ij+vec2(0.,1.)));
    float d = rand((ij+vec2(1.,1.)));
    float x1 = mix(a, b, xy.x);
    float x2 = mix(c, d, xy.x);
    return mix(x1, x2, xy.y);
}

float pNoise(vec2 p, int res){
    float persistance = .5;
    float n = 0.;
    float normK = 0.;
    float f = 4.;
    float amp = 1.;
    int iCount = 0;
    for (int i = 0; i<50; i++){
        n+=amp*noise(p, f);
        f*=2.;
        normK+=amp;
        amp*=persistance;
        if (iCount == res) break;
        iCount++;
    }
    float nf = n/normK;
    return nf*nf*nf*nf;
}

/*!
 * \brief Renders the sky to a equirectangular texture, allowing for world-space sky reflections
 *
 * \param coord The UV coordinate to render to
 */
vec3 get_sky_color(in vec3 eye_vector, in vec3 light_vector, in float light_intensity) {
	vec3 light_vector_worldspace = normalize(viewspace_to_worldspace(vec4(light_vector, 0.0)).xyz);

	float alpha = max(dot(eye_vector, light_vector_worldspace), 0.0);

	float rayleigh_factor = phase(alpha, -0.01) * RAYLEIGH_BRIGHTNESS;
	float mie_factor = phase(alpha, MIE_DISTRIBUTION) * MIE_BRIGHTNESS;
	float spot = smoothstep(0.0, 15.0, phase(alpha, 0.9995)) * light_intensity;

	vec3 eye_position = vec3(0.0, SURFACE_HEIGHT, 0.0);
	float eye_depth = atmospheric_depth(eye_position, eye_vector);
	float step_length = eye_depth / STEP_COUNT;

	float eye_extinction = horizon_extinction(eye_position, eye_vector, SURFACE_HEIGHT - 0.15);

	vec3 rayleigh_collected = vec3(0);
	vec3 mie_collected = vec3(0);

	for(int i = 0; i < STEP_COUNT; i++) {
		float sample_distance = step_length * float(i);
		vec3 position = eye_position + eye_vector * sample_distance;
		float extinction = horizon_extinction(position, light_vector_worldspace, SURFACE_HEIGHT - 0.35);
		float sample_depth = atmospheric_depth(position, light_vector_worldspace);

		vec3 influx = absorb(sample_depth, vec3(light_intensity), SCATTER_STRENGTH) * extinction;

		// rayleigh will make the nice blue band around the bottom of the sky
		rayleigh_collected += absorb(sample_distance, Kr * influx, RAYLEIGH_STRENGTH);
		mie_collected += absorb(sample_distance, influx, MIE_STRENGTH);
	}

	rayleigh_collected = (rayleigh_collected * eye_extinction * pow(eye_depth, RAYLEIGH_COLLECTION_POWER)) / STEP_COUNT;
	mie_collected = (mie_collected * eye_extinction * pow(eye_depth, MIE_COLLECTION_POWER)) / STEP_COUNT;

	vec3 color = (spot * mie_collected) + (mie_factor * mie_collected) + (rayleigh_factor * rayleigh_collected);

	return color * 7;
}

float get_brownian_noise(in vec2 orig_coord) {
	float noise_accum = 0;
	noise_accum += texture2D(noisetex, orig_coord * vec2(3, 1)).b * 0.5;
	noise_accum += texture2D(noisetex, orig_coord * 2).g * 0.25;
	//noise_accum += texture2D(noisetex, orig_coord * 8).g * 0.125;
	//noise_accum += texture2D(noisetex, orig_coord * 16).g * 0.0625;

	return pow(noise_accum, 2);
}

vec3 calc_clouds(in vec3 eye_vector) {
	// Project the eye vector against the cloud plane, then use that position to draw a red/green stiped band

	float num_steps_to_clouds = CLOUDS_START / eye_vector.y;
	vec3 clouds_start_pos = eye_vector * num_steps_to_clouds;
	if(length(clouds_start_pos) > 10000 || num_steps_to_clouds < 0.0f) {
		return vec3(0);
	}

	vec3 color = vec3(get_brownian_noise(clouds_start_pos.xz * 0.00001));

	return color;
}

/*
 * Shadowing code
 */
vec3 calcShadowCoordinate(in vec4 pixelPos) {
    vec4 shadowCoord = viewspace_to_worldspace(pixelPos);
    shadowCoord = worldspace_to_shadowspace(shadowCoord);

	vec2 pos = abs(shadowCoord.xy * 1.165);
	float dist = pow(pow(pos.x, 8) + pow(pos.y, 8), 1.0 / 8.0);
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;

	shadowCoord.xy *= 1.0f / distortFactor;
	shadowCoord.z /= 4.0;

    shadowCoord.st = shadowCoord.st * 0.5 + 0.5;    //take it from [-1, 1] to [0, 1]
    float dFrag = shadowCoord.z * 0.5 + 0.505;

    return vec3(shadowCoord.st, dFrag);
}

vec2 getCoordFromCameraSpace(in vec3 position) {
    vec4 viewSpacePosition = gbufferProjection * vec4(position, 1);
    vec2 ndcSpacePosition = viewSpacePosition.xy / viewSpacePosition.w;
    return ndcSpacePosition * 0.5 + 0.5;
}

vec3 getCameraSpacePosition(vec2 uv, float depth) {
	vec4 fragposition = gbufferProjectionInverse * vec4(uv.s * 2.0 - 1.0, uv.t * 2.0 - 1.0, 2.0 * depth - 1.0, 1.0);
		 fragposition /= fragposition.w;
	return fragposition.xyz;
}

/*
vec2 calc_raytraced_shadows(in vec3 origin, in vec3 direction) {
    vec3 curPos = origin;
    vec2 curCoord = getCoordFromCameraSpace(curPos);
    vec3 noise = get_3d_noise(coord);
    direction = normalize(direction + noise * 0.01);
    //return direction;
    direction = normalize(direction) * (HRS_RAY_LENGTH / HRS_RAY_STEPS);

    //The basic idea here is the the ray goes forward until it's behind something,
    //then slowly moves forward until it's in front of something.
    for(int i = 0; i < HRS_RAY_STEPS; i++) {
        curPos += direction;
        curCoord = getCoordFromCameraSpace(curPos);
        if(curCoord.x < 0 || curCoord.x > 1 || curCoord.y < 0 || curCoord.y > 1) {
            //If we're here, the ray has gone off-screen so we can't reflect anything
            return vec2(1);
        }
        float raw_depth = getDepth(curCoord);
        float worldDepth = getCameraSpacePosition(curCoord, raw_depth).z;
        worldDepth -= HRS_DEPTH_CORRECTION * raw_depth;
        float depthDiff = (worldDepth - curPos.z);
        //return vec2(depthDiff * far);
        float maxDepthDiff = sqrt(dot(direction, direction)) + HRS_BIAS;
        //maxDepthDiff *= raw_depth;
        if(depthDiff > 0 && depthDiff < maxDepthDiff) {
            return vec2(0, length(curPos - origin) / HRS_RAY_LENGTH);
        }
    }
    //If we're here, we couldn't find anything to reflect within the alloted number of steps
    return vec2(1);
}
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

vec3 calcShadowing(in vec4 fragPosition) {
    vec3 shadowCoord = calcShadowCoordinate(fragPosition);

    if(shadowCoord.x > 1 || shadowCoord.x < 0 ||
        shadowCoord.y > 1 || shadowCoord.y < 0) {
        return vec3(1.0);
    }

    #ifdef HARD_SHADOWS
        float shadowDepth = texture2D(shadowtex1, shadowCoord.st).r;
        return vec3(step(shadowCoord.z - shadowDepth, SHADOW_BIAS));

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
                vec2 sampleCoord = vec2(j, i) / (shadowMapResolution * 0.25 * PCF_SIZE_HALF);
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

        #ifdef HYBRID_RAYTRACED_SHADOWS
        if(length(fragPosition.xyz - cameraPosition) < 8.7) {
            vec2 raytraced_shadow = calc_raytraced_shadows(get_viewspace_position().xyz, lightVector);
            shadow_color = min(raytraced_shadow.xxx, shadow_color);
        }
        #endif

        return shadow_color;
    #endif
}

float luma(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec3 enhance(in vec3 color) {
	color *= vec3(0.85, 0.7, 1.2);

    vec3 intensity = vec3(luma(color));

    return mix(intensity, color, SKY_SATURATION);
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
            direction = -1 * normalize(direction) * RAY_STEP_LENGTH;
            forward = false;
        }
        direction *= RAY_GROWTH;
    }
    //If we're here, we couldn't find anything to reflect within the alloted number of steps
    return vec3(-1);
}

float get_emission(in vec2 coord) {
    return texture2D(gaux2, coord).r;
}

vec3 raytrace_light(in vec2 coord) {
	vec3 light = vec3(0);
	for(int i = 0; i < NUM_DIFFUSE_RAYS; i++) {
	    vec3 position_viewspace = get_viewspace_position(coord).xyz;
		vec3 normal = get_normal(coord);
		vec3 noise = get_3d_noise(coord * i);
		vec3 ray_direction = normalize(noise * 0.35 + normal);
		vec3 hit_uv = cast_screenspace_ray(position_viewspace, ray_direction);
		hit_uv.z *= 0.5;

		float ndotl = max(0, dot(normal, ray_direction));
		float falloff = max(1, pow(hit_uv.z, 1));
		float emission =  get_emission(hit_uv.st);
		light += texture2D(gcolor, hit_uv.st).rgb * emission * ndotl / falloff;
	}

	return light * 2 / float(NUM_DIFFUSE_RAYS);
}
#endif

void main() {
    vec3 gi = vec3(0);

	vec2 gi_coord = coord * 2.0;
	vec4 position_viewspace = get_viewspace_position(gi_coord);
	if(gi_coord.x < 1 && gi_coord.y < 1) {
	    vec3 normal = get_normal(gi_coord);
		gi = calculate_gi(gi_coord, position_viewspace, normal);

	} else if(gi_coord.x < 1 && gi_coord.y > 1) {
        position_viewspace = get_viewspace_position(gi_coord - vec2(0, 1));
        vec4 position_worldspace = gbufferModelViewInverse * position_viewspace;
        gi = calcShadowing(position_viewspace);
        //gi = position_viewspace.rgb;
    }

	#ifdef RAYTRACED_LIGHT
	else if(gi_coord.x > 1 && gi_coord.y < 1) {

		gi = raytrace_light(gi_coord - vec2(1, 0));
	}
	#endif

	vec3 sky_color = vec3(0);
	vec3 eye_vector = get_eye_vector(coord).xzy;
	sky_color += get_sky_color(eye_vector, normalize(sunPosition), SUNSPOT_BRIGHTNESS);	// scattering from sun
	sky_color += get_sky_color(eye_vector, normalize(moonPosition), MOONSPOT_BRIGHTNESS);		// scattering from moon
	//sky_color += calc_clouds(eye_vector) * SUNSPOT_BRIGHTNESS;

	sky_color = enhance(sky_color);

    gl_FragData[0] = vec4(gi, 1.0);
	gl_FragData[1] = vec4(sky_color, 1.0);
}
