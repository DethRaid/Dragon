#version 450 compatibility

uniform float rainStrength;

uniform int worldTime;
uniform vec3 sunPosition;
uniform vec3 moonPosition;

out vec2 coord;

out vec3 fogColor;

void main() {
    gl_Position = ftransform();
    coord = gl_MultiTexCoord0.st;

    if(rainStrength > 0.1) {
        //load up the rain fog profile
        fogColor = vec3(0.5, 0.5, 0.5);
    } else {
        fogColor = vec3(1);
    }
}
