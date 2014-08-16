#version 120

uniform sampler2D diffuse;

varying vec4 color;
varying vec2 uv;

void main() {
    gl_FragData[0] = color * texture2D( diffuse, uv );
}
