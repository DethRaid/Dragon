#version 120

varying vec4 color;
varying vec2 uv;
varying vec3 normal;

void main() {
    color = gl_Color;
    uv = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
    normal = gl_Normal * gl_NormalMatrix;

    gl_Position = ftransform();
}
