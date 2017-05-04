#ifndef SPACE_CONVERSION_GLSL
#define SPACE_CONVERSION_GLSL

#line 1005

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

uniform float viewWidth;
uniform float viewHeight;

uniform float near;
uniform float far;

/*!
 * \brief A bunch of functions to convert between spaces
 */

float exp_to_linear_depth(in float depth_value) {
    return 2.0 * near * far / (far + near - (2.0 * depth_value - 1.0) * (far - near));
}

vec4 get_viewspace_position(in vec2 coord, in float depth) {
    vec4 pos = gbufferProjectionInverse * vec4(vec3(coord.st, depth) * 2.0 - 1.0, 1.0);
	return pos / pos.w;
}

vec4 viewspace_to_worldspace(in vec4 position_viewspace) {
	vec4 pos = gbufferModelViewInverse * position_viewspace;
    pos.xyz += cameraPosition;
	return pos;
}

vec2 get_coord_from_viewspace(in vec4 position) {
    vec4 ndc_position = gbufferProjection * position;
    ndc_position /= ndc_position.w;
    return ndc_position.xy * 0.5 + 0.5;
}

#endif
