#version 120

uniform sampler2D texture;
uniform sampler2D lightmap;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 normal;

void main() {
    gl_FragData[0] = texture2D( texture, uv ) * color;
    gl_FragData[1] = vec4( normal, gl_FragCoord.z );
    gl_FragData[4] = vec4( 0.5, 0.5, 0.0, 1.0 );
    gl_FragData[5] = vec4( uvLight.r, uvLight.g, 0.0, 1.0 );
    gl_FragData[6] = vec4( 0.0, 0.0, 0.0, 1.0 );
}
