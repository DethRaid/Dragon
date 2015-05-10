#version 120

#define SATURATION 1.0
#define CONTRAST 1.0
#define EXPOSURE 1.0
#define MAX_BRIGHTNESS 25.0

//#define FILM_GRAIN
#define FILM_GRAIN_STRENGTH 0.075

#define BLOOM
#define BLOOM_RADIUS 9

//#define VINGETTE
#define VINGETTE_MIN        0.4
#define VINGETTE_MAX        0.65
#define VINGETTE_STRENGTH   0.05


//#define MOTION_BLUR
#define MOTION_BLUR_SAMPLES 16
#define MOTION_BLUR_SCALE   0.25

uniform sampler2D gcolor;
uniform sampler2D gdepthtex;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux2;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;

uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;

varying vec2 coord;
varying float floatTime;

vec4 getColor( in vec2 coord ) {
    return texture2D( gnormal, coord );
}

float luma( vec3 color ) {
    return dot( color, vec3( 0.2126, 0.7152, 0.0722 ) );
}

//actually texel to uv. Oops.
vec2 uvToTexel( int s, int t ) {
    return vec2( s / viewWidth, t / viewHeight );
}

void doBloom( inout vec3 color ) {
    vec3 colorAccum = vec3( 0 );
    int numSamples = 0;
    vec2 halfTexel = vec2( 0.5 / viewWidth, 0.5 / viewHeight );
    float radius = BLOOM_RADIUS * 2.0;
    for( float i = -radius; i < radius; i += 4 ) {
        for( float j = -radius; j < radius; j += 4 ) {
            vec2 samplePos = coord + uvToTexel( int( j ), int( i ) ) + halfTexel;
            vec3 sampledColor = getColor( samplePos ).rgb;
            float emission = texture2D( gaux2, samplePos ).b;
            float lumaSample = sampledColor.r;
            float bloomPow = float( abs( i ) * abs( j ) );
            lumaSample = pow( lumaSample, bloomPow );
            colorAccum += sampledColor * (lumaSample * emission);
            numSamples++;
        }
    }
    color += colorAccum / numSamples;
}

void correctColor( inout vec3 color ) {
    color *= vec3( 1.2, 1.2, 1.2 );
}

void contrastEnhance( inout vec3 color ) {
    vec3 intensity = vec3( luma( color ) );
 
    vec3 satColor = mix( intensity, color, SATURATION );
    vec3 conColor = mix( vec3( 0.5, 0.5, 0.5 ), satColor, CONTRAST );
    color = conColor;
}

void doFilmGrain( inout vec3 color ) {
    float noise = fract( sin( dot( coord + vec2( frameTimeCounter ), vec2( 12.8989, 78.233 ) ) ) * 43758.5453 );
    
    color += vec3( noise ) * FILM_GRAIN_STRENGTH;
    color /= 1.0 + FILM_GRAIN_STRENGTH;
}

#ifdef VINGETTE
float vingetteAmt( in vec2 coord ) {
    return smoothstep( VINGETTE_MIN, VINGETTE_MAX, length( coord - vec2( 0.5, 0.5 ) ) ) * VINGETTE_STRENGTH;
}
#endif

#ifdef MOTION_BLUR
vec2 getBlurVector() {
    mat4 curToPreviousMat = gbufferModelViewInverse * gbufferPreviousModelView * gbufferPreviousProjection;
    float depth = texture2D( gdepthtex, coord ).r;
    vec2 ndcPos = coord * 2.0 - 1.0;
    vec4 fragPos = gbufferProjectionInverse * vec4( ndcPos.x, ndcPos.y, depth * 2.0 - 1.0, 1.0 );
    fragPos /= fragPos.w;

    vec4 previous = curToPreviousMat * fragPos;
    previous /= previous.w;
    previous.xy = previous.xy * 0.5 + 0.5;

    return previous.xy - coord;
}

vec3 doMotionBlur() {
    vec2 blurVector = getBlurVector() * MOTION_BLUR_SCALE;
    vec4 result = getColor( coord );
    for( int i = 0; i < MOTION_BLUR_SAMPLES; i++ ) {
        vec2 offset = blurVector * (float( i ) / float( MOTION_BLUR_SAMPLES - 1.0 ) - 0.5);
        result += getColor( coord + offset );
    }
    return result.rgb / float( MOTION_BLUR_SAMPLES );
}
#endif

void doToneMapping( inout vec3 color ) {
    //vec3 x = max( vec3( 0.0 ), color - 0.004 );
    //color = (x * (6.2 * x +0.5)) / (x * (6.2 * x + 1.7) + 0.06);
    float lumac = luma( color );
    float lumar = lumac / (1.0 + lumac);
    color *= lumar / lumac;
}

void main() {
    vec3 color = vec3( 0 );
#ifdef MOTION_BLUR
    color = doMotionBlur();
#else
    color = getColor( coord ).rgb;
#endif

#ifdef BLOOM
    doBloom( color );
#endif

#ifdef FILM_GRAIN
    doFilmGrain( color );
#endif

#ifdef VINGETTE
    color -= vec3( vingetteAmt( coord ) );
#endif

    //correctColor( color );
    contrastEnhance( color );
        
    doToneMapping( color );

    // go from linear to gamma color space
    color = pow( color, vec3( 1.0 / 2.2 ) );
    
    gl_FragColor = vec4( color, 1 );
}
