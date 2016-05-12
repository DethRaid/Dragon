#version 120

uniform sampler2D texture;

varying vec4 color;
varying vec2 uv;
varying vec3 normal;

void main() {
    gl_FragData[0] = color * texture2D(texture, uv);
    gl_FragData[5] = vec4(0.0, 0.0, 0.0, 0.1);
    gl_FragData[6] = vec4(0.0, 0.0, 0.0, 0.0);
    gl_FragData[7] = vec4(normalize(normal), 1.0);
}
