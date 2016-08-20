#version 120

#define REFLECTION_RESOLUTION_MODIFIER     0.5 // [1 0.5 0.25]

varying vec2 coord;

uniform int worldTime;

uniform vec3 sunPosition;
uniform vec3 moonPosition;

varying vec3 lightVector;

void main() {
    gl_Position = ftransform();
    gl_Position.xy = gl_Position.xy * REFLECTION_RESOLUTION_MODIFIER - (1.0 - REFLECTION_RESOLUTION_MODIFIER);
    coord = gl_MultiTexCoord0.st;

    if( worldTime > 100 && worldTime < 13000 ) {
        lightVector = normalize(sunPosition);
    } else {
        lightVector = normalize(moonPosition);
    }
}
