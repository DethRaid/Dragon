#version 120

#define MAX_BLUR_RADIUS         7
#define BLUR_DEPTH_DIFFERENCE   0.25

#define HALFPIXEL               texelToUV( 0.5, 0.5 )

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

float luma( in vec3 color ) {
    return dot( color, vec3( 0.2126, 0.7152, 0.0722 ) );
}

//smoothness of 1
vec3 blur0() {
    return texture2D( gaux1, coord ).rgb;
}

//smoothness of .9
vec3 blur9() {
    return texture2D( gaux1, coord + HALFPIXEL ).rgb;
}

//smoothness of .8
vec3 blur8() {
    vec3 finalColor = vec3( 0 );
    
    vec2 offset = texelToUV( -1, -1 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;    
    offset = texelToUV( 1, -1 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;    
    offset = texelToUV( 1, 1 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;    
    offset = texelToUV( -1, 1 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;
    
    return finalColor / 4.0;
}

//smoothness of .7
vec3 blur7() {
    vec3 finalColor = vec3( 0 );
    
    vec2 offset = texelToUV( -1, -1 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;    
    offset = texelToUV( 1, -1 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;    
    offset = texelToUV( 1, 1 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;    
    offset = texelToUV( -1, 1 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb; 
    
    offset = texelToUV( -2, 0 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;    
    offset = texelToUV( 2, 0 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;    
    offset = texelToUV( 0, -2 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 0, 2 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    return finalColor / 6.8;
}

//smoothness of .6
vec3 blur6() {
    vec3 finalColor = vec3( 0 );
    
    vec2 offset = texelToUV( -2, -2 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;    
    offset = texelToUV( 2, -2 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;    
    offset = texelToUV( 2, 2 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;    
    offset = texelToUV( -2, 2 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;  
    
    offset = texelToUV( -4, 0 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;    
    offset = texelToUV( 4, 0 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;    
    offset = texelToUV( 0, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 0, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    offset = texelToUV( -4, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.6;    
    offset = texelToUV( 4, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.6;    
    offset = texelToUV( 4, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.6;
    offset = texelToUV( -4, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.6;
    
    return finalColor / 9.2;
}

//smoothness of .5
vec3 blur5() {
    vec3 finalColor = vec3( 0 );
    
    vec2 offset = texelToUV( -3, -3 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;    
    offset = texelToUV( 3, -3 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;    
    offset = texelToUV( 3, 3 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;    
    offset = texelToUV( -3, 3 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;  
    
    offset = texelToUV( -6, 0 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;    
    offset = texelToUV( 6, 0 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;    
    offset = texelToUV( 0, -6 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( 0, 6 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    
    offset = texelToUV( -6, -6 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;    
    offset = texelToUV( 6, -6 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;    
    offset = texelToUV( 6, 6 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;
    offset = texelToUV( -6, 6 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;
    
    offset = texelToUV( -9, 0 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;    
    offset = texelToUV( 9, 0 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;    
    offset = texelToUV( 0, 9 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 0, 9 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    return finalColor / 13.6;
}

//smoothness of .4
vec3 blur4() {
    vec3 finalColor = vec3( 0 );
    
    vec2 offset = texelToUV( -3, -3 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;    
    offset = texelToUV( 3, -3 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;    
    offset = texelToUV( 3, 3 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;    
    offset = texelToUV( -3, 3 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;  
    
    offset = texelToUV( -6, 0 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;    
    offset = texelToUV( 6, 0 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;    
    offset = texelToUV( 0, -6 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( 0, 6 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    
    offset = texelToUV( -6, -6 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;    
    offset = texelToUV( 6, -6 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;    
    offset = texelToUV( 6, 6 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;
    offset = texelToUV( -6, 6 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;
    
    offset = texelToUV( -7, 0 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;    
    offset = texelToUV( 7, 0 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;    
    offset = texelToUV( 0, 7 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 0, 7 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    offset = texelToUV( -12, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.6;    
    offset = texelToUV( 12, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.6;    
    offset = texelToUV( -12, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.6;
    offset = texelToUV( 12, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.6;
    
    return finalColor / 16;
}

//smoothness of .3
vec3 blur3() {
    vec3 finalColor = vec3( 0 );
    
    vec2 offset = texelToUV( -4, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;    
    offset = texelToUV( 4, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;    
    offset = texelToUV( 4, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;    
    offset = texelToUV( -4, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;  
    
    offset = texelToUV( -12, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;    
    offset = texelToUV( 12, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;    
    offset = texelToUV( -12, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( 12, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    
    offset = texelToUV( -4, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;    
    offset = texelToUV( -4, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;    
    offset = texelToUV( 4, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( 4, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    
    offset = texelToUV( -12, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;    
    offset = texelToUV( 12, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;    
    offset = texelToUV( 12, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;
    offset = texelToUV( -12, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;
    
    offset = texelToUV( -20, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;    
    offset = texelToUV( 20, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;    
    offset = texelToUV( -20, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 20, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    offset = texelToUV( -20, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;    
    offset = texelToUV( 20, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;    
    offset = texelToUV( -20, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 20, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    offset = texelToUV( -4, -20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;    
    offset = texelToUV( -4, 20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;    
    offset = texelToUV( -12, -20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( -12, 20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    offset = texelToUV( 4, -20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;    
    offset = texelToUV( 4, 20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;    
    offset = texelToUV( 12, -20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 12, 20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    return finalColor / 25.6;
}

//smoothness of .2
vec3 blur2() {
    vec3 finalColor = vec3( 0 );
    vec2 offset;
        
    offset = texelToUV( 4, -20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 4, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( 4, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;
    offset = texelToUV( 4, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;
    offset = texelToUV( 4, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( 4, 20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    offset = texelToUV( -4, -20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( -4, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( -4, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;
    offset = texelToUV( -4, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;
    offset = texelToUV( -4, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( -4, 20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    offset = texelToUV( 12, 20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 12, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;
    offset = texelToUV( 12, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( 12, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( 12, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;
    offset = texelToUV( 12, -20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    offset = texelToUV( -12, 20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( -12, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;
    offset = texelToUV( -12, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( -12, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( -12, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;
    offset = texelToUV( -12, -20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    
    offset = texelToUV( 20, -20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 20, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 20, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 20, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 20, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 20, 20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    offset = texelToUV( -20, -20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( -20, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( -20, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( -20, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( -20, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( -20, -20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    for( int i = -28; i < 29; i += 8 ) {
        offset = texelToUV( 28, i );
        finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.6;
        offset = texelToUV( i, 28 );
        finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.6;
        offset = texelToUV( -28, i );
        finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.6;
        offset = texelToUV( i, -28 );
        finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.6;
    }
    
    return finalColor / 47.6;
}

//smoothness of 0.1//smoothness of .2
vec3 blur1() {
    vec3 finalColor = vec3( 0 );
    vec2 offset;
        
    offset = texelToUV( 4, -20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 4, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( 4, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;
    offset = texelToUV( 4, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;
    offset = texelToUV( 4, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( 4, 20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    offset = texelToUV( -4, -20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( -4, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( -4, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;
    offset = texelToUV( -4, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb;
    offset = texelToUV( -4, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( -4, 20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    offset = texelToUV( 12, 20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 12, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;
    offset = texelToUV( 12, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( 12, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( 12, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;
    offset = texelToUV( 12, -20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    offset = texelToUV( -12, 20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( -12, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;
    offset = texelToUV( -12, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( -12, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.9;
    offset = texelToUV( -12, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.8;
    offset = texelToUV( -12, -20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    
    offset = texelToUV( 20, -20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 20, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 20, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 20, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 20, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( 20, 20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    offset = texelToUV( -20, -20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( -20, -12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( -20, -4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( -20, 4 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( -20, 12 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    offset = texelToUV( -20, -20 );
    finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.7;
    
    for( int i = -28; i < 29; i += 8 ) {
        offset = texelToUV( 28, i );
        finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.6;
        offset = texelToUV( i, 28 );
        finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.6;
        offset = texelToUV( -28, i );
        finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.6;
        offset = texelToUV( i, -28 );
        finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.6;
    }
    
    for( int i = -36; i < 37; i += 8 ) {
        offset = texelToUV( 36, i );
        finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.5;
        offset = texelToUV( i, 36 );
        finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.5;
        offset = texelToUV( -36, i );
        finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.5;
        offset = texelToUV( i, -36 );
        finalColor += texture2D( gaux1, coord + offset + HALFPIXEL ).rgb * 0.5;
    }
    
    return finalColor / 67.6;
}

vec3 blurReflections( in float blurRadius ) { 
    /*blurRadius *= 8;
    vec3 finalColor = texture2D( gaux1, coord ).rgb;
    int numSamples = 1;
    float compareDepth = getDepthLinear( coord );
    for( float i = -blurRadius; i < blurRadius + 1; i += 8 ) {
        for( float j = -blurRadius; j < blurRadius + 1; j += 8 ) {
            vec2 offset = texelToUV( j, i );
            if( abs( getDepthLinear( coord + offset ) - compareDepth ) < BLUR_DEPTH_DIFFERENCE ) {
                vec4 compColor = texture2D( gaux1, coord + offset + HALFPIXEL );
                finalColor += compColor.rgb;
            }
            numSamples++;
        }
    }
    return finalColor / numSamples;*/
    if( blurRadius > 0.99 ) {           //1.0
        return blur0();
    } else if( blurRadius > 0.89 ) {    //0.9
        return blur9();
    } else if( blurRadius > 0.79 ) {    //0.8
        return blur8();
    } else if( blurRadius > 0.69 ) {    //0.7
        return blur7();
    } else if( blurRadius > 0.59 ) {    //0.6
        return blur6();
    } else if( blurRadius > 0.49 ) {    //0.5
        return blur5();
    } else if( blurRadius > 0.39 ) {    //0.4
        return blur4();
    } else if( blurRadius > 0.29 ) {    //0.3
        return blur3();
    } else if( blurRadius > 0.19 ) {    //0.2
        return blur2();
    }
    return blur1();
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
        float blurAmt = (1.0 - texture2D( gaux1, coord ).a) * (1.0 - smoothness) * smoothness + smoothness;
        if( smoothness > 0.1 ) {
            reflectedColor = blurReflections( blurAmt ) * pow( smoothness, 0.5 );
        }

        smoothness = pow( smoothness, 4 );
        vec3 sColor = color * metalness + vec3( smoothness ) * (1.0 - metalness);
        vec3 fresnel = sColor + (vec3( 1.0 ) - sColor) * pow( 1.0 - vdoth, 5 );

        if( length( fresnel ) > 1 ) {
            //fresnel = normalize( fresnel );
        }
        
        reflectedColor *= fresnel;

        color = (1.0 - luma( reflectedColor )) * color * (1.0 - metalness) + reflectedColor;
        //color = reflectedColor;
        // = vec3( blurAmt );
    }
    color = pow( color, vec3( 1 / 2.2 ) );
    
    gl_FragData[0] = vec4( color, 1.0 );
    gl_FragData[1] = texture2D( gdepth, coord );
    gl_FragData[2] = texture2D( gnormal, coord );
    gl_FragData[3] = texture2D( composite, coord );
    gl_FragData[4] = texture2D( gaux1, coord );
    gl_FragData[5] = texture2D( gaux2, coord );
    gl_FragData[6] = texture2D( gaux3, coord );
}
