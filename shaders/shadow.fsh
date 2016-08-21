#version 450 compatibility

#include "/lib/normalmapping.glsl"

#line 6

uniform sampler2D tex;
//uniform sampler2D normal;

in vec4 color;
in vec2 uv;
in mat3 tbn_matrix;
in vec3 normal;

void main() {
    vec4 frag_color = texture(tex, uv) * color;
    gl_FragData[0] = frag_color;

    //vec3 texnormal = texture(normal, uv).xyz * 2.0 - 1.0;
    //texnormal = normalize(tbn_matrix * texnormal);

    gl_FragData[1] = vec4(normal * 0.5 + 0.5, 1.0);
}
