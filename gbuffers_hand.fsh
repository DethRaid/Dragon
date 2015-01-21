#version 120

uniform sampler2D texture;

varying vec4 color;
varying vec2 uv;
varying vec3 normal;

void main() {
    gl_FragData[0] = color * texture2D( texture, uv );
    gl_FragData[1] = vec4( normal, gl_FragCoord.z );
    gl_FragData[4] = vec4( 0.0, 1.0, 0.0, 1.0 );
    gl_FragData[5] = vec4( 0.0, 0.0, 1.0, 1.0 );
    gl_FragData[6] = vec4( 0.0, 0.0, 0.0, 1.0 );
}
