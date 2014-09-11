#version 120

uniform sampler2D diffuse;
uniform sampler2D lightmap;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 normal;

void main() {
    gl_FragData[0] = color * texture2D( diffuse, uv );
    gl_FragData[5] = vec4( 0, texture2D( lightmap, uvLight ).r, 1, gl_FragCoord.z / gl_FragCoord.w );
    gl_FragData[2] = vec4( normal * 0.5 + 0.5, 1 );
}
