#version 450

#include "/lib/sky.glsl"
#include "/lib/noise.glsl"
#include "/lib/shadow_functions.glsl"

#line 8

// TODO: 0
/* DRAWBUFFERS:0 */

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;

uniform sampler2D gdepthtex;

layout(location = 0) out vec3 diffuse_out;

in vec2 coord;
in vec2 sun_coord;
in vec3 light_direction_viewspace;

vec3 get_ambient_lighting(vec3 normal_worldspace) {
    vec3 ambient = vec3(0);
    ambient += texture(colortex2, get_sky_coord(vec3(1, 0, 0))).rgb * max(0, dot(normal_worldspace, vec3(1, 0, 0)));
    ambient += texture(colortex2, get_sky_coord(vec3(-1, 0, 0))).rgb * max(0, dot(normal_worldspace, vec3(-1, 0, 0)));
    ambient += texture(colortex2, get_sky_coord(vec3(0, 1, 0))).rgb * max(0, dot(normal_worldspace, vec3(0, 1, 0)));
    ambient += texture(colortex2, get_sky_coord(vec3(0, -1, 0))).rgb * max(0, dot(normal_worldspace, vec3(0, -1, 0)));
    ambient += texture(colortex2, get_sky_coord(vec3(0, 0, 1))).rgb * max(0, dot(normal_worldspace, vec3(0, 0, 1)));
    ambient += texture(colortex2, get_sky_coord(vec3(0, 0, -1))).rgb * max(0, dot(normal_worldspace, vec3(0, 0, -1)));

    return ambient * 0.1;
}

void main() {
    vec4 data = texture(colortex5, coord);
    if(data.z < 0.5) {

        vec3 albedo = texture(colortex4, coord).rgb;
        vec3 N = texture(colortex6, coord).xyz * 2.0 - 1.0;
        float ndotl = max(0, dot(N, light_direction_viewspace));

        vec3 light_color = texture(colortex2, sun_coord).rgb;

        float depth = texture(gdepthtex, coord).r;
        vec4 viewspace_position = get_viewspace_position(coord, depth);
        vec4 worldspace_position = viewspace_to_worldspace(viewspace_position);

        vec3 shadow_color = get_shadow_color(worldspace_position.xyz, coord);

        vec3 gi_color = texture(colortex1, coord * 0.5 + vec2(0.5, 0.0)).rgb;

        vec3 normal_worldspace = normalize(viewspace_to_worldspace(vec4(N, 0)).xyz);
        vec3 ambient_color = get_ambient_lighting(normal_worldspace);

        

        diffuse_out = albedo * ndotl * light_color * shadow_color + gi_color * light_color + ambient_color * albedo;
    } else {
        vec4 worldspace_position = viewspace_to_worldspace(viewspace_position);
        diffuse_out = 
    }
}
