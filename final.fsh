#version 120

#define SATURATION 0.99
#define CONTRAST 1.0

//#define FXAA
#define EDGE_LUMA_THRESHOLD 0.5

#define FILM_GRAIN
#define FILM_GRAIN_STRENGTH 0.03
#define FILM_GRAIN_SIZE     1.6

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
uniform int worldTime;

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

//film grain from https://dl.dropboxusercontent.com/u/11542084/FilmGrain_v1.1
//edited slightly for formatting
/*
   Film Grain post-process shader v1.1  
   Martins Upitis (martinsh) devlog-martinsh.blogspot.com
   2013

   --------------------------
   This work is licensed under a Creative Commons Attribution 3.0 Unported License.
   So you are free to share, modify and adapt it for your needs, and even use it for commercial use.
   I would also love to hear about a project you are using it.

   Have fun,
   Martins
   --------------------------

   Perlin noise shader by toneburst:
http://machinesdontcare.wordpress.com/2009/06/25/3d-perlin-noise-sphere-vertex-shader-sourcecode/
*/
//a random texture generator, but you can also use a pre-computed perturbation texture
vec4 rnm(in vec2 tc) {
    float noise =  sin( dot( tc + vec2( floatTime, floatTime ), vec2( 12.9898, 78.233 ) ) ) * 43758.5453;

    float noiseR =  fract(noise)*2.0-1.0;
    float noiseG =  fract(noise*1.2154)*2.0-1.0; 
    float noiseB =  fract(noise*1.3453)*2.0-1.0;
    float noiseA =  fract(noise*1.3647)*2.0-1.0;
                            
    return vec4(noiseR,noiseG,noiseB,noiseA);
}

float fade(in float t) {
    return t*t*t*(t*(t*6.0-15.0)+10.0);
}

//I (DethRaid) don't really know what these do, but they seem important
const float permTexUnit = 1.0/256.0;		// Perm texture texel-size
const float permTexUnitHalf = 0.5/256.0;	// Half perm texture texel-size

float pnoise3D(in vec3 p) {
    vec3 pi = permTexUnit*floor(p)+permTexUnitHalf; // Integer part, scaled so +1 moves permTexUnit texel
    // and offset 1/2 texel to sample texel centers
    vec3 pf = fract(p);     // Fractional part for interpolation

    // Noise contributions from (x=0, y=0), z=0 and z=1
    float perm00 = rnm(pi.xy).a ;
    vec3  grad000 = rnm(vec2(perm00, pi.z)).rgb * 4.0 - 1.0;
    float n000 = dot(grad000, pf);
    vec3  grad001 = rnm(vec2(perm00, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
    float n001 = dot(grad001, pf - vec3(0.0, 0.0, 1.0));

    // Noise contributions from (x=0, y=1), z=0 and z=1
    float perm01 = rnm(pi.xy + vec2(0.0, permTexUnit)).a ;
    vec3  grad010 = rnm(vec2(perm01, pi.z)).rgb * 4.0 - 1.0;
    float n010 = dot(grad010, pf - vec3(0.0, 1.0, 0.0));
    vec3  grad011 = rnm(vec2(perm01, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
    float n011 = dot(grad011, pf - vec3(0.0, 1.0, 1.0));

    // Noise contributions from (x=1, y=0), z=0 and z=1
    float perm10 = rnm(pi.xy + vec2(permTexUnit, 0.0)).a ;
    vec3  grad100 = rnm(vec2(perm10, pi.z)).rgb * 4.0 - 1.0;
    float n100 = dot(grad100, pf - vec3(1.0, 0.0, 0.0));
    vec3  grad101 = rnm(vec2(perm10, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
    float n101 = dot(grad101, pf - vec3(1.0, 0.0, 1.0));

    // Noise contributions from (x=1, y=1), z=0 and z=1
    float perm11 = rnm(pi.xy + vec2(permTexUnit, permTexUnit)).a ;
    vec3  grad110 = rnm(vec2(perm11, pi.z)).rgb * 4.0 - 1.0;
    float n110 = dot(grad110, pf - vec3(1.0, 1.0, 0.0));
    vec3  grad111 = rnm(vec2(perm11, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
    float n111 = dot(grad111, pf - vec3(1.0, 1.0, 1.0));

    // Blend contributions along x
    vec4 n_x = mix(vec4(n000, n001, n010, n011), vec4(n100, n101, n110, n111), fade(pf.x));

    // Blend contributions along y
    vec2 n_xy = mix(n_x.xy, n_x.zw, fade(pf.y));

    // Blend contributions along z
    float n_xyz = mix(n_xy.x, n_xy.y, fade(pf.z));

    // We're done, return the final noise value.
    return n_xyz;
}

//2d coordinate orientation thing
vec2 coordRot(in vec2 tc, in float angle) {
    float aspect = viewWidth / viewHeight;
    float rotX = ((tc.x*2.0-1.0)*aspect*cos(angle)) - ((tc.y*2.0-1.0)*sin(angle));
    float rotY = ((tc.y*2.0-1.0)*cos(angle)) + ((tc.x*2.0-1.0)*aspect*sin(angle));
    rotX = ((rotX/aspect)*0.5+0.5);
    rotY = rotY*0.5+0.5;
    return vec2(rotX,rotY);
}

//I used the licensed algorithm here, making minimal variable name changes to integrate this code
//with my own and to make the formatting consistent with my own formatting

void doFilmGrain( inout vec3 color ) {
    vec3 rotOffset = vec3( 1.425, 3.892, 5.835 );
    vec2 rotCoordsR = coordRot( coord, floatTime + rotOffset.x );
    vec3 noise = vec3( pnoise3D( vec3( rotCoordsR * vec2( viewWidth / FILM_GRAIN_SIZE, viewHeight / FILM_GRAIN_SIZE ) , 0.0 ) ) );
    float luma = luma( color );
    noise = mix( noise, vec3( 0.0 ), pow( luma, 4.0 ) );

    color += noise * FILM_GRAIN_STRENGTH;
}
//licensed film grain code stops here

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
