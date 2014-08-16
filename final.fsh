#version 120

uniform sampler2D composite;

varying vec2 coord;

void main() {
    vec4 color = texture2D( composite, coord );
    color = color * color;
    gl_FragColor = color;
}
