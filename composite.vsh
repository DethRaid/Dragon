#version 120

uniform int worldTime;
uniform vec3 sunPosition;
uniform vec3 moonPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

varying vec2 coord;
varying vec3 lightVector;
varying vec3 lightColor;

varying vec3 fogColor;

void main() {
    gl_Position = ftransform();
    coord = gl_MultiTexCoord0.st;

    if( worldTime > 500 && worldTime < 13000 ) {
        lightVector = normalize( sunPosition );
        lightColor = vec3( 1, 0.98, 0.95 ) * 24.0; 
        fogColor = vec3( 0.529, 0.808, 0.980 );
    } else {
        lightVector = normalize( moonPosition );
        lightColor = vec3( 0.125, 0.125, 0.15725 ) * 12.09;
        fogColor = vec3( 0.103, 0.103, 0.105 );
    }
}
