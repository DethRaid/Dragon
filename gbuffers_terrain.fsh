#version 120

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D lightmap;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 normal;
varying mat3 tbnMatrix;

varying float smoothness_in;
varying float metalness_in;

varying float isEmissive;

void main() {
    //color
    vec4 texColor = texture2D( texture, uv );
    gl_FragData[0] = texture2D( texture, uv ) * color;
    
    vec3 sData = texture2D( specular, uv ).rgb;
    float gloss = sData.r;
    float emission = sData.g;
    float metalness = sData.b;
    
    //gloss = smoothness_in;
    //metalness - metalness_in;
    
    //gl_FragData[0] = vec4( vec3( gloss ), 1 );
    
    //skipLighting, torch lighting, isWater, smoothness
    gl_FragData[5] = vec4( emission, texture2D( lightmap, uvLight ).r, metalness, gloss );

    vec3 texnormal = texture2D( normals, uv ).xyz;
    texnormal = tbnMatrix * texnormal;
    //normal, metalness
    gl_FragData[2] = vec4( normal * 0.5 + 0.5, 0.0 );
}
