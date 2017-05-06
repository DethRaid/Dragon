#version 450 compatibility

#include "/lib/space_conversion.glsl"
#include "/lib/sky.glsl"

#line 7

/*
 * Composite1
 *
 * Responsible for rendering clouds, GI, VL, and raytraced block lighting
 */

uniform vec3 shadowLightPosition;

uniform sampler2D colortex2;

out vec2 coord;
out vec2 sun_coord;
out vec3 light_direction_viewspace;
out vec3 light_color;

void main() {
    gl_Position = ftransform();
    coord = gl_MultiTexCoord0.st;
    
    light_direction_viewspace = normalize(shadowLightPosition);
    vec3 sun_direction_worldspace = normalize(viewspace_to_worldspace(vec4(shadowLightPosition, 0)).xyz);
    sun_coord = get_sky_coord(sun_direction_worldspace);
    light_color = texture(colortex2, sun_coord).rgb;
}
