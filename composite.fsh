#version 120

///////////////////////////////////////////////////////////////////////////////
//                              Unchangable Variables                        //
///////////////////////////////////////////////////////////////////////////////
const int   shadowMapResolution     = 2048;
const float shadowDistance          = 120.0;
const bool  shadowHardwareFiltering = false;
const int   noiseTextureResolution  = 64;

const float sunPathRotation         = 25.0;

///////////////////////////////////////////////////////////////////////////////
//                              Changable Variables                          //
///////////////////////////////////////////////////////////////////////////////

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
#define PCSS_SAMPLES    20              //don't make this number greater than 32. You'll just waste GPU time

#define SSAO            true
#define SSAO_SAMPLES    32               //more samples = prettier
#define SSAO_STRENGTH   1.0             //bigger number = more SSAO
#define SSAO_RADIUS     150.0             //search a 2-unit radius hemisphere
#define SSAO_MAX_DEPTH  1.0             //if a sample's depth is within 2 units of the world depth, the sample is
                                        //obscured

///////////////////////////////////////////////////////////////////////////////
//                              I need these                                 //
///////////////////////////////////////////////////////////////////////////////

uniform sampler2D gcolor;
uniform sampler2D gdepthtex;
uniform sampler2D gnormal;
uniform sampler2D gaux2;

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

struct Pixel {
    vec4 position;
    vec4 screenPosition;
    vec3 color;
    vec3 normal;
    float reflectivity;
    float smoothness;
    bool isWater;
    
    bool skipLighting;
    
    vec3 directLighting;
    vec3 torchLighting;
    vec3 ambientLighting;
};

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
    return texture2D( gcolor, coord ).rgb;
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

float getReflectivity() {
    return texture2D( gnormal, coord ).a;
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

void calcShadowing( inout Pixel pixel ) {
    vec3 shadowCoord = calcShadowCoordinate( pixel );
    
    if( shadowCoord.x > 1 || shadowCoord.x < 0 ||
        shadowCoord.y > 1 || shadowCoord.y < 0 ) {
        return;
    }
    
#if SHADOW_QUALITY == HARD
    float shadowDepth = texture2D( shadow, shadowCoord.st ).r;    
    if( shadowCoord.z - shadowDepth > SHADOW_BIAS ) {
        pixel.directLighting = vec3( 0 );
        return;
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
    float sub = 1.0 / PCSS_SAMPLES;
    int shadowCount = 0;
	for( int i = 0; i < PCSS_SAMPLES; i++ ) {
        int ind = rand( coord * i );
        float shadowDepth = texture2D( shadow, shadowCoord.st + (penumbraSize * poisson( ind )) ).r;
		if( shadowCoord.z - shadowDepth > SHADOW_BIAS ) {
			visibility -= sub;
		}
	}
#else
    //go from UV to texels
    int kernelSize = int( penumbraSize * shadowMapResolution * 5 );
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
    pixel.directLighting *= visibility;
#endif
}

//Cook-Toorance shading
void calcDirectLighting( inout Pixel pixel ) { 
    vec3 normal = pixel.normal;
    vec3 viewVector = normalize( cameraPosition - pixel.position.xyz );
    viewVector = (gbufferModelView * vec4( viewVector, 0 )).xyz;
    vec3 half = normalize( lightVector + viewVector );

    float ndotl = dot( normal, lightVector );
    float ndoth = dot( normal, half );
    float ndotv = dot( normal, viewVector );
    float vdoth = dot( viewVector, half );

    float fresnel = dot( normal, viewVector ) * (1 - pixel.reflectivity);
    fresnel += pixel.reflectivity;
    
    //geometric attenuation factor
    float g = min( 1, 2 * ndoth * ndotv / vdoth );
    g = min( g, 2 * ndoth * ndotl / vdoth );

    //microfacet slope distribution
    //Or, how likely is it that microfactes are oriented toward the half vector
    //Using a Beckmann distribution because accuracy
    float m = 1.1 - pixel.smoothness;
    float alpha = acos( ndoth );
    float d = pow( E, -pow( (tan( alpha ) / m), 2 ) ) / (m * m * pow( ndoth, 4 ));

    float cook = pixel.reflectivity * pixel.smoothness * fresnel * d * g / (2 * PI * ndotv);
    cook = max( cook, 0 );
    
    ndotl = max( ndotl, 0 );

    pixel.directLighting = lightColor * (ndotl + cook);
//    pixel.directLighting = vec3( cook );
    calcShadowing( pixel );
}

//calcualtes the lighting from the torches
void calcTorchLighting( inout Pixel pixel ) {
    vec3 torchColor = vec3( 1, 0.80, 0.5 );
    pixel.torchLighting = torchColor * texture2D( gaux2, coord ).g;
}

void calcAmbientLighting( inout Pixel pixel ) {
    pixel.ambientLighting = vec3( 0.15, 0.17, 0.2 ) * 1.5;
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
    pixel.isWater =         getWater();
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

    vec2 sampleCoord;
    for( int i = 0; i < SSAO_SAMPLES; i++ ) {
        sampleCoord = poisson( rand( coord * i ) );
        sampleCoord *= sign( dot( sampleCoord, pixel.normal.xy ) );
        sampleCoord = sampleCoord * sampleScale + coord;
        float depthDiff = compareDepth - getDepthLinear( sampleCoord );
        if( depthDiff > 0.05 && depthDiff < SSAO_MAX_DEPTH ) {
            ssaoFac -= occlusionPerSample * (1 - (depthDiff / SSAO_MAX_DEPTH));
        }
    }

    ssaoFac = max( ssaoFac, 0 );
    
    pixel.directLighting *= ssaoFac;
    pixel.torchLighting *= ssaoFac;
    pixel.ambientLighting *= ssaoFac;
}

void calcSkyScattering( inout Pixel pixel ) {
    float fogFac = -pixel.position.z * 0.00005;
    pixel.color = vec3( 0.529, 0.808, 0.980 ) * fogFac + pixel.color * (1 - fogFac);
}

vec3 calcLitColor( in Pixel pixel ) {
    vec3 color = pixel.color * pixel.directLighting + 
                 pixel.color * pixel.torchLighting + 
                 pixel.color * pixel.ambientLighting;
    return color / 1.75;
}

void main() {
    Pixel pixel;
    vec3 finalColor;
    
    fillPixelStruct( pixel );
    
    if( !pixel.skipLighting ) {
        calcDirectLighting( pixel );
        calcTorchLighting( pixel );
        calcAmbientLighting( pixel );
    
//        calcSSAO( pixel );

        calcSkyScattering( pixel );
    
        finalColor = calcLitColor( pixel );
    } else {
        finalColor = pixel.color;
    }

    gl_FragData[3] = vec4( finalColor, 1 );
//  gl_FragData[3] = vec4( pixel.directLighting, 1 );
}
