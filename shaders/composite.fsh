#version 120
#extension GL_ARB_shader_texture_lod : enable

/*!
 * \brief Computes GI and the skybox
 */

#define GLOBAL_ILLUMINATION

// GI variables
#define GI_SAMPLE_RADIUS 7.5
#define GI_QUALITY 2	// [2 4 8 16]

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

#define SUNSPOT_BRIGHTNESS			1000
#define MOONSPOT_BRIGHTNESS			25

#define SKY_SATURATION				1.5

#define SURFACE_HEIGHT				0.98

#define CLOUDS_START 				512

#define PI 3.14159

const int RGB32F					= 0;
const int RGB16F					= 1;

const int   shadowMapResolution     = 4096;	// [1024 2048 4096]
const float shadowDistance          = 120.0;
const bool  generateShadowMipmap    = false;
const float shadowIntervalSize      = 4.0;
const bool  shadowHardwareFiltering = false;
const bool  shadowtexNearest        = true;
const float	sunPathRotation 		= -40.0f;

const int   noiseTextureResolution  = 64;
const int	gcolorFormat			= RGB32F;
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
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjectionInverse;

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

// TODO: 12
/* DRAWBUFFERS:12 */

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

vec3 get_3d_noise(in vec2 coord) {
    coord *= vec2(viewWidth, viewHeight);
    coord /= noiseTextureResolution;

    return texture2D(noisetex, coord).xyz * 2.0 - 1.0;
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

float luma(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}


vec3 enhance(in vec3 color) {
	color *= vec3(0.525, 0.7, 1.175);

    vec3 intensity = vec3(luma(color));

    return mix(intensity, color, SKY_SATURATION);
}

void main() {
	vec3 sky_color = vec3(0);
	vec3 eye_vector = get_eye_vector(coord).xzy;
	sky_color += get_sky_color(eye_vector, normalize(sunPosition), SUNSPOT_BRIGHTNESS);	// scattering from sun
	sky_color += get_sky_color(eye_vector, normalize(moonPosition), MOONSPOT_BRIGHTNESS);		// scattering from moon

	sky_color = enhance(sky_color);

	gl_FragData[0] = vec4(sky_color, 1.0);
}
