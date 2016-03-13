#version 120

varying vec2 coord;

uniform int worldTime;
uniform float rainStrength;

varying vec3 skyColor;

void main() {
    gl_Position = ftransform();
    coord = gl_MultiTexCoord0.st;

    if( worldTime > 500 && worldTime < 13000 ) {
        skyColor = vec3( 0.529, 0.808, 0.922 );
    }
    if( rainStrength > 0.1 ) {
        skyColor = vec3( 0.3, 0.3, 0.3 );
    }
    if( worldTime < 500 || worldTime > 13000 ) {
        skyColor = vec3( 0.1, 0.1, 0.2 );
    }
}
