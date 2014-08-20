#version 120

uniform sampler2D gaux1;

varying vec2 coord;

void main() {
    gl_FragColor = texture2D( gaux1, coord );
}
