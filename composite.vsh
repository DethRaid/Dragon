#version 120

uniform float rainStrength;

uniform int worldTime;
uniform vec3 sunPosition;
uniform vec3 moonPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

varying vec2 coord;
varying vec3 lightVector;
varying vec3 lightColor;
varying vec3 ambientColor;

varying vec3 fogColor;

void main() {
    gl_Position = ftransform();
    coord = gl_MultiTexCoord0.st;

    if( worldTime > 500 && worldTime < 13000 ) {
        lightVector = normalize( sunPosition );
        lightColor = vec3( 1, 0.98, 0.95 ) * 5.0;
        ambientColor = vec3( 0.2, 0.2, 0.2 );
        fogColor = vec3( 0.529, 0.808, 0.980 );
    } 
    if( rainStrength > 0.1 ) {
        //load up the rain fog profile
        fogColor = vec3( 0.5, 0.5, 0.5 );
        lightColor *= 0.3;
        ambientColor *= 0.3;
    }
    if( worldTime < 500 || worldTime > 13000 ) {
        lightVector = normalize( moonPosition );
        lightColor = vec3( 0.125, 0.125, 0.15725 );
        ambientColor = vec3( 0.02, 0.02, 0.02 ) * 0.5;
        fogColor = vec3( 0.103, 0.103, 0.105 );
    }
}
