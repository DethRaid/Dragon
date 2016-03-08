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

    isWater = 0.0;
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
    //We're working in a cube world. If one component of the normal is
    //greater than all the others, we know what direction the surface is
    //facing in
    if( gl_Normal.x > 0.5 ) {
        tangent  = vec3( 0,  0, 1 );
        binormal = cross(  gl_Normal, tangent );
    } else if( gl_Normal.x < -0.5 ) {
        tangent  = vec3( 0,  0, 1 );
        binormal = cross(  gl_Normal, tangent );
    } else if( gl_Normal.y > 0.5 ) {
        tangent  = vec3( -1,  0, 0 );
        binormal = cross(  gl_Normal, tangent );
    } else if( gl_Normal.y < -0.5 ) {
        tangent  = vec3( 1,  0, 0 );
        binormal = cross(  gl_Normal, tangent );
    } else if( gl_Normal.z > 0.5 ) {
        tangent  = vec3( 1,  0, 0 );
        binormal = cross(  gl_Normal, tangent );
    } else if( gl_Normal.z < -0.5 ) {
        tangent  = vec3( 1,  0, 0 );
        binormal = cross(  gl_Normal, tangent );
    }

    normal = normalize(gl_NormalMatrix * gl_Normal);
    tangent = normalize( gl_NormalMatrix * tangent );
    binormal = normalize( gl_NormalMatrix * binormal );

    normalMatrix = mat3( tangent, binormal, normal );
}
