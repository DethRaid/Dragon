#version 120

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D lightmap;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 normal;
varying mat3 tbnMatrix;

void main() {
    //color
    gl_FragData[0] = texture2D( texture, uv ) * color;
    
    //isSky, torch lighting, isWater, smoothness
    gl_FragData[1] = vec4( 0, texture2D( lightmap, uvLight ).r, 0, 1 );

    vec3 texnormal = texture2D( normals, uv ).xyz;
    texnormal = tbnMatrix * texnormal;
    //normal, reflectivity
    gl_FragData[2] = vec4( normal * 0.5 + 0.5, 1 );
}
