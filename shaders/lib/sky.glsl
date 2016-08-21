#ifndef SKY_GLSL
#define SKY_GLSL

#include "/lib/space_conversion.glsl"

#line 4007

/*!
 * \brief A collection of function to calculate the sky
 *
 * Taken from http://codeflow.org/entries/2011/apr/13/advanced-webgl-part-2-sky-rendering/
 */

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

float phase(float alpha, float g) {
	float a = 3.0 * (1.0 - g * g);
	float b = 2.0 * (2.0 + g * g);
    float c = 1.0 + alpha * alpha;
    float d = pow(1.0 + g * g - 2.0 * g * alpha, 1.5);
    return (a / b) * (c / d);
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

vec3 worldspace_to_skyspace(in vec3 worldspace_position) {
    return vec3(0.0, worldspace_position.y * 0.00390625 + SURFACE_HEIGHT, 0.0);
}

vec3 Kr = vec3(0.18867780436772762, 0.4978442963618773, 0.6616065586417131);	// Color of nitrogen

vec3 absorb(float dist, vec3 color, float factor) {
	return color - color * pow(Kr, vec3(factor / dist));
}

float luma(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec3 enhance(in vec3 color) {
	color *= vec3(0.85, 0.7, 1.2);

    vec3 intensity = vec3(luma(color));

    return mix(intensity, color, SKY_SATURATION);
}

#endif
