#version 450 compatibility

#include "/lib/space_conversion.glsl"

#line 6

/*
 * Composite1
 *
 * Responsible for rendering clouds, GI, VL, and raytraced block lighting
 */

uniform vec3 sunPosition; 

out vec2 coord;
out vec3 sun_direction_worldspace;

void main() {
    gl_Position = ftransform();
    coord = gl_MultiTexCoord0.st;
    
    sun_direction_worldspace = normalize(viewspace_to_worldspace(vec4(sunPosition, 0)).xyz);
}
