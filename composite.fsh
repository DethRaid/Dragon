#version 120

uniform sampler2D gcolor;
uniform sampler2D gdepth;

varying vec2 coord;

void main() {
    float torchLighting = texture2D( gdepth, coord ).g;
    vec4 torchColor = torchLighting * vec4( 1, 0.7, 0.7, 1 );
    vec4 color = texture2D( gcolor, coord );
    gl_FragData[3] = (color + (color * torchColor)) / 2.0;
}
