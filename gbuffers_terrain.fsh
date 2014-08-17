#version 120

uniform sampler2D texture;
uniform sampler2D lightmap;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 normal;
varying mat3 tbnMatrix;

void main() {
    gl_FragData[0] = texture2D( texture, uv ) * color;
    gl_FragData[1] = vec4( 0, texture2D( lightmap, uvLight ).r, 0, 1 );
    gl_FragData[2] = vec4( normal, 1 );
}
