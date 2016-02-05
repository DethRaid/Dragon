#version 120

uniform sampler2D tex;

varying vec4 color;
varying vec2 uv;

void main() {
    gl_FragData[0] = texture2D(tex, uv) * color;
}
