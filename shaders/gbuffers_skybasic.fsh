#version 120

varying vec4 color;

void main() {
    gl_FragData[0] = color;
    gl_FragData[6] = vec4(1.0, 1.0, 1.0, 0.0);
    gl_FragData[5] = vec4(1, 0, 0, 1);
}
