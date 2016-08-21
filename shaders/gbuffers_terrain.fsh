#version 450 compatibility

uniform sampler2D texture;
uniform sampler2D normals;

in vec4 color;
in vec2 uv;
in mat3 tbn_matrix;

void main() {
    vec4 texcolor = texture2D(texture, uv) * color;

    vec3 texnormal = texture2D(normals, uv).xyz * 2.0 - 1.0;
    texnormal = normalize(tbn_matrix * texnormal);

    gl_FragData[4] = texcolor;
    gl_FragData[6] = vec4(texnormal * 0.5 + 0.5, 1.0);
}
