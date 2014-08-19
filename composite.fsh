#version 120

///////////////////////////////////////////////////////////////////////////////
//                              Unchangable Variables                        //
///////////////////////////////////////////////////////////////////////////////
const int   shadowMapResolution     = 2048;
const float shadowDistance          = 120.0;
const bool  shadowHardwareFiltering = false;
const int   noiseTextureResolution  = 64;


///////////////////////////////////////////////////////////////////////////////
//                              Changable Variables                          //
///////////////////////////////////////////////////////////////////////////////

#define HARD            0
#define SOFT            1
#define REALISTIC       2
#define SHADOW_QUALITY  REALISTIC
#define SHADOW_BIAS     0.0065
#define PCSS_SAMPLES    32              //don't make this number greater than 32. You'll just waste GPU time

#define SSAO            true
#define SSAO_RADIUS     2.0             //search a 2-unit radius hemisphere
#define SSAO_MAX_DEPTH  2.0             //if a sample's depth is within 2 units of the world depth, the sample is
                                        //obscured
#define SSAO_SAMPLES    16.0            //16 samples is pretty good, right? MUST be a multiple of four

///////////////////////////////////////////////////////////////////////////////
//                              I need these                                 //
///////////////////////////////////////////////////////////////////////////////

uniform sampler2D gcolor;
uniform sampler2D gdepthtex;
uniform sampler2D gdepth;
uniform sampler2D gnormal;

uniform sampler2D shadow;

uniform sampler2D noisetex;

uniform vec3 cameraPosition;

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
    return texture2D( gdepth, coord ).r > 0.5;
}

bool getWater() {
    return texture2D( gdepth, coord ).b > 0.5;
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
        return vec2( -0.1094937, -0.752005 );
    } else if( i == 1 ) {
        return vec2( 0.5059697, -0.7294227 );
    } else if( i == 2 ) {
     	return vec2( -0.3904303, 0.5678311 );
    } else if( i == 3 ) {
        return vec2( -0.3050305, 0.7459931 );
    } else if( 1 == 4 ) {
	    return vec2( 0.1725386, -0.50636 );
    } else if( i == 5 ) {
        return vec2( 0.1979104, 0.7830779 );
    } else if( i == 6 ) {
        return vec2( 0.0663829, 0.9336991 );
    } else if( i == 7 ) {
        return vec2( -0.163072, -0.9741971 );
    } else if( i == 8 ) {
        return vec2( 0.1710306, 0.5527771 );
    } else if( i == 9 ) {
        return vec2( 0.02903906, 0.3999698 );
    } else if( i == 10 ) {
        return vec2( -0.1748933, 0.1948632 );
    } else if( i == 11 ) {
        return vec2( -0.3564819, 0.2770886 );
    } else if( i == 12 ) {
	    return vec2( -0.4994766, -0.4100508 );
    } else if( i == 13 ) {
        return vec2( 0.6305282, -0.5586912 );
    } else if( i == 14 ) {
        return vec2( -0.5874177, -0.1295959 );
    } else if( i == 15 ) {
        return vec2( 0.4260757, -0.02231212 );
    } else if( i == 16 ) {
        return vec2( -0.8381009, -0.1279669 );
    } else if( i == 17 ) {
        return vec2( -0.8977778, 0.1717084 );
    } else if( i == 18 ) {
        return vec2( 0.8211543, 0.365194 );
    } else if( i == 19 ) {
        return vec2( 0.6365152, -0.229197 );
    } else if( i == 20 ) {
        return vec2( -0.8206947, -0.3301564 );
    } else if( i == 21 ) {
        return vec2( 0.08938109, -0.005763604 );
    } else if( i == 22 ) {
        return vec2( -0.3123821, 0.2344262 );
    } else if( i == 23 ) {
        return vec2( 0.1038207, -0.2167438 );
    } else if( i == 24 ) {
        return vec2( 0.3256707, 0.2347208 );
    } else if( i == 25 ) {
        return vec2( 0.3405131, 0.4458854 );
    } else if( i == 26 ) {
        return vec2( -0.6740047, -0.4649915 );
    } else if( i == 27 ) {
        return vec2( -0.6670403, 0.658087 );
    } else if( i == 28 ) {
        return vec2( -0.4680224, -0.4418066 );
    } else if( i == 29 ) {
        return vec2( 0.09780561, -0.1236207 );
    } else if( i == 30 ) {
        return vec2( -0.030519, 0.3487186 );
    } else {
        return vec2( 0.4240496, -0.1010172 );
    }
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
    
	for( int i = 0; i < 8; i++ ) {    
		temp = texture2D( shadow, shadowCoord.st + (poisson( i ) * 0.001 ) ).r;
		if( temp < dFragment ) {
            dBlocker += temp;
			count += 1.0;
		}
	}

	if( count > 0.1 ) {
		dBlocker /= count;
		penumbra = wLight * (dFragment - dBlocker) / dFragment;
	}
    
    return penumbra;
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
    }
    
#elif SHADOW_QUALITY >= SOFT
    float penumbraSize = 3.0;
    
#if SHADOW_QUALITY == REALISTIC
    penumbraSize = calcPenumbraSize( shadowCoord );
#endif
    
    float visibility = 1.0;
    float sub = 1.0 / PCSS_SAMPLES;
    int shadowCount = 0;
	for( int i = 0; i < PCSS_SAMPLES; i++ ) {
        float shadowDepth = texture2D( shadow, shadowCoord.st + (penumbraSize * poisson( i ) * 0.005) ).r;
		if( shadowCoord.z - shadowDepth > SHADOW_BIAS ) {
			visibility -= sub;
		}
	}
    
    pixel.directLighting *= visibility;
#endif
}

void calcDirectLighting( inout Pixel pixel ) { 
    vec3 normal = normalize( texture2D( gnormal, coord ).xyz * 2.0 - 1.0 );
    float ndotl = dot( lightVector, normal );
    ndotl = clamp( ndotl, 0, 1 );
    pixel.directLighting = lightColor * ndotl;
    if( ndotl > 0.1 ) {
        calcShadowing( pixel );
    }
}

//calcualtes the lighting from the torches
void calcTorchLighting( inout Pixel pixel ) {
    vec3 torchColor = vec3( 1, 0.9, 0.5 );
    pixel.torchLighting = torchColor * texture2D( gdepth, coord ).g;
}

void calcAmbientLighting( inout Pixel pixel ) {
    pixel.ambientLighting = vec3( 0.15, 0.17, 0.2 );
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

vec2 rand( int i ) {
    float x = fract( sin( i * 9823.234 ) );
    float y = fract( sin( i * 323.4352 ) );
    return vec2( x, y );
}

void calcSSAO( inout Pixel pixel ) {
    //SSAO from http://john-chapman-graphics.blogspot.com/2013/01/ssao-tutorial.html
    float ssaoFac = 1.0;
    
    //OSX can deal with it
    vec3 kernel[int(SSAO_SAMPLES)];
    
    //generate a kernel
    for( int i = 0; i < SSAO_SAMPLES; i++ ) {
        float scale = float( i ) / SSAO_SAMPLES;
        scale = mix( 0.1, 1.0, scale * scale );
        kernel[i] = normalize( vec3( rand( i ), 0 ) ) * scale;
    }
    
    vec3 rvec = texture2D( noisetex, coord ).xyz * 2.0 - 1.0;
    vec3 tangent = normalize( rvec - pixel.normal * dot( rvec, pixel.normal ) );
    vec3 bitangent = cross( pixel.normal, tangent );
    mat3 tbn = mat3( tangent.x, bitangent.x, pixel.normal.x,
                     tangent.y, bitangent.y, pixel.normal.y,
                     tangent.z, bitangent.z, pixel.normal.z );
    
    for( int i = 0; i < SSAO_SAMPLES; i++ ) {
        vec3 sample = tbn * kernel[i];
        sample = sample * SSAO_RADIUS + pixel.position.xyz;
        
        vec4 offset = vec4( sample, 1.0 );
        offset = gbufferProjection * offset;
        offset.xy /= offset.w;
        offset.xy = offset.xy * 0.5 + 0.5;
        
        float sampleDepth = texture2D( gdepth, offset.st ).r;
        
        if( abs( pixel.position.z - sampleDepth ) < SSAO_MAX_DEPTH ) {
            if( sampleDepth <= sample.z ) {
                ssaoFac -= 1.0 / SSAO_SAMPLES;
            }
        }
    }
    
    pixel.directLighting *= ssaoFac;
    pixel.torchLighting *= ssaoFac;
    
    pixel.directLighting = vec3( ssaoFac );
}

vec3 calcLitColor( in Pixel pixel ) {
    vec3 color = pixel.color * pixel.directLighting + 
                 pixel.color * pixel.torchLighting + 
                 pixel.color * pixel.ambientLighting;
    return color / 2;
}

void main() {
    Pixel pixel;
    vec3 finalColor;
    
    fillPixelStruct( pixel );
    
    if( !pixel.skipLighting ) {
        calcDirectLighting( pixel );
        calcTorchLighting( pixel );
        calcAmbientLighting( pixel );
    
        calcSSAO( pixel );
    
        finalColor = calcLitColor( pixel );
    } else {
        finalColor = pixel.color;
    }

    gl_FragData[3] = vec4( pixel.directLighting, 1 );
}
