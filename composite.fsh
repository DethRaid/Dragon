#version 120

uniform sampler2D gcolor;

varying vec2 coord;

void main() {
    gl_FragData[3] = texture2D( gcolor, coord );
}
