#version 120
#extension GL_ARB_shader_texture_lod : enable

/*!
 * \brief Computes GI, storing it to a single buffer
 */

// GI variables
#define GI_SAMPLE_RADIUS 35
#define GI_QUALITY 203

// Sky parameters
#define RAYLEIGH_BRIGHTNESS			33
#define MIE_BRIGHTNESS 				100
#define MIE_DISTRIBUTION 			63
#define STEP_COUNT 					15.0
#define SCATTER_STRENGTH			28
#define INTENSITY					1.8
#define RAYLEIGH_STRENGTH			139
#define MIE_STRENGTH				264
#define RAYLEIGH_COLLECTION_POWER	1
#define MIE_COLLECTION_POWER		1

#define SUNSPOT_BRIGHTNESS			1000

#define SURFACE_HEIGHT				0.99

#define PI 3.14159

const int RGB16F					= 0;

const int   shadowMapResolution     = 4096;
const float shadowDistance          = 120.0;
const bool  generateShadowMipmap    = false;
const float shadowIntervalSize      = 4.0;
const bool  shadowHardwareFiltering = false;
const bool  shadowtexNearest        = true;

const int   noiseTextureResolution  = 64;
const int 	gaux3format				= RGB16F;

uniform sampler2D gdepthtex;
uniform sampler2D colortex2;

uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor;
uniform sampler2D shadowcolor1;

uniform sampler2D noisetex;

uniform float viewWidth;
uniform float viewHeight;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

varying vec2 coord;
varying vec3 lightVector;
varying vec3 lightColor;
varying vec3 ambientColor;

varying vec3 fogColor;
varying vec3 skyColor;

/* DRAWBUFFERS:76 */

vec3 get_normal(in vec2 coord) {
	return texture2DLod(colortex2, coord, 0).xyz * 2.0 - 1.0;
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

    return texture2D(noisetex, coord).xyz;
}

/*
 * Global Illumination
 *
 * Calculates bounces diffuse light
 */

vec3 calculate_gi(in vec2 coord, in vec4 position_viewspace, in vec3 normal) {
 	float NdotL = dot(normal, lightVector);

 	vec3 normal_shadowspace = (shadowModelView * gbufferModelViewInverse * vec4(normal, 0.0)).xyz;

 	vec4 position = viewspace_to_worldspace(position_viewspace);
 		 position = worldspace_to_shadowspace(position);
 		 position = position * 0.5 + 0.5;

 	float fademult 	= 0.15;

 	vec3 light = vec3(0.0);
 	int samples	= 0;

 	for(int i = 0; i < GI_QUALITY; i++) {
 		float percentage_done = float(i) / float(GI_QUALITY);
 		float dist_from_center = GI_SAMPLE_RADIUS * percentage_done;

 		float theta = percentage_done * (GI_QUALITY / 16) * PI;
 		vec2 offset = vec2(cos(theta), sin(theta)) * dist_from_center;
 		offset += get_3d_noise(coord * 1.3).xy * 3;
 		offset /= shadowMapResolution;

 		vec3 sample_pos = vec3(position.xy + offset, 0.0);
 		sample_pos.z	= texture2DLod(shadowtex1, sample_pos.st, 0.0).x;

 		vec3 sample_dir      = normalize(sample_pos.xyz - position.xyz);
 		vec3 normal_shadow	 = texture2DLod(shadowcolor1, sample_pos.st, 0).xyz * 2.0 - 1.0;

        vec3 light_strength              = lightColor * max(0, dot(normal_shadow, vec3(0, 0, 1)));
 		float received_light_strength	 = max(0.0, dot(normal_shadowspace, -sample_dir));
 		float transmitted_light_strength = max(0.0, dot(normal_shadow, sample_dir));

 		float falloff = length(sample_pos.xyz - position.xyz) * 50;
        falloff = pow(falloff, 4);
		falloff = max(1.0, falloff);

 		vec3 sample_color = pow(texture2DLod(shadowcolor, sample_pos.st, 0.0).rgb, vec3(2.2));
        vec3 flux = sample_color * light_strength;

 		light += flux * transmitted_light_strength * received_light_strength / falloff;
        //light += flux * received_light_strength;
 	}

 	light /= GI_QUALITY;

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

	return vec3(cos_lat * cos_long, cos_lat * sin_long, sin_lat);
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

    if(length(near) < radius) {
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
vec3 get_sky_color(in vec2 coord) {
	vec3 eye_vector = get_eye_vector(coord).xzy;

	vec3 light_vector_worldspace = normalize(viewspace_to_worldspace(vec4(lightVector, 0.0)).xyz);

	float alpha = max(dot(eye_vector, light_vector_worldspace), 0.0);

	float rayleigh_factor = phase(alpha, -0.01) * RAYLEIGH_BRIGHTNESS;
	float mie_factor = phase(alpha, MIE_DISTRIBUTION) * MIE_BRIGHTNESS;
	float spot = smoothstep(0.0, 15.0, phase(alpha, 0.9995)) * SUNSPOT_BRIGHTNESS;

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

		vec3 influx = absorb(sample_depth, vec3(INTENSITY), SCATTER_STRENGTH) * extinction;
		rayleigh_collected += max(absorb(sample_distance, Kr * influx, RAYLEIGH_STRENGTH), 0.0);
		mie_collected += absorb(sample_distance, influx, MIE_STRENGTH);
	}

	rayleigh_collected = (rayleigh_collected * eye_extinction * pow(eye_depth, RAYLEIGH_COLLECTION_POWER)) / float(STEP_COUNT);
	mie_collected = (mie_collected * eye_extinction * pow(eye_depth, MIE_COLLECTION_POWER)) / float(STEP_COUNT);

	vec3 color = (spot * mie_collected) + (mie_factor * mie_collected * 0) + (rayleigh_factor * rayleigh_collected);

	return (color);
}

void main() {
    vec4 position_viewspace = get_viewspace_position(coord);
    vec3 normal = get_normal(coord);

    vec3 gi = calculate_gi(coord, position_viewspace, normal);

	vec3 sky_color = get_sky_color(coord);

    gl_FragData[0] = vec4(pow(gi, vec3(1 / 2.2)), 1.0);
	gl_FragData[1] = vec4(sky_color, 1.0);
}
