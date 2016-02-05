#version 120

varying vec4 color;
varying vec2 uv;

void main() {
    gl_Position = ftransform();

    uv = gl_MultiTexCoord0.st;
    color = gl_Color;
}
