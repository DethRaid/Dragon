#version 120

#define PI 3.14159265

uniform sampler2D diffuse;
uniform sampler2D lightmap;

uniform float frameTimeCounter;

uniform mat4 gbufferModelView;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 pos;
varying float depth;

varying vec3 normal;
varying mat3 normalMatrix;
varying float isWater;
varying float windSpeed;

// Taken from chociaptic13's shaderpack. See vertex shader for download location
vec3 getWaveNormal() {
    vec3 posxz = pos;
    posxz.x += sin( posxz.z + frameTimeCounter ) * 0.2;
    posxz.z += cos( posxz.x + frameTimeCounter * 0.5 ) * 0.2;

    float wave = 0.005 * sin( 2 * PI * (frameTimeCounter + posxz.x * 0.2 + posxz.z) )
               + 0.005 * sin( 2 * PI * (frameTimeCounter * 1.2 + posxz.x * 0.1 + posxz.z) );

    vec3 newNormal = vec3( sin( wave * PI ), 1.0 - cos( wave * PI ), wave );
    float bumpMult = 0.5;
    return newNormal * vec3( bumpMult ) + vec3( 0.0, 0.0, 1.0 - bumpMult );
}

void main() {
    mat3 nMat = mat3( gbufferModelView );

    vec3 wNormal = normal;
    vec4 matColor = color * texture2D( diffuse, uv ) * texture2D( lightmap, uv ).r;

    if( isWater > 0.9 ) {
        wNormal = getWaveNormal();
        wNormal = wNormal * normalMatrix;
       // matColor = vec4( 0.0, 0.412, 0.58, 0.11 );
    }
    
    gl_FragData[0] = matColor;
    //Save the water's depth in the green channel of texture 1
    //Use alpha blending to save both the water's depth and the terrain's depth
    gl_FragData[1] = vec4( 0, gl_FragCoord.z * 2.0, 0, 0.5 );
    gl_FragData[5] = vec4( 0, texture2D( lightmap, uvLight ).r, 0, 0.99 );
    gl_FragData[2] = vec4( wNormal * 0.5 + 0.5, 1.0 ); 
}
