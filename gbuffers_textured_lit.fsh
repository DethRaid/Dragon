#version 120

uniform sampler2D diffuse;
uniform sampler2D lightmap;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

void main() {
    gl_FragData[0] = color * texture2D( diffuse, uv ) * texture2D( lightmap, uvLight ).r;
}
