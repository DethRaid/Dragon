#version 120

///////////////////////////////////////////////////////////////////////////////
//                              Unchangable Variables                        //
///////////////////////////////////////////////////////////////////////////////
const int   shadowMapResolution     = 4096;
const float shadowDistance          = 120.0;
const bool  generateShadowMipmap    = false;
const float shadowIntervalSize      = 4.0;
const bool  shadowHardwareFiltering = false;
const bool  shadowtexNearest     = true;

const int   noiseTextureResolution  = 64;

const float sunPathRotation         = 25.0;
const float ambientOcclusionLevel   = 0.2;

const int 	R8 						= 0;
const int 	RG8 					= 0;
const int 	RGB8 					= 1;
const int 	RGB16 					= 2;
const int 	gcolorFormat 			= RGB16;
const int 	gdepthFormat 			= RGB8;
const int 	gnormalFormat 			= RGB16;
const int 	compositeFormat 		= RGB16;
const int   gaux1Format             = RGB16;

///////////////////////////////////////////////////////////////////////////////
//                              Changable Variables                          //
///////////////////////////////////////////////////////////////////////////////

#define OFF            -1
#define HARD            0
#define SOFT            1
#define REALISTIC       2

#define POISSON         0
#define PCF             1

#define PI              3.14159265
#define E               2.71828183

#define SHADOW_QUALITY  REALISTIC
#define SHADOW_BIAS     0.0065
#define SHADOW_FILTER   PCF
#define MAX_PCF_SAMPLES 20              //make this number smaller for better performance at the expence of realism
#define PCSS_SAMPLES    32              //don't make this number greater than 32. You'll just waste GPU time

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
    bool isWater;
    
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

bool getWater() {
    return texture2D( gaux2, coord ).b > 0.5;
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
	if ( i == 0 ) {
        return vec2( -0.4994766, -0.4100508 );
    } else if( i == 1 ) {
        return vec2(  0.1725386, -0.50636 );
    } else if( i == 2 ) {
        return vec2( -0.3050305,  0.7459931 );
    } else if( i == 3 ) {
        return vec2(  0.3256707,  0.2347208 );

    } else if( 1 == 4 ) {
        return vec2( -0.1094937, -0.752005 );
    } else if( i == 5 ) {
        return vec2(  0.5059697, -0.7294227 );
    } else if( i == 6 ) {
        return vec2( -0.3904303,  0.5678311 );
    } else if( i == 7 ) {
        return vec2(  0.3405131,  0.4458854 );
  
    } else if( i == 8 ) {
        return vec2( -0.163072,  -0.9741971 );
    } else if( i == 9 ) {
        return vec2(  0.4260757, -0.02231212 );
    } else if( i == 10 ) {
        return vec2( -0.8977778,  0.1717084 );
    } else if( i == 11 ) {
        return vec2(  0.02903906, 0.3999698 );
        
    } else if( i == 12 ) { 
        return vec2( -0.4680224, -0.4418066 );
    } else if( i == 13 ) {
        return vec2(  0.09780561, -0.1236207 );
    } else if( i == 14 ) {
        return vec2( -0.3564819,  0.2770886 );
    } else if( i == 15 ) {
        return vec2(  0.0663829,  0.9336991 );
        
    } else if( i == 16 ) {
        return vec2( -0.8206947, -0.3301564 );
    } else if( i == 17 ) {
        return vec2(  0.1038207, -0.2167438 );
    } else if( i == 18 ) {
        return vec2( -0.3123821,  0.2344262 );
    } else if( i == 19 ) {
        return vec2(  0.1979104,  0.7830779 );
        
    } else if( i == 20 ) {
        return vec2( -0.6740047, -0.4649915 );
    } else if( i == 21 ) {
        return vec2(  0.08938109, -0.005763604 );
    } else if( i == 22 ) {
        return vec2( -0.6670403,  0.658087 );
    } else if( i == 23 ) {
        return vec2(  0.8211543,  0.365194 );
        
    } else if( i == 24 ) {
        return vec2( -0.8381009, -0.1279669 );
    } else if( i == 25 ) {
        return vec2(  0.6365152, -0.229197 );
    } else if( i == 26 ) {
        return vec2( -0.1748933,  0.1948632 );
    } else if( i == 27 ) {
        return vec2(  0.1710306,  0.5527771 );
        
    } else if( i == 28 ) {
        return vec2( -0.5874177, -0.1295959 );
    } else if( i == 29 ) {
        return vec2(  0.6305282, -0.5586912 );
    } else if( i == 30 ) {
        return vec2( -0.030519,  0.3487186 );
    } else {
        return vec2(  0.4240496, -0.1010172 );
    }
}

int rand( vec2 seed ) {
    return int( 32 * fract( sin( dot( vec2( 12.9898, 72.233 ), seed ) * 43758.5453 ) ) );
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
    
    return penumbra * 0.025;
}

float calcShadowing( inout Pixel pixel ) {
    vec3 shadowCoord = calcShadowCoordinate( pixel );
    
    if( shadowCoord.x > 1 || shadowCoord.x < 0 ||
        shadowCoord.y > 1 || shadowCoord.y < 0 ) {
        return 1;
    }
    
#if SHADOW_QUALITY == HARD
    float shadowDepth = texture2D( shadow, shadowCoord.st ).r;    
    if( shadowCoord.z - shadowDepth > SHADOW_BIAS ) {
        return 0;
    }
    
#elif SHADOW_QUALITY >= SOFT
    float penumbraSize = 3;

#if SHADOW_FILTER == PCF
    penumbraSize = 0.00049;
#endif
    
#if SHADOW_QUALITY == REALISTIC
    penumbraSize = calcPenumbraSize( shadowCoord );
#endif
    
    float visibility = 1.0;

#if SHADOW_FILTER == POISSON
    //penumbraSize *= 5.0;
    float sub = 1.0 / PCSS_SAMPLES;
    int shadowCount = 0;
	for( int i = 0; i < PCSS_SAMPLES; i++ ) {
        int ind = rand( coord * i );
        float shadowDepth = texture2D( shadow, shadowCoord.st + (penumbraSize * poisson( i )) ).r;
		if( shadowCoord.z - shadowDepth > SHADOW_BIAS ) {
			visibility -= sub;
		}
	}
#else
    //go from UV to texels
    int kernelSize = int( min( penumbraSize * shadowMapResolution * 5, MAX_PCF_SAMPLES ) );
    int kernelSizeHalf = kernelSize / 2;
    float sub = 1.0 / (4 * kernelSizeHalf * kernelSizeHalf);
    float shadowDepth;

    for( int i = -kernelSizeHalf; i < kernelSizeHalf; i++ ) {
        for( int j = -kernelSizeHalf; j < kernelSizeHalf; j++ ) {
            vec2 sampleCoord = vec2( j, i ) / shadowMapResolution;
            shadowDepth = texture2D( shadow, shadowCoord.st + sampleCoord ).r;
            if( shadowCoord.z - shadowDepth > SHADOW_BIAS ) {
                visibility -= sub;
            }
        }
    }
#endif

    visibility = max( visibility, 0 );
    //return 0;
    return visibility;
#endif
}

vec3 fresnel( vec3 specularColor, float hdotl ) {
    return specularColor + (vec3( 1.0 ) - specularColor) * pow( 1.0f - hdotl, 5 );
}

//Cook-Toorance shading
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
    vdoth = max( 0, vdoth );

    //calculate diffuse lighting
    vec3 lambert = albedo * ndotl;

    vec3 fresnel = fresnel( specularColor, vdoth );

    //microfacet slope distribution
    //Or, how likely is it that microfacets are oriented toward the half vector  
    float d = pow( ndoth, specularPower );

    vec3 specular = fresnel * specularNormalization * d * ndotl;
    
    //lambert = lambert * (1 - metalness) + albedo * metalness * 0.25;

    lambert = (vec3( 1.0 ) - specular) * lambert;

    vec3 directLighting = (lambert + specular) * lightColor;

#if SHADOW_QUALITY != OFF
  //  if( metalness < 0.5 ) {
        directLighting *= calcShadowing( pixel );
    //}
#endif
    return directLighting;
}

//calcualtes the lighting from the torches
vec3 calcTorchLighting( in Pixel pixel ) {
    float torchFac = texture2D( gdepth, coord ).g;
    vec3 torchColor = vec3( 1, 0.6, 0.4 ) * torchFac;
    float torchIntensity = min( length( torchColor ), 1.0 );
    torchIntensity = pow( torchIntensity, 2 );
    torchColor *= torchIntensity;
    return torchColor * (1 - pixel.metalness) * 1.0;
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
    pixel.isWater =         getWater();
    pixel.directLighting =  vec3( 0 );
    pixel.torchLighting =   vec3( 0 );
    
    return pixel;
}

vec2 texelToScreen( vec2 texel ) {
    float newx = texel.x / viewWidth;
    float newy = texel.y / viewHeight;
    return vec2( newx, newy );
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
    float fogFac = z * 0.0005;
    return fogColor * fogFac + color * (1 - fogFac);
}

vec3 calcLitColor( in Pixel pixel ) {
    return pixel.color * pixel.directLighting + 
           pixel.color * pixel.torchLighting +
           pixel.color * ambientColor;
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
    vec3 curr = unchartedTonemap( color * 2.0 );
    vec3 whiteScale = vec3( 1.0 ) / unchartedTonemap( vec3( 11.2 ) );

    return curr * whiteScale;
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
    } else {
        finalColor = curFrag.color;
    }

    //finalColor = calcSkyScattering( finalColor, curFrag.position.z );
    
    gl_FragData[0] = texture2D( gcolor, coord );
    gl_FragData[1] = texture2D( gdepth, coord );
    gl_FragData[2] = texture2D( gnormal, coord );
    
    gl_FragData[3] = vec4( finalColor, 1 );
//    gl_FragData[3] = vec4( texture2D( gnormal, coord ).a );
    
    gl_FragData[4] = texture2D( gaux1, coord );
    gl_FragData[5] = texture2D( gaux2, coord );
    gl_FragData[6] = texture2D( gaux3, coord );
    
}
