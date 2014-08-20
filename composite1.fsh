#version 120

//Adjustable variables. Tune these for performance
#define MAX_BLUR_RADIUS         12  //The bigger the number, the less sharp reflections will be
#define MAX_RAY_LENGTH          500 //How many pixels is a single ray allowed to travel?
#define MAX_DEPTH_DIFFERENCE    0.1 //How much of a step between the hit pixel and anything else is allowed?

uniform sampler2D gdepthdex;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D composite;

varying vec2 coord;

struct Pixel1 {
    vec4 position;
    vec3 color;
    vec3 normal;
    bool skipLighting;
    float reflectivity;
    float smootheess;
}

///////////////////////////////////////////////////////////////////////////////
//                              Helper Functions                             //
///////////////////////////////////////////////////////////////////////////////
//Credit to Sonic Ether for depth, normal, and positions

float getDepth(  vec2 coord ) {	
    return texture2D( gdepthtex, coord ).r;
}

vec4 getScreenSpacePosition() {	
	float depth = getDepth( coord );
	vec4 fragposition = gbufferProjectionInverse * vec4( coord.s * 2.0 - 1.0, coord.t * 2.0 - 1.0, 2.0 * depth - 1.0, 1.0 );
		 fragposition /= fragposition.w;
	return fragposition;
}

vec4 getWorldSpacePosition() {
	vec4 pos = getScreenSpacePosition();
	pos = gbufferModelViewInverse * pos;
	pos.xyz += cameraPosition.xyz;
	return pos;
}

vec3 getColor() {
    return texture2D( composite, coord ).rgb;
}

bool shouldSkipLighting() {
    return texture2D( gdepth, coord ).r > 0.5;
}

float getSmoothness() {
    return texture2D( gdepth, coord ).a;
}

vec3 getNormal() {
    vec3 normal = normalize( texture2D( gnormal, coord ).xyz * 2.0 - 1.0 );
    normal.x *= -1;
    return normal;
}

float getReflectivity() {
    return texture2D( gnormal, coord ).a;
}

///////////////////////////////////////////////////////////////////////////////
//                              Main Functions                               //
///////////////////////////////////////////////////////////////////////////////

void fillPixelStruct( inout Pixel pixel ) {
    pixel.position =        getWorldSpacePosition();
    pixel.normal =          getNormal();
    pixel.color =           getColor();
    pixel.reflectivity =    getReflectivity();
    pixel.smoothness =      getSmoothness();
    pixel.skipLighting =    shouldSkipLighting();
}

//Takes a number of texels and converts them to a UV position
//Actually only works when your screen is 1080p
//I hope you people like full HD...
vec2 texelToUV( int x, int y ) {
    return vec2( float( x ) / 1920.0, float( y ) / 1080 );
}

/*!\brief Blurs composite by the specified size around the specified point

\param in center The texture-space coordinate of the center of the blur
\param in blurRadius The radius of the blur operation, in pixels
*/
vec3 blurArea( in vec2 center, in int blurRadius, in float maxDepthDifference ) {
    vec3 finalColor = vec3( 0 );
    int numBlurred;
    float hitDepth = texture2D( gdepthtex, center ).r;
    for( int i = -blurRadius; i < blurRadius; i++ ) {
        for( int j = -blurRadius; j < blurRadius; j++ ) {
            //get the depth of the pixel we're looking at
            vec2 offset = texelToUV( j, i );
            float curDepth = texture2D( gdepthtex, center + offset ).r;
            if( abs( curDepth - hitDepth ) < maxDepthDifference ) {
                finalColor += texture2D( composite, center + offset ).rgb;
                numBlurred++;
            }
        }
    }
    return finalColor / float( numBlurred );
}

//Determines the UV coordinate where the ray hits
//If the returned value is not in the range [0, 1] then nothing was hit.
//NOTHING!
//Note that origin and direction are assumed to be in screen-space coordinates, such that 
//  -origin.st is the texture coordinate of the ray's origin
//  -direction.st is of such a length that it moves the equivalent of one texel
//  -both origin.z and direction.z correspond to values raw from the depth buffer
vec2 castRay( in vec3 origin, in vec3 direction, in float maxDist ) {
    vec3 curPos = origin + direction;
    while( texture2D( gdepthtex, curPos.st ).r > curPos.z ) {
        curPos += direction;
        if( length( curPos ) > maxDist ) {
            return vec2( -1, -1 );
        }
        if( curPos.x < 0 || curPos.x > 1 || curPos.y < 0 || curPos.y > 1 ) {
            return curPos.st;
        }
    }
    if( curPos.z - texture2D( gdepthtex, curPos.st ) < maxDist ) {
        return curPos.st;
    } else {
        return vec2( -1, -1 );
    }
}

//This function simulates a single bounce of light, because who needs framerate when you have #swag?
void doLightBounce( inout Pixel1 pixel ) {
    //Find where the ray hits
    //get the blur at that point
    //mix with the color already in composite
    vec3 rayStart = vec3( coord, texture2D( gdepthtex, coord ).r );
    vec3 rayDir = pixel.normal;
    vec3 maxRayLength = MAX_RAY_LENGTH
    
    vec2 hitUV = castRay( rayStart, rayDir, 
    vec3 hitColor;
    hitColor = blurArea( hitUV, 
    pixel.color = pixel.color * 0.5 + hitColor * 0.5;
}

void main() {
    Pixel1 pixel;
    fillPixelStruct( pixel );
    doLightBounce( pixel );
    gl_FragData[4] = vec4( pixel.color, 1 );
}
