#version 120

uniform sampler2D gcolor;
uniform sampler2D gdepth;

varying vec2 coord;

void main() {
    //extract torch lighting factor
    float torchLighting = texture2D( gdepth, coord ).g;
    //get rid of boooooring not-quite-dark spots
    //torchLighting = pow( torchLighting, 2 );

    vec4 torchColor = torchLighting * vec4( 1, 0.9, 0.5, 1 );


    vec4 color = texture2D( gcolor, coord );

    gl_FragData[3] = color * torchColor;
}
