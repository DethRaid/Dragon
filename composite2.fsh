#version 120

#define MAX_BLUR_RADIUS         7
#define BLUR_DEPTH_DIFFERENCE   0.25

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
uniform float near;
uniform float far;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

varying vec2 coord;

struct Pixel {
    vec3 color;
    float smoothness;
};

float getDepthLinear( vec2 coord ) {
    return 2.0 * near * far / (far + near - (2.0 * texture2D( gdepthtex, coord ).r - 1.0) * (far - near));
}

vec3 getNormal() {
    return texture2D( gnormal, coord ).rgb * 2.0 - 1.0;
}

float getDepth() {
    return texture2D( gdepthtex, coord ).r;
}

vec3 getViewVector() {
    float depth = getDepth();
    vec4 fragpos = gbufferProjectionInverse * vec4( coord.s * 2.0 - 1.0, coord.t * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0 );
    fragpos /= fragpos.w;
    return fragpos.xyz;
}

vec3 getColor() {
    return texture2D( composite, coord ).rgb;
}

float getSmoothness() {
    return texture2D( gaux2, coord ).a;
}

float getMetalness() {
    return texture2D( gaux2, coord ).b;
}

bool shouldSkipLighting() {
    return texture2D( gaux2, coord ).r > 0.5;
}

vec2 texelToUV( float x, float y ) {
    return vec2( x / viewWidth, y / viewHeight );
}

vec3 blurReflections( in float blurRadius ) { 
    blurRadius *= 8;
    vec3 finalColor = texture2D( gaux1, coord ).rgb;
    vec2 halfPixel = texelToUV( 0.5, 0.5 );
    int numSamples = 1;
    float compareDepth = getDepthLinear( coord );
    for( float i = -blurRadius; i < blurRadius + 1; i += 8 ) {
        for( float j = -blurRadius; j < blurRadius + 1; j += 8 ) {
            vec2 offset = texelToUV( j, i );
            if( abs( getDepthLinear( coord + offset ) - compareDepth ) < BLUR_DEPTH_DIFFERENCE ) {
                vec4 compColor = texture2D( gaux1, coord + offset + halfPixel );
                finalColor += compColor.rgb;
                numSamples += 1;
            }
        }
    }
    return finalColor / numSamples;
}

void main() {
    vec3 color = getColor();
    if( !shouldSkipLighting() ) {
        vec3 normal = getNormal();
        vec3 viewVector = normalize( getViewVector() );

        float vdoth = clamp( dot( -viewVector, normal ), 0, 1 );

        float smoothness = (getSmoothness() + 0.1) / 1.1;
        float oneMinusSmoothness = 1 - smoothness;
        float metalness = getMetalness();
    
        float blurRadius = oneMinusSmoothness * MAX_BLUR_RADIUS;
        vec3 reflectedColor = vec3( 0 );
        if( smoothness > 0.1 ) {
            reflectedColor = blurReflections( blurRadius ) * pow( smoothness, 0.5 );
        }

        vec3 sColor = color * metalness + vec3( smoothness ) * (1.0 - metalness);
        vec3 fresnel = sColor + (vec3( 1.0 ) - sColor) * pow( 1.0 - vdoth, 5 );

        reflectedColor *= fresnel;

        color = (vec3( 1.0 ) - reflectedColor) * color + reflectedColor;
        //color = vec3( reflectedColor );
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
