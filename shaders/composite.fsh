#version 120
#extension GL_ARB_shader_texture_lod : enable

/*!
 * \brief Computes GI, storing it to a single buffer
 */

#define GI_SAMPLE_RADIUS 35
#define GI_QUALITY 303

#define PI 3.14159

const int   shadowMapResolution     = 4096;
const float shadowDistance          = 120.0;
const bool  generateShadowMipmap    = false;
const float shadowIntervalSize      = 4.0;
const bool  shadowHardwareFiltering = false;
const bool  shadowtexNearest        = true;

const int   noiseTextureResolution  = 64;

uniform sampler2D gdepthtex;
uniform sampler2D colortex2;

uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor;
uniform sampler2D shadowcolor1;

uniform sampler2D noisetex;

uniform float viewWidth;
uniform float viewHeight;

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

/* DRAWBUFFERS:7 */

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
	return pos / pos.w;
}

vec4 worldspace_to_shadowspace(in vec4 powition_worldspace) {
	vec4 pos = shadowProjection * shadowModelView * powition_worldspace;
	return pos /= pos.w;
}

vec3 get_3d_noise(in vec2 coord) {
    coord *= vec2(viewWidth, viewHeight);
    coord /= noiseTextureResolution;

    return texture2D(noisetex, coord).xyz;
}

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

void main() {
    vec4 position_viewspace = get_viewspace_position(coord);
    vec3 normal = get_normal(coord);

    vec3 gi = calculate_gi(coord, position_viewspace, normal);

    gl_FragData[0] = vec4(pow(gi, vec3(1 / 2.2)), 1.0);
}
