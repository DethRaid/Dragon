#version 120

uniform sampler2D diffuse;
uniform sampler2D lightmap;
uniform sampler2D noisetex;

uniform float frameTimeCounter;

uniform mat4 gbufferModelView;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 pos;

varying vec3 normal;
varying vec3 normal_raw;
varying mat3 normalMatrix;

vec3 getWaves( float windStrength ) {
    float waveTime = frameTimeCounter;
    float sharpness = 0.2;
    float amplitude = 0.01;
    float w = 10;
    vec2 direction = vec2( 10, 10 );

    float wa = w * amplitude;
    float qi = sharpness / (amplitude * wa);
    float s = sin( dot( w * direction, pos.xz ) + waveTime );
    float c = cos( dot( w * direction, pos.xz ) + waveTime );
    s = sin( waveTime );
    c = cos( waveTime );

    vec3 normalOut = vec3( 0 );
    normalOut.x += direction.x * wa * c;
    normalOut.y += qi * wa * s;
    normalOut.z += direction.y * wa * c;

    normalOut.xz *= -1;
    normalOut.y = 1.0 - normalOut.y;

    return normalOut;
}

void main() {
    mat3 nMat = mat3( gbufferModelView );

    vec3 wNormal = getWaves( 0.1 ) * 2.0 - 1.0;
    wNormal = normalMatrix * normal_raw;
    
    gl_FragData[0] = color * texture2D( diffuse, uv );
    gl_FragData[5] = vec4( 0, texture2D( lightmap, uvLight ).r, 0, 1 );
    gl_FragData[2] = vec4( normal * 0.5 + 0.5, 1.0 );
    //gl_FragData[0] = vec4( normal, 1 );
}
