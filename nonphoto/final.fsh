#version 120

#define SATURATION 1.05
#define CONTRAST 1.1

#define FXAA
#define EDGE_LUMA_THRESHOLD 0.5

#define BLOOM_RADIUS 19

//Some defines to make my life easier
#define NORTH   0
#define SOUTH   1
#define WEST    2
#define EAST    3

uniform sampler2D gaux1;

uniform float viewWidth;
uniform float viewHeight;

varying vec2 coord;

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

    vec3 colorN = texture2D( gaux1, coordN ).rgb;
    vec3 colorS = texture2D( gaux1, coordS ).rgb;
    vec3 colorE = texture2D( gaux1, coordE ).rgb;
    vec3 colorW = texture2D( gaux1, coordW ).rgb;

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
            vec3 sampledColor = texture2D( gaux1, coord + uvToTexel( int( j ), int( i ) ) + halfTexel ).rgb;
            colorAccum += pow( sampledColor, vec3( 50, 50, 50 ) );
            float bloomPow = float( abs( i ) * abs( j ) );
            colorAccum += pow( sampledColor, vec3( bloomPow ) );
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

void main() {
    vec3 color = texture2D( gaux1, coord ).rgb;
    doBloom( color );
#ifdef FXAA
    fxaa( color );
#endif
    //correctColor( color );
    contrastEnhance( color );

    gl_FragColor = vec4( color, 1 );
}
