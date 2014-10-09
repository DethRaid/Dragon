#version 120

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D lightmap;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 normal;
varying mat3 tbnMatrix;

varying float smoothness_in;
varying float metalness_in;

varying float isEmissive;

float luma( in vec3 color ) {
    return dot( color, vec3( 0.2126, 0.7152, 0.0722 ) );
}

void main() {
    //color
    vec4 texColor = texture2D( texture, uv ) * color;
    
    vec3 sData = texture2D( specular, uv ).rgb;
    float smoothness = sData.r;
    float emission = sData.g;
    float metalness = sData.b;
    
    float lumac = min( luma( texColor.rgb ), 1.0 );
    texColor += texColor * (1.0 - lumac) * 0.75;
    texColor /= 1.1;
    
    gl_FragData[0] = texColor;
    
    //skipLighting, torch lighting, isWater, smoothness
    gl_FragData[5] = vec4( emission, texture2D( lightmap, uvLight ).r, metalness, smoothness );

    vec3 texnormal = texture2D( normals, uv ).xyz;
    texnormal = tbnMatrix * texnormal;
    //normal, metalness
    gl_FragData[2] = vec4( normal * 0.5 + 0.5, 0.0 );
}
