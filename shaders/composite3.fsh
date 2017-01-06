#version 120
#extension GL_ARB_shader_texture_lod : enable

#define OFF 0
#define ON 1

//#define FILTER_REFLECTIONS
#define REFLECTION_FILTER_SIZE 2

uniform sampler2D gdepthtex;
uniform sampler2D gdepth;
uniform sampler2D gaux2;
uniform sampler2D gaux4;

uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float near;

uniform mat4 gbufferProjectionInverse;

varying vec2 coord;

varying vec2 reflection_filter_coords[REFLECTION_FILTER_SIZE * REFLECTION_FILTER_SIZE];

// TODO: Ensure that this is always 0
/* DRAWBUFFERS:0 */

float getSmoothness(in vec2 coord) {
    return texture2D(gaux2, coord).a;
}

float getDepth(vec2 coord) {
    return texture2D(gdepthtex, coord).r;
}

float getDepthLinear(in sampler2D depthtex, in vec2 coord) {
    return 2.0 * near * far / (far + near - (2.0 * texture2D(depthtex, coord).r - 1.0) * (far - near));
}

float getDepthLinear(vec2 coord) {
    return getDepthLinear(gdepthtex, coord);
}

float getMetalness(in vec2 coord) {
    return texture2D(gaux2, coord).b;
}

vec3 getNormal(in vec2 coord) {
    return normalize(texture2D(gaux4, coord).xyz * 2.0 - 1.0);
}

vec3 get_reflection(in vec2 sample_coord) {
#ifdef FILTER_REFLECTIONS
	vec2 recipres = vec2(1.0f / viewWidth, 1.0f / viewHeight);
    float depth = getDepthLinear(sample_coord);
    vec3 normal = getNormal(sample_coord);
    float roughness = 1.0 - getSmoothness(coord);

	vec4 light = vec4(0.0f);
	float weights = 0.0f;

    vec2 max_pos = vec2(REFLECTION_FILTER_SIZE) * recipres * 0.5;
    float max_len = sqrt(dot(max_pos, max_pos));

	for(float i = -REFLECTION_FILTER_SIZE; i <= REFLECTION_FILTER_SIZE; i += 1.0f) {
		for(float j = -REFLECTION_FILTER_SIZE; j <= REFLECTION_FILTER_SIZE; j += 1.0f) {
			vec2 offset = vec2(i, j) * recipres * roughness;

            float dist_factor = max(0, max_len - sqrt(dot(offset, offset)));
            dist_factor /= max_len;

			float sampleDepth = getDepthLinear(sample_coord + offset * 2.0f);
			vec3 sampleNormal = getNormal(sample_coord + offset * 2.0f);
			float weight = clamp(1.0f - abs(sampleDepth - depth) / 2.0f, 0.0f, 1.0f);
			weight *= max(0.0f, dot(sampleNormal, normal));
            weight *= dist_factor;

			light += max(texture2DLod(gdepth, (sample_coord + offset), 0), vec4(0)) * weight;
			weights += weight;
		}
	}

	light /= max(0.00001f, weights);

#else
    vec4 light = texture2D(gdepth, sample_coord);

#endif

	return light.rgb;
}

void main() {
    vec3 color = get_reflection(coord);
    color = max(color, vec3(0));

    gl_FragData[0] = vec4(color, 1.0);
}
