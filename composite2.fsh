#version 120

#define MAX_BLUR_RADIUS     11

uniform sampler2D gcolor;
uniform sampler2D gdepthtex;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;

uniform float viewWidth;
uniform float viewHeight;

varying vec2 coord;

struct Pixel {
    vec3 color;
    float smoothness;
};

vec3 getColor() {
    return texture2D( composite, coord ).rgb;
}

float getSmoothness() {
    return texture2D( gaux2, coord ).a;
}

float getMetalness() {
    return texture2D( gnormal, coord ).a;
}

bool shouldSkipLighting() {
    return texture2D( gaux2, coord ).r > 0.5;
}

vec2 texelToUV( float x, float y ) {
    return vec2( x / viewWidth, y / viewHeight );
}

vec3 blurReflections( in float blurRadius ) {
    blurRadius *= 8;
    vec3 finalColor = vec3( 0 );
    vec2 halfPixel = texelToUV( 0.5, 0.5 );
    int numSamples = 0;
    for( float i = -blurRadius; i < blurRadius + 1; i += 8 ) {
        for( float j = -blurRadius; j < blurRadius + 1; j += 8 ) {
            vec2 offset = texelToUV( j, i );
            finalColor += texture2D( gaux1, coord + offset + halfPixel ).rgb;
            numSamples += 1;
        }
    }
    return finalColor / numSamples;
}

void main() {
    vec3 color = getColor();
    if( !shouldSkipLighting() ) {
        float smoothness = getSmoothness();
        float metalness = getMetalness();
    
        float blurRadius = (1 - smoothness) * MAX_BLUR_RADIUS;
        vec3 reflectedColor = blurReflections( blurRadius ) * pow( smoothness, 0.5 );

        metalness = mix( 0, metalness * 0.5 + 0.5, metalness );
        reflectedColor *= color * metalness + vec3( 1 ) * (1 - metalness);

        color = color * (1 - smoothness) + reflectedColor * smoothness;
    }
    color = pow( color, vec3( 1 / 2.2 ) );
    gl_FragData[0] = vec4( color, 1 );

    gl_FragData[1] = texture2D( gdepth, coord );
    gl_FragData[2] = texture2D( gnormal, coord );
    gl_FragData[3] = texture2D( composite, coord );
    gl_FragData[4] = texture2D( gaux1, coord );
    gl_FragData[5] = texture2D( gaux2, coord );
    gl_FragData[6] = texture2D( gaux3, coord );
}
