#version 120

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 normal;

void main() {
    color = gl_Color;
    uv = gl_MultiTexCoord0.st;
    uvLight = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;

    gl_Position = ftransform();

    normal = gl_NormalMatrix * gl_Normal;
}
