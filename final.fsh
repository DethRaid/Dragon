#version 120

#define SATURATION 0.9
#define CONTRAST 1.0

//#define FXAA
#define EDGE_LUMA_THRESHOLD 0.5

#define FILM_GRAIN
#define FILM_GRAIN_STRENGTH 0.075

//#define BLOOM
#define BLOOM_RADIUS 9

#define VINGETTE
#define VINGETTE_MIN        0.4
#define VINGETTE_MAX        0.65
#define VINGETTE_STRENGTH   0.25

#define MOTION_BLUR
#define MOTION_BLUR_SAMPLES 16
#define MOTION_BLUR_SCALE   0.25

//Some defines to make my life easier
#define NORTH   0
#define SOUTH   1
#define WEST    2
#define EAST    3

uniform sampler2D gcolor;
uniform sampler2D gdepthtex;
uniform sampler2D gaux1;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;

uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;

varying vec2 coord;
varying float floatTime;

float luma( vec3 color ) {
    return dot( color, vec3( 0.2126, 0.7152, 0.0722 ) );
}

//actually texel to uv. Oops.
vec2 uvToTexel( int s, int t ) {
    return vec2( s / viewWidth, t / viewHeight );
}

//Written by DethRaid, dirty implementation of http://developer.download.nvidia.com/assets/gamedev/files/sdk/11/FXAA_WhitePaper.pdf
void fxaa( inout vec3 color ) {
    //Are we on an edge? If so, which way is the edge going?
    vec2 coordN = coord + uvToTexel(  0,  1 );
    vec2 coordS = coord + uvToTexel(  0, -1 );
    vec2 coordE = coord + uvToTexel(  1,  0 );
    vec2 coordW = coord + uvToTexel( -1,  0 );

    vec3 colorN = texture2D( gcolor, coordN ).rgb;
    vec3 colorS = texture2D( gcolor, coordS ).rgb;
    vec3 colorE = texture2D( gcolor, coordE ).rgb;
    vec3 colorW = texture2D( gcolor, coordW ).rgb;

    float lumaM = luma( color );
    float lumaN = luma( colorN );
    float lumaS = luma( colorS );
    float lumaE = luma( colorE );
    float lumaW = luma( colorW );

    float diffN = abs( lumaM - lumaN );
    float diffS = abs( lumaM - lumaS );
    float diffE = abs( lumaM - lumaE );
    float diffW = abs( lumaM - lumaW );

    float diffH = max( diffN, diffS );
    float diffV = max( diffE, diffW );

    if( max( diffH, diffV ) < EDGE_LUMA_THRESHOLD ) {
        //If there's not enough luma difference surrounding this pixel, go home
        return;
    }

    int edgeDir;
    int edgeSide;

    if( diffE > diffV ) {
        edgeDir = EAST;
    } 
    if( diffW > diffV ) {
        edgeDir = WEST;
    }
    if( diffN > diffH ) {
        edgeDir = NORTH;
    }
    if( diffS > diffH ) {
        edgeDir = SOUTH;
    }

    if( edgeDir == EAST || edgeDir == WEST ) {
        edgeSide = (diffN > diffS ? NORTH : SOUTH);
    } else if( edgeDir == NORTH || edgeDir == SOUTH ) {
        edgeSide = (diffE > diffW ? EAST : WEST);
    }
}

void doBloom( inout vec3 color ) {
    vec3 colorAccum = vec3( 0 );
    int numSamples = 0;
    vec2 halfTexel = vec2( 0.5 / viewWidth, 0.5 / viewHeight );
    for( float i = -BLOOM_RADIUS; i < BLOOM_RADIUS; i += 2 ) {
        for( float j = -BLOOM_RADIUS; j < BLOOM_RADIUS; j += 2 ) {
            vec3 sampledColor = texture2D( gcolor, coord + uvToTexel( int( j ), int( i ) ) + halfTexel ).rgb;
            float lumaSample = luma( sampledColor );
            lumaSample = pow( lumaSample, 25 );
            float bloomPow = float( abs( i ) * abs( j ) );
            colorAccum += pow( sampledColor, vec3( bloomPow ) ) * lumaSample;
            numSamples++;
        }
    }
    color += colorAccum / (numSamples * 3);
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
    float depth = texture2D( gdepthtex, coord );
    vec2 ndcPos = coord * 2.0 - 1.0;
    vec4 fragPos = gbufferProjectionInverse * vec4( ndcPos, depth * 2.0 - 1.0, 1.0 );
    fragPos /= fragPos.w;

    vec4 previous = curToPreviousMat * fragPos;
    previous /= previous.w;
    previous.xy = previous.xy * 0.5 + 0.5;

    return previous.xy - coord;
}

vec3 doMotionBlur() {
    vec2 blurVector = getBlurVector() * MOTION_BLUR_SCALE;
    vec4 result = texture2D( gaux1, coord );
    for( int i = 0; i < MOTION_BLUR_SAMPLES; i++ ) {
        vec2 offset = blurVector * (float( i ) / float( MOTION_BLUR_SAMPLES - 1) - 0.5);
        result += texture2D( gaux1, coord + offset );
    }
    return result.rgb / float( MOTION_BLUR_SAMPLES );
}
#endif

void main() {
    vec3 color = vec3( 0 );
#ifdef MOTION_BLUR
    color = doMotionBlur();
#else
    color = texture2D( gaux1, coord );
#endif

#ifdef BLOOM
    doBloom( color );
#endif

#ifdef FXAA
    fxaa( color );
#endif

    //correctColor( color );
    contrastEnhance( color );

#ifdef FILM_GRAIN
    doFilmGrain( color );
#endif

#ifdef VINGETTE
    color -= vec3( vingetteAmt( coord ) );
#endif

    gl_FragColor = vec4( color, 1 );
}
