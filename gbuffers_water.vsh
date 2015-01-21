#version 120

#define PI 3.14159265

attribute vec4 mc_Entity;

uniform float frameTimeCounter;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;
varying vec3 pos;

varying float depth;

varying vec3 normal;
varying mat3 normalMatrix;
varying float windSpeed;
varying float isWater;

float rand( in vec2 coord ) {
    return fract( sin( dot( coord, vec2( 12.9898, 7.2534 ) ) ) * 41632.34 );
}

void calcWindSpeed( in vec2 coord ) {
    vec2 windTime = vec2( frameTimeCounter );
    vec2 windOffset = windTime * vec2( 0.5, 0.2 );

    coord += vec2( frameTimeCounter );

    vec2 wc1 = coord * 0.025;
    wc1 -= fract( wc1 );
    vec2 wc2 = coord * 0.05;
    wc2 -= fract( wc2 );
    vec2 wc3 = coord * 0.1;
    wc3 -= fract( wc3 );
    vec2 wc4 = coord * 0.2;
    wc4 -= fract( wc4 );

    windSpeed = 0.5 * rand( wc1 ) + 0.25 * rand( wc2 ) + 0.125 * rand( wc3 ) + 0.0625 * rand( wc4 );
}

// Wave code from chocapic13's shaderpack
// modified by DethRaid to incorporate dynamic wind speeds
float getDisplacement( in vec3 worldPos ) {
    float fy = fract( worldPos.y + 0.001 );
    float wTime = frameTimeCounter;

    float amplitude = 0.05;

    if( fy > 0.002 ) {
        float wave = amplitude * sin( 2 * PI * (wTime * 0.75 + worldPos.x / 7.0 + worldPos.z / 13.0) )
                   + amplitude * sin( 2 * PI * (wTime * 0.6 + worldPos.x / 11.0 + worldPos.z / 5.0) );
        return clamp( wave, -fy, 1.0 - fy );
    }
    return 0.0;
}

void main() {
    color = gl_Color;

    uv = gl_MultiTexCoord0.st;
    uvLight = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;

    //Water position determination comes from chocapic13's shaderpack, available from
    //http://www.minecraftforum.net/forums/mapping-and-modding/minecraft-mods/1293898-chocapic13s-shaders
    vec4 position = gl_ModelViewMatrix * gl_Vertex;
    vec4 viewPos = gbufferModelViewInverse * position;
    vec3 worldPos = viewPos.xyz + cameraPosition;
    pos = worldPos;

    float displacement = 0;
    if( mc_Entity.x == 8.0 || mc_Entity.x == 9.0 ) {
        isWater = 1.0;
        calcWindSpeed( worldPos.xz );
        displacement = getDisplacement( worldPos );
        viewPos.y += displacement;
    }

    gl_Position = gl_ProjectionMatrix * (gbufferModelView * viewPos);
    depth = gl_Position.z;

    vec3 tangent = vec3( 0 );
    vec3 binormal = vec3( 0 );
    normal = normalize( gl_NormalMatrix * gl_Normal );

    if( gl_Normal.x > 0.5 ) {
        tangent = vec3( 0.0, 0.0, -1.0 );
    } else if( gl_Normal.x < -0.5 ) {
        tangent = vec3( 0.0, 0.0, 1.0 );
    } else if( gl_Normal.y > 0.5 ) {
        tangent = vec3( 1.0, 0.0, 0.0 );
    } else if( gl_Normal.y < -0.5 ) {
        tangent = vec3( 1.0, 0.0, 0.0 );
    } else if( gl_Normal.z > 0.5 ) {
        tangent = vec3( 1.0, 0.0, 0.0 );
    } else if( gl_Normal.z < -0.5 ) {
        tangent = vec3( -1.0, 0.0, 0.0 );
    }

    binormal = cross( normal, tangent );

    normalMatrix = mat3( tangent.x, binormal.x, normal.x,
                         tangent.y, binormal.y, normal.y,
                         tangent.z, binormal.z, normal.z );

    if( isWater > 0.9 ) {
        vec3 newNormal = vec3( sin( displacement * PI ), 1.0 - cos( displacement * PI ), displacement );

        float bumpMult = 0.05;
        newNormal = newNormal * vec3( bumpMult ) + vec3( 0.0, 0.0, 1.0 - bumpMult );

        normal = newNormal * normalMatrix;
    }
}
