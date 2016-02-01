#version 120

uniform int worldTime;

varying vec2 coord;
varying float floatTime;

void main() {
    gl_Position = ftransform();
    coord = gl_MultiTexCoord0.st;
    floatTime = float( worldTime ) / 24000.0;
}
