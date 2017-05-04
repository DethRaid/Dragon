#version 450 compatibility

#define PI 3.14159265

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform float viewWidth;
uniform float viewHeight;

uniform float near;
uniform float far; 

uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;

in vec4 color;
in vec2 uv;
in mat3 tbn_matrix;
in vec3 eye_vector;
in float is_lava;

void main() {
    vec4 texcolor = texture2D(texture, uv) * color;

    vec3 texnormal = texture2D(normals, uv).xyz * 2.0 - 1.0;
    texnormal = normalize(tbn_matrix * texnormal);

    vec4 specdata = texture2D(specular, uv);

    gl_FragData[4] = texcolor;
    gl_FragData[5] = vec4(specdata.rg, is_lava, 1);
    gl_FragData[6] = vec4(texnormal * 0.5 + 0.5, 1.0);
}
