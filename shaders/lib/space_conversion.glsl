#ifndef SPACE_CONVERSION_GLSL
#define SPACE_CONVERSION_GLSL

#line 1005

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

uniform float viewWidth;
uniform float viewHeight;

/*!
 * \brief A bunch of functions to convert between spaces
 */

vec4 get_viewspace_position(in vec2 coord, in float depth) {
    vec4 pos = gbufferProjectionInverse * vec4(vec3(coord.st, depth) * 2.0 - 1.0, 1.0);
	return pos / pos.w;
}

vec4 viewspace_to_worldspace(in vec4 position_viewspace) {
	vec4 pos = gbufferModelViewInverse * position_viewspace;
    pos.xyz += cameraPosition;
	return pos;
}

#endif
