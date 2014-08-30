#version 120

//Adjustable variables. Tune these for performance
#define MAX_BLUR_RADIUS         12  //The bigger the number, the less sharp reflections will be
#define MAX_RAY_LENGTH          500 //How many pixels is a single ray allowed to travel?
#define MAX_DEPTH_DIFFERENCE    0.1 //How much of a step between the hit pixel and anything else is allowed?
#define MAX_REFLECTIVITY        0.8 //As this value approaches 1, so do all reflections

uniform sampler2D gdepthtex;
uniform sampler2D gaux2;
uniform sampler2D gnormal;
uniform sampler2D composite;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

varying vec2 coord;

struct Pixel1 {
    vec4 position;
    vec3 color;
    vec3 normal;
    bool skipLighting;
    float reflectivity;
    float smoothness;
};

///////////////////////////////////////////////////////////////////////////////
//                              Helper Functions                             //
///////////////////////////////////////////////////////////////////////////////
//Credit to Sonic Ether for depth, normal, and positions

float getDepth( vec2 coord ) {	
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
    return texture2D( gaux2, coord ).r > 0.5;
}

float getSmoothness() {
    return texture2D( gaux2, coord ).a;
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

void fillPixelStruct( inout Pixel1 pixel ) {
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
    /*while( texture2D( gdepthtex, curPos.st ).r > curPos.z ) {
        curPos += direction;
        if( length( curPos ) > maxDist ) {
            return vec2( -1, -1 );
        }
        if( curPos.x < 0 || curPos.x > 1 || curPos.y < 0 || curPos.y > 1 ) {
            return curPos.st;
        }
    }
    if( curPos.z - texture2D( gdepthtex, curPos.st ).r < maxDist ) {
        return curPos.st;
    } else {
        return vec2( -1, -1 );
    }*/
    return vec2( curPos.st );
}

//This function simulates a single bounce of light, because who needs framerate when you have #swag?
void doLightBounce( inout Pixel1 pixel ) {
    //Find where the ray hits
    //get the blur at that point
    //mix with the color already in composite
    vec3 rayStart = vec3( coord, texture2D( gdepthtex, coord ).r );
    vec3 rayDir = pixel.normal;//(gbufferProjection * vec4( pixel.normal, 0 )).xyz;
    float maxRayLength = MAX_RAY_LENGTH * (1 - rayStart.z) * (1 - pixel.smoothness);
    
    vec2 hitUV = castRay( rayStart, rayDir, maxRayLength );
    vec3 hitColor;
    if( hitUV.s > 0 && hitUV.s < 1 && hitUV.t > 0 && hitUV.t < 1 ) {
        /*float maxDepthDifference = (1 - pixel.smoothness) * MAX_DEPTH_DIFFERENCE;
        int blurRadius = int( (1.0 - pixel.smoothness) * MAX_BLUR_RADIUS );
        hitColor = blurArea( hitUV, blurRadius, maxDepthDifference );*/
        hitColor = texture2D( composite, hitUV ).rgb;
        //pixel.color = vec3( 1, 0, 0 );
    } else {
        hitColor = vec3( 0.529, 0.808, 0.922 );
    }
    
    pixel.reflectivity *= MAX_REFLECTIVITY;
    pixel.color = pixel.color * (1 - pixel.reflectivity) + hitColor * pixel.reflectivity;
    pixel.color = vec3( rayDir );
}

void main() {
    Pixel1 pixel;
    fillPixelStruct( pixel );
    if( !pixel.skipLighting ) {
        //doLightBounce( pixel );
    }
    gl_FragData[4] = texture2D( composite, coord );
}
