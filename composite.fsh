#version 120

///////////////////////////////////////////////////////////////////////////////
//                              Unchangable Variables                        //
///////////////////////////////////////////////////////////////////////////////
const int   shadowMapResolution     = 2048;
const float shadowDistance          = 120.0;
const bool  generateShadowMipmap    = false;
const float shadowIntervalSize      = 4.0;
const bool  shadowHardwareFiltering = false;
const bool  shadowtexNearest        = true;

const int   noiseTextureResolution  = 64;

const float sunPathRotation         = 25.0;
const float ambientOcclusionLevel   = 0.2;

const int 	R8 						= 0;
const int 	RG8 					= 0;
const int 	RGB8 					= 1;
const int 	RGB16 					= 2;
const int   RGBA16                  = 3;
const int   RGBA8                   = 4;
const int 	gcolorFormat 			= RGB16;
const int 	gdepthFormat 			= RGB8;
const int 	gnormalFormat 			= RGBA16;
const int 	compositeFormat 		= RGB16;
const int   gaux1Format             = RGBA16;
const int   gaux2Format             = RGBA8;

///////////////////////////////////////////////////////////////////////////////
//                              Changable Variables                          //
///////////////////////////////////////////////////////////////////////////////

#define OFF            -1
#define HARD            0
#define SOFT            1
#define REALISTIC       2

#define PCF_FIXED       0
#define PCF_VARIABLE    1

#define PI              3.14159265
#define E               2.71828183

#define SHADOW_QUALITY  REALISTIC
#define SHADOW_BIAS     0.0065
#define SHADOW_FILTER   PCF_FIXED       //PCF has better quality but is slow as mud, POISSON looks good enough
                                        //and runs at a reasonable framerate. Your choice.
#define MAX_PCF_SAMPLES 20              //make this number smaller for better performance at the expence of realism

#define SSAO            false
#define SSAO_SAMPLES    16               //more samples = prettier
#define SSAO_STRENGTH   1.0             //bigger number = more SSAO
#define SSAO_RADIUS     250.0
#define SSAO_MAX_DEPTH  1.0

///////////////////////////////////////////////////////////////////////////////
//                              I need these                                 //
///////////////////////////////////////////////////////////////////////////////

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gdepthtex;
uniform sampler2D gnormal;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;

uniform sampler2D shadow;

uniform sampler2D noisetex;

uniform vec3 cameraPosition;

uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float near;

uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjectionInverse;

varying vec2 coord;

varying vec3 lightVector;
varying vec3 lightColor;
varying vec3 fogColor;
varying vec3 ambientColor;

struct Pixel {
    vec4 position;
    vec4 screenPosition;
    vec3 color;
    vec3 normal;
    float metalness;
    float smoothness;
    float water;
    
    bool skipLighting;
    
    vec3 directLighting;
    vec3 torchLighting;
} curFrag;

struct World {
    vec3 lightDirection;
    vec3 lightColor;
};

///////////////////////////////////////////////////////////////////////////////
//                              Helper Functions                             //
///////////////////////////////////////////////////////////////////////////////
//Credit to Sonic Ether for depth, normal, and positions

float getDepth(  vec2 coord ) {	
    return texture2D( gdepthtex, coord ).r;
}

float getDepthLinear( vec2 coord ) {
    return 2.0 * near * far / (far + near - (2.0 * texture2D( gdepthtex, coord ).r - 1.0) * (far - near));
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
    return pow( texture2D( gcolor, coord ).rgb, vec3( 2.2 ) );
}

bool shouldSkipLighting() {
    return texture2D( gaux2, coord ).r > 0.5;
}

float getWater() {
    return texture2D( gnormal, coord ).a;
}

float getSmoothness() {
    return texture2D( gaux2, coord ).a;
}

vec3 getNormal() {
    return normalize( texture2D( gnormal, coord ).xyz * 2.0 - 1.0 );
}

float getMetalness() {
    return texture2D( gaux2, coord ).b;
}

float getSkyLighting() {
    return max( texture2D( gdepth, coord ).r, 0.1 );
}

///////////////////////////////////////////////////////////////////////////////
//                              Lighting Functions                           //
///////////////////////////////////////////////////////////////////////////////

//from SEUS v8
vec3 calcShadowCoordinate( in Pixel pixel ) {
    vec4 shadowCoord = pixel.position;
    shadowCoord.xyz -= cameraPosition;
    shadowCoord = shadowModelView * shadowCoord;
    shadowCoord = shadowProjection * shadowCoord;
    shadowCoord /= shadowCoord.w;
    
    shadowCoord.st = shadowCoord.st * 0.5 + 0.5;    //take it from [-1, 1] to [0, 1]
    float dFrag = (1 + shadowCoord.z) * 0.5 + 0.005;
    
    return vec3( shadowCoord.st, dFrag );
}

//I'm sorry this is so long, OSX doesn't support GLSL 120 arrays
vec2 poisson( int i ) {
    if( i == 0 ) {
        return vec2( 0.680375, -0.211234 );
    } else if( i == 1 ) {
        return vec2( 0.566198, 0.596880 );
    } else if( i == 2 ) {
        return vec2( 0.823295, -0.604897 );
    } else if( i == 3 ) {
        return vec2( -0.329554, 0.536459 );

    } else if( i == 4 ) {
        return vec2( -0.444451, 0.107940 );
    } else if( i == 5 ) {
        return vec2( -0.045206, 0.257742 );
    } else if( i == 6 ) {
        return vec2( -0.270431, 0.026802 );
    } else if( i == 7 ) {
        return vec2( 0.904459, 0.832390 );

    } else if( i == 8 ) {
        return vec2( 0.271423, 0.434594 );
    } else if( i == 9 ) {
        return vec2( -0.716795, 0.213938 );
    } else if( i == 10 ) {
        return vec2( -0.967399, -0.514226 );
    } else if( i == 11 ) {
        return vec2( -0.725537, 0.608354 );

    } else if( i == 12 ) {
        return vec2( -0.686642, -0.198111 );
    } else if( i == 13 ) {
        return vec2( -0.740419, -0.782382 );
    } else if( i == 14 ) {
        return vec2( 0.997849, -0.563486 );
    } else if( i == 15 ) {
        return vec2( 0.025865, 0.678224 );

    } else if( i == 16 ) {
        return vec2( 0.225280, -0.407937 );
    } else if( i == 17 ) {
        return vec2( 0.275105, 0.048574 );
    } else if( i == 18 ) {
        return vec2( -0.012834, 0.945550 );
    } else if( i == 19 ) {
        return vec2( -0.414966, 0.542715 );

    } else if( i == 20 ) {
        return vec2( 0.053490, 0.539828 );
    } else if( i == 21 ) {
        return vec2( -0.199543, 0.783059 );
    } else if( i == 22 ) {
        return vec2( -0.433371, -0.295083 );
    } else if( i == 23 ) {
        return vec2( 0.615449, 0.838053 );

    } else if( i == 24 ) {
        return vec2( -0.860489, 0.898654 );
    } else if( i == 25 ) {
        return vec2( 0.051991, -0.827888 );
    } else if( i == 26 ) {
        return vec2( -0.615572, 0.326454 );
    } else if( i == 27 ) {
        return vec2( 0.780465, -0.302214 );

    } else if( i == 28 ) {
        return vec2( -0.871657, -0.959954 );
    } else if( i == 29 ) {
        return vec2( -0.084597, -0.873808 );
    } else if( i == 30 ) {
        return vec2( -0.523440, 0.941268 );
    } else if( i == 31 ) {
        return vec2( 0.804416, 0.701840 );
    }
}

int rand( vec2 seed ) {
    return int( 32 * fract( sin( dot( vec2( 12.9898, 72.233 ), seed ) ) * 43758.5453 ) );
}

//Implements the Percentage-Closer Soft Shadow algorithm, as defined by nVidia
//Implemented by DethRaid - github.com/DethRaid
float calcPenumbraSize( vec3 shadowCoord ) {
	float dFragment = shadowCoord.z;
	float dBlocker = 0;
	float penumbra = 0;
	float wLight = 0.5;

	// Sample the shadow map 8 times
	float temp;
	float count = 0;

	for( int i = 0; i < 32; i++ ) {    
		temp = texture2D( shadow, shadowCoord.st + (poisson( i ) *  0.005 ) ).r;
		if( temp < dFragment ) {
            dBlocker += temp;
			count += 1.0;
		}
	}

	if( count > 0.1 ) {
		dBlocker /= count;
		penumbra = wLight * (dFragment - dBlocker) / dFragment;
	}
    
    return penumbra * 0.1;
}

float calcShadowing( inout Pixel pixel ) {
    vec3 shadowCoord = calcShadowCoordinate( pixel );
    
    if( shadowCoord.x > 1 || shadowCoord.x < 0 ||
        shadowCoord.y > 1 || shadowCoord.y < 0 ) {
        return 1;
    }
    
#if SHADOW_QUALITY == HARD
    float shadowDepth = texture2D( shadow, shadowCoord.st ).r;
    return step( shadowCoord.z - shadowDepth, SHADOW_BIAS );
    
#else
    float penumbraSize = 0.0049;
    
#if SHADOW_QUALITY == REALISTIC
    penumbraSize = calcPenumbraSize( shadowCoord );
#endif
    
    float visibility = 1.0;

#if SHADOW_FILTER == PCF_FIXED
    int kernelSizeHalf = 4;
    float sub = 1.0 / 81.0;
    penumbraSize *= 500;

#else
    int kernelSize = int( min( penumbraSize * shadowMapResolution * 2, MAX_PCF_SAMPLES ) );
    int kernelSizeHalf = kernelSize / 2;
    float sub = 1.0 / (4 * kernelSizeHalf * kernelSizeHalf);
#endif

	for( int i = -kernelSizeHalf; i < kernelSizeHalf + 1; i++ ) {
        for( int j = -kernelSizeHalf; j < kernelSizeHalf + 1; j++ ) {
            vec2 sampleCoord = vec2( j, i ) / shadowMapResolution;
#if SHADOW_FILTER == PCF_FIXED
            sampleCoord *= penumbraSize;
#endif
            float shadowDepth = texture2D( shadow, shadowCoord.st + sampleCoord ).r;
            visibility -= (1.0 - step( shadowCoord.z - shadowDepth, SHADOW_BIAS )) * sub;
        }
	}

    visibility = max( visibility, 0 );

    return visibility;
#endif
}

vec3 fresnel( vec3 specularColor, float hdotl ) {
    return specularColor + (vec3( 1.0 ) - specularColor) * pow( 1.0f - hdotl, 5 );
}

vec3 calcDirectLighting( in Pixel pixel ) {
    //data that's super important to the shading algorithm
    vec3 albedo = pixel.color;
    vec3 normal = pixel.normal;
    float specularPower = pow( 10 * pixel.smoothness + 1, 2 );  //yeah
    float metalness = pixel.metalness;
    vec3 specularColor = pixel.color * metalness + (1 - metalness) * vec3( 1.0 );
    specularColor *= pixel.smoothness;

    //Other useful value
    vec3 viewVector = normalize( cameraPosition - pixel.position.xyz );
    viewVector = (gbufferModelView * vec4( viewVector, 0 )).xyz;
    vec3 half = normalize( lightVector + viewVector );
    float specularNormalization = (specularPower + 2.0) / 8.0;


    float ndotl = dot( normal, lightVector );
    float ndoth = dot( normal, half );
    float vdoth = dot( viewVector, half );

    ndotl = max( 0, ndotl );
    ndoth = max( 0, ndoth ); 

    //calculate diffuse lighting
    vec3 lambert = albedo * ndotl;

    vec3 fresnel = fresnel( specularColor, vdoth );

    //microfacet slope distribution
    //Or, how likely is it that microfacets are oriented toward the half vector  
    float d = pow( ndoth, specularPower );

    vec3 specular = fresnel * specularNormalization * d * ndotl;

    lambert = (vec3( 1.0 ) - specular) * lambert * (1 - metalness);

    //use skyLighting as a maximum amount of direct lighting
    vec3 directLighting = (lambert + specular) * lightColor * getSkyLighting();

#if SHADOW_QUALITY != OFF
    directLighting *= calcShadowing( pixel );
#endif
    //return vec3( getSkyLighting() );
    return directLighting;
}

vec2 texelToScreen( vec2 texel ) {
    float newx = texel.x / viewWidth;
    float newy = texel.y / viewHeight;
    return vec2( newx, newy );
}

//calcualtes the lighting from the torches
vec3 calcTorchLighting( in Pixel pixel ) {
    //determine if there is a gradient in the torch lighting
    float t1 = texture2D( gaux2, coord ).g - texture2D( gaux2, coord + texelToScreen( vec2( 1, 0 ) ) ).g - 0.1;
    float t2 = texture2D( gaux2, coord ).g - texture2D( gaux2, coord + texelToScreen( vec2( 0, 1 ) ) ).g - 0.1;
    t1 = max( t1, 0 );
    t2 - max( t2, 0 );
    float t3 = max( t1, t2 );
    float torchMul = step( t3, 0.1 );

    float torchFac = texture2D( gaux2, coord ).g; 
    vec3 torchColor = vec3( 1, 0.6, 0.4 ) * torchFac;
    float torchIntensity = length( torchColor );
    torchIntensity = pow( torchIntensity, 2 );
    torchColor *= torchIntensity;
    return torchColor * (1 - pixel.metalness);
}

///////////////////////////////////////////////////////////////////////////////
//                              Main Functions                               //
///////////////////////////////////////////////////////////////////////////////

Pixel fillPixelStruct() {
    Pixel pixel;
    pixel.position =        getWorldSpacePosition();
    pixel.normal =          getNormal();
    pixel.color =           getColor();
    pixel.metalness =       getMetalness();
    pixel.smoothness =      getSmoothness();
    pixel.skipLighting =    shouldSkipLighting();
    pixel.water =           getWater();
    pixel.directLighting =  vec3( 0 );
    pixel.torchLighting =   vec3( 0 );
    
    return pixel;
}

void calcSSAO( inout Pixel pixel ) {
    float ssaoFac = SSAO_STRENGTH;
    float compareDepth = getDepthLinear( coord );

    float radiusx = SSAO_RADIUS / (viewWidth * compareDepth);
    float radiusy = SSAO_RADIUS / (viewHeight * compareDepth);
    vec2 sampleScale = vec2( radiusx, radiusy );

    float occlusionPerSample = ssaoFac / float( SSAO_SAMPLES ); 
    
    vec3 colorAccum = vec3( 0 );

    vec2 sampleCoord;
    for( int i = 0; i < SSAO_SAMPLES; i++ ) {
        sampleCoord = poisson( rand( coord * 1 ) );
        sampleCoord *= sign( dot( sampleCoord, pixel.normal.xy ) );
        sampleCoord = sampleCoord * sampleScale + coord;
        float depthDiff = compareDepth - getDepthLinear( sampleCoord );
        colorAccum += texture2D( gcolor, sampleCoord ).rgb;
        if( depthDiff > 0.05 && depthDiff < SSAO_MAX_DEPTH ) {
            ssaoFac -= occlusionPerSample * (1 - (depthDiff / SSAO_MAX_DEPTH));
        }
    }

    ssaoFac = max( ssaoFac, 0 );
    
    colorAccum /= SSAO_SAMPLES;
    pixel.color = pixel.color * 0.8 + colorAccum * 0.2;
    
    //pixel.directLighting *= ssaoFac;
    pixel.torchLighting *= ssaoFac;
}

vec3 calcSkyScattering( in vec3 color, in float z ) {
    float fogFac = z * 0.00025;
    return fogColor * fogFac + color * (1 - fogFac);
}

vec3 calcLitColor( in Pixel pixel ) { 
    vec3 ambientColorCorrected = ambientColor + vec3( 0.5 ) * pixel.metalness;
    ambientColorCorrected *= getSkyLighting();
    return pixel.color * pixel.directLighting + 
           pixel.color * pixel.torchLighting * (1.0 - length( pixel.directLighting ) / length( lightColor )) +
           pixel.color * ambientColorCorrected;
}

float luma( in vec3 color ) {
    return dot( color, vec3( 0.2126, 0.7152, 0.0722 ) );
}

vec3 unchartedTonemap( in vec3 color ) {
    float a = vec3( 0.15 );
    float b = vec3( 0.50 );
    float c = vec3( 0.10 );
    float d = vec3( 0.20 );
    float e = vec3( 0.02 );
    float f = vec3( 0.30 );
    return ((color * (a * color + c * b) + d * e) / (color * (a * color + b) + d * f)) - e / f;
}

vec3 doToneMapping( in vec3 color ) {
    //return unchartedTonemap( color );
    float lumac = luma( color );
    float lWhite = 2.4;

    float lumat = (lumac * (1.0 + (lumac / (lWhite * lWhite) ))) / (1.0 + lumac );
    float scale = lumat / lumac;
    return color * scale;
}

void main() {
    curFrag = fillPixelStruct();
    vec3 finalColor = vec3( 0 );
    
    if( !curFrag.skipLighting ) {
        curFrag.directLighting = calcDirectLighting( curFrag );
        curFrag.torchLighting = calcTorchLighting( curFrag );
    
#if SSAO
        calcSSAO( curFrag );
#endif

        finalColor = calcLitColor( curFrag );
        finalColor = doToneMapping( finalColor );
        //finalColor = calcSkyScattering( finalColor, curFrag.position.z );
    } else {
        finalColor = curFrag.color; 
    }
    
    gl_FragData[0] = texture2D( gcolor, coord );
    gl_FragData[1] = texture2D( gdepth, coord );
    gl_FragData[2] = texture2D( gnormal, coord );
    
    gl_FragData[3] = vec4( finalColor, 1 );
    
    gl_FragData[4] = texture2D( gaux1, coord );
    gl_FragData[5] = texture2D( gaux2, coord );
    gl_FragData[6] = texture2D( gaux3, coord );
    
}
