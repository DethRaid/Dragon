#version 120

varying vec4 color;

void main() {
    gl_FragData[0] = color;
}
