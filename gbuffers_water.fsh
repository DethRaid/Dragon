#version 120

uniform sampler2D diffuse;
uniform sampler2D lightmap;
uniform sampler2D noisetex;

uniform float frameTimeCounter;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 worldPos;

varying vec3 normal;
varying mat3 normalMatrix;

vec3 getWaves() {
    vec3 wave = vec3( 0, 1, 0 );
    
    //Wave 1
    vec2 waveSpeed = vec2( 0.05, 0.00 );
    vec2 waveScale = vec2( 0.05, 0.01 );
    vec2 waveSamplePos = worldPos.xz * waveScale + waveSpeed * frameTimeCounter;    
    vec3 waveSample = normalize( texture2D( noisetex, waveSamplePos ).xyz * 2.0 + 1.0 );
    
    //Wave 2
    /*waveSpeed = vec2( 0.05, 0.005 );
    waveScale = vec2( 0.05, 0.00075 );
    waveSamplePos = worldPos.xz * waveScale + waveSpeed * frameTimeCounter;
    waveSample += (texture2D( noisetex, waveSamplePos ).xyz * 2.0 + 1.0) * 0.5;
    
    waveSpeed = vec2( 0.05, 0.025 );
    waveScale = vec2( 0.0095, 0.0000025 );
    waveSamplePos = worldPos.xz * waveScale + waveSpeed * frameTimeCounter;
    waveSample += (texture2D( noisetex, waveSamplePos ).xyz * 2.0 + 1.0) * 0.75;*/
    
    waveSample.y = 0;
    waveSample = normalize( waveSample );
    
    return normalize( wave + waveSample );
}

void main() {
    vec3 wNormal = getWaves();
    wNormal = normalize( wNormal * normalMatrix );
    
    gl_FragData[0] = color * texture2D( diffuse, uv );
    gl_FragData[5] = vec4( 0, texture2D( lightmap, uvLight ).r, 0, 1 );
    gl_FragData[2] = vec4( normal * 0.5 + 0.5, 1.0 );
    //gl_FragData[0] = vec4( wNormal, 1 );
}
