#version 120

varying vec2 coord;

uniform int worldTime;

uniform vec3 sunPosition;
uniform vec3 moonPosition;

varying vec3 lightVector;

void main() {
    gl_Position = ftransform();
    gl_Position.xy = gl_Position.xy * 0.5 - 0.5;
    coord = gl_MultiTexCoord0.st;

    if( worldTime > 100 && worldTime < 13000 ) {
        lightVector = normalize(sunPosition);
    } else {
        lightVector = normalize(moonPosition);
    }
}
