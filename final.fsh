#version 120

uniform sampler2D composite;

varying vec2 coord;

void main() {
    gl_FragColor = texture2D( composite, coord );
}
