#version 120

uniform sampler2D diffuse;
uniform sampler2D lightmap;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

void main() {
    gl_FragData[0] = color * texture2D( diffuse, uv );
    gl_FragData[1] = vec4( 1, texture2D( lightmap, uvLight ).r, 0, 1 );
}
