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

varying vec3 normal;
varying mat3 normalMatrix;
varying float isWater;

void main() {
    color = gl_Color;

    uv = gl_MultiTexCoord0.st;
    uvLight = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;

    if(mc_Entity.x == 8 || mc_Entity.x == 9) {
        isWater = 1.0;
    }

    vec4 position = gl_ModelViewMatrix * gl_Vertex;
    vec4 viewPos = gbufferModelViewInverse * position;
    vec3 worldPos = viewPos.xyz + cameraPosition;
    pos = worldPos;

    gl_Position = gl_ProjectionMatrix * (gbufferModelView * viewPos);

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
}
