#version 120

uniform sampler2D texture;
uniform sampler2D lightmap;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

void main() {
    gl_FragData[0] = texture2D( texture, uv ) * color;
    gl_FragData[1] = vec4( 0, texture2D( lightmap, uv ).r, 0, 1 );
}
