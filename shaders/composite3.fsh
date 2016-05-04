#version 130

#define OFF 0
#define ON 1

#define FILTER_REFLECTIONS OFF
#define REFLECTION_FILTER_SIZE 2

uniform sampler2D gcolor;
uniform sampler2D gdepthtex;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux2;
uniform sampler2D gaux4;

uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float near;

uniform mat4 gbufferProjectionInverse;

varying vec2 coord;

/* DRAWBUFFERS:0 */

float getSmoothness(in vec2 coord) {
    return texture2D(gaux2, coord).a;
}

float getDepth(vec2 coord) {
    return texture2D(gdepthtex, coord).r;
}

vec3 getCameraSpacePosition(vec2 uv) {
	float depth = getDepth(uv);
	vec4 fragposition = gbufferProjectionInverse * vec4(uv.s * 2.0 - 1.0, uv.t * 2.0 - 1.0, 2.0 * depth - 1.0, 1.0);
		 fragposition /= fragposition.w;
	return fragposition.xyz;
}

float getDepthLinear(in sampler2D depthtex, in vec2 coord) {
    return 2.0 * near * far / (far + near - (2.0 * texture2D(depthtex, coord).r - 1.0) * (far - near));
}

float getDepthLinear(vec2 coord) {
    return getDepthLinear(gdepthtex, coord);
}

vec3 get_specular_color(in vec2 coord) {
    return texture2D(gcolor, coord).rgb;
}

float getMetalness(in vec2 coord) {
    return texture2D(gaux2, coord).b;
}

vec3 getNormal(in vec2 coord) {
    return normalize(texture2D(gaux4, coord).xyz * 2.0 - 1.0);
}

bool shouldSkipLighting(in vec2 coord) {
    return texture2D(gaux2, coord).r > 0.5;
}

vec3 get_reflection(in vec2 sample_coord) {
#if FILTER_REFLECTIONS == ON
	vec2 recipres = vec2(1.0f / viewWidth, 1.0f / viewHeight);
    float depth = getDepthLinear(sample_coord);
    vec3 normal = getNormal(sample_coord);
    float roughness = 1.0 - getSmoothness(coord);
    roughness = pow(roughness, 4);
    float roughness_fac = mix(0.5, 1, roughness);

	vec4 light = vec4(0.0f);
	float weights = 0.0f;

    vec2 max_pos = vec2(REFLECTION_FILTER_SIZE) * recipres * 2;
    float max_len = sqrt(dot(max_pos, max_pos));

	for(float i = -REFLECTION_FILTER_SIZE; i <= REFLECTION_FILTER_SIZE; i += 1.0f) {
		for(float j = -REFLECTION_FILTER_SIZE; j <= REFLECTION_FILTER_SIZE; j += 1.0f) {
			vec2 offset = vec2(i, j) * recipres * roughness_fac * 2;

            float dist_factor =  max_len - sqrt(dot(offset, offset));
            dist_factor /= max_len;

			float sampleDepth = getDepthLinear(sample_coord + offset * 2.0f);
			vec3 sampleNormal = getNormal(sample_coord + offset * 2.0f);
			float weight = clamp(1.0f - abs(sampleDepth - depth) / 2.0f, 0.0f, 1.0f);
			weight *= max(0.0f, dot(sampleNormal, normal));
            weight *= mix(0, 0.05, dist_factor);

			light += max(texture2DLod(gdepth, sample_coord + offset, 1), vec4(0)) * weight;
			weights += weight;
		}
	}

	light /= max(0.00001f, weights);

#else
    vec4 light = texture2D(gdepth, sample_coord);

#endif

	return light.rgb;
}

float luma(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

void main() {
    vec3 diffuse = texture2D(composite, coord).rgb;
    vec3 specular = get_reflection(coord);

    float smoothness = getSmoothness(coord);
    float metalness = getMetalness(coord);
    vec3 viewVector = normalize(getCameraSpacePosition(coord));
    vec3 normal = getNormal(coord);

    float vdoth = clamp(dot(-viewVector, normal), 0, 1);

    vec3 sColor = mix(vec3(0.14), get_specular_color(coord), vec3(metalness));
    vec3 fresnel = sColor + (vec3(1.0) - sColor) * pow(1.0 - vdoth, 5);

    if(shouldSkipLighting(coord)) {
        fresnel = vec3(0);
    }

    vec3 color = mix(diffuse, specular, fresnel * smoothness);

    color = max(color, vec3(0));

    gl_FragData[0] = vec4(color, 1.0);
}
