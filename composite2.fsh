#version 120

#define MAX_BLUR_RADIUS         11
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

varying vec2 coord;

struct Pixel {
    vec3 color;
    float smoothness;
};

float getDepthLinear( vec2 coord ) {
    return 2.0 * near * far / (far + near - (2.0 * texture2D( gdepthtex, coord ).r - 1.0) * (far - near));
}

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
    vec3 finalColor = texture2D( gaux1, coord ).rgb;
    vec2 halfPixel = texelToUV( 0.5, 0.5 );
    int numSamples = 1;
    float compareDepth = getDepthLinear( coord );
    for( float i = -blurRadius; i < blurRadius + 1; i += 8 ) {
        for( float j = -blurRadius; j < blurRadius + 1; j += 8 ) {
            vec2 offset = texelToUV( j, i );
            if( abs( getDepthLinear( coord + offset ) - compareDepth ) < BLUR_DEPTH_DIFFERENCE ) {
                vec4 compColor = texture2D( gaux1, coord + offset + halfPixel );
                //if( compColor.a > 0.5 ) {
                    finalColor += compColor.rgb;
                    numSamples += 1;
                //}
            }
        }
    }
    return finalColor / numSamples;
}

void main() {
    vec3 color = getColor();
    if( !shouldSkipLighting() ) {
        float smoothness = (getSmoothness() + 0.1) / 1.1;
        float metalness = getMetalness();
    
        float blurRadius = (1 - smoothness) * MAX_BLUR_RADIUS;
        vec3 reflectedColor = blurReflections( blurRadius ) * pow( smoothness, 0.5 );

        metalness = mix( 0, metalness * 0.5 + 0.5, metalness );
        reflectedColor *= color * metalness + vec3( 1 ) * (1 - metalness);

        if( metalness < 0.5 ) {
            smoothness = min( smoothness, 0.4 );
        }
        
        color = color * (1 - smoothness) + reflectedColor * smoothness;
        //color = reflectedColor;
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
