#version 120

uniform int worldTime;
uniform vec3 sunPosition;
uniform vec3 moonPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

varying vec2 coord;
varying vec3 lightVector;
varying vec3 lightColor;

void main() {
    gl_Position = ftransform();
    coord = gl_MultiTexCoord0.st;

    if( worldTime < 12000 ) {
        lightVector = normalize( sunPosition );
        lightColor = vec3( 1, 0.98, 0.95 );
    } else {
        lightVector = normalize( moonPosition );
        lightColor = vec3( 0.5, 0.5, 0.625 );
    }
}
