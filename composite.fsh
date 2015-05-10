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

const int 	 R8 					= 0;
const int 	 RG8 					= 0;
const int 	 RGB8 					= 1;
const int 	 RGB16 					= 2;
const int    RGBA16                 = 3;
const int    RGBA8                  = 4;
const int    RGBA16F                = 5;

const int 	gcolorFormat 			= RGB16;
const int 	gdepthFormat 			= RGBA16;
const int 	gnormalFormat 			= RGBA16F;
const int 	compositeFormat 		= RGBA16F;

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

#define SHADOW_QUALITY  HARD
#define SHADOW_BIAS     0.0065
#define SHADOW_FILTER   PCF_FIXED
#define MAX_PCF_SAMPLES 20 //make this number smaller for better performance at the expense of realism

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
uniform sampler2D composite;
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
    float R0;
    
    vec3 directLighting;
    vec3 torchLighting;
    vec3 skyLighting;
    float emission;
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

float getEmission() {
    return texture2D( gaux2, coord ).b;
}

float getWaterDepth() {
    return texture2D( gaux3, coord ).r;
}

float getSmoothness() {
    return texture2D( gaux1, coord ).g;
}

float getR0() {
    return texture2D( gaux1, coord ).r;
}

vec3 getNormal() {
    return normalize( texture2D( gdepth, coord ).xyz * 2.0 - 1.0 );
}

float getMetalness() {
    return texture2D( gaux1, coord ).b;
}

float getSkyLighting() {
    return max( texture2D( gaux2, coord ).g, 0.1 ) * ambientColor;
}

float getTorchLighting( in vec2 incoord ) {
    return texture2D( gaux2, incoord ).r;
}

float getTerrainDepth() {
    return texture2D( gdepth, coord ).b;
}

float luma( vec3 color ) {
    return dot( color, vec3( 0.2126, 0.7152, 0.0722 ) );
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

	for( int i = -2; i < 3; i++ ) {
        for( int j = -2; j < 3; j++ )
		temp = texture2D( shadow, shadowCoord.st + (vec2( i, j ) / shadowMapResolution) ).r;
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
        return 1.0;
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

void calcDirectLighting( inout Pixel pixel ) {
    //data that's super important to the shading algorithm
    vec3 albedo = pixel.color;
    vec3 normal = pixel.normal;
    float specularPower = pow( 2, 10 * pixel.smoothness + 1 );
    vec3 specularColor = pixel.color * pixel.metalness + 
        (1 - pixel.metalness) * vec3( 1.0 );
    specularColor *= pixel.R0 * pixel.smoothness * pixel.smoothness;

    //Other useful value
    vec3 viewVector = normalize( cameraPosition - pixel.position.xyz );
    viewVector = (gbufferModelView * vec4( viewVector, 0 )).xyz;
    vec3 halfVec = normalize( lightVector + viewVector );
    float specularNormalization = (specularPower + 2.0) / 8.0;


    float ndotl = dot( normal, lightVector );
    float ndoth = dot( normal, halfVec );
    float vdoth = dot( viewVector, halfVec );

    ndotl = max( 0, ndotl );
    ndoth = max( 0, ndoth ); 

    //calculate diffuse lighting
    vec3 lambert = albedo * ndotl * (1.0 - luma( specularColor ));

    vec3 fresnel = fresnel( specularColor, vdoth );

    //microfacet slope distribution
    //Or, how likely is it that microfacets are oriented toward the half vector  
    float d = pow( ndoth, specularPower );

    vec3 specular = fresnel * specularNormalization * d;// * ndotl;

    lambert = (vec3( 1.0 ) - specular) * lambert;// * (1.0 - pixel.metalness);

    //use skyLighting as a maximum amount of direct lighting
    vec3 directLighting = (lambert + specular) * lightColor;

#if SHADOW_QUALITY != OFF
    directLighting *= calcShadowing( pixel );
#endif
    pixel.directLighting = directLighting;
}

vec2 texelToScreen( vec2 texel ) {
    float newx = texel.x / viewWidth;
    float newy = texel.y / viewHeight;
    return vec2( newx, newy );
}

//calculates the lighting from the torches
void calcTorchLighting( inout Pixel pixel ) {
    //determine if there is a gradient in the torch lighting
    /*float t1 = getTorchLighting( coord ) - getTorchLighting( coord + texelToScreen( vec2( 1, 0 ) ) ) - 0.1;
    float t2 = getTorchLighting( coord ) - getTorchLighting( coord + texelToScreen( vec2( 0, 1 ) ) ) - 0.1;
    t1 = max( t1, 0 );
    t2 = max( t2, 0 );
    float t3 = max( t1, t2 );
    float torchMul = step( t3, 0.1 );*/

    float torchFac = getTorchLighting( coord ); 
    vec3 torchColor = vec3( 1, 0.6, 0.4 ) * torchFac;
    float torchIntensity = length( torchColor );
    torchIntensity *= torchIntensity;
    torchColor *= torchIntensity;
    pixel.torchLighting = torchColor * (1.0 - pixel.metalness);
}


void calcSkyLighting( inout Pixel pixel ) {
    vec3 ambientMetalFix = ambientColor + vec3( 0.5 ) * pixel.metalness;
    pixel.skyLighting = ambientMetalFix * getSkyLighting();
}

///////////////////////////////////////////////////////////////////////////////
//                              Main Functions                               //
///////////////////////////////////////////////////////////////////////////////

Pixel fillPixelStruct() {
    Pixel pixel;
    pixel.position          = getWorldSpacePosition();
    pixel.normal            = getNormal();
    pixel.color             = getColor();
    pixel.metalness         = getMetalness();
    pixel.smoothness        = getSmoothness();
    pixel.emission          = getEmission();
    pixel.R0                = getR0();
    
    pixel.directLighting    = vec3( 0 );
    pixel.torchLighting     = vec3( 0 );
    pixel.skyLighting       = vec3( 0 );
    
    return pixel;
}

vec3 calcSkyScattering( in vec3 color, in float z ) {
    float fogFac = z * 0.00025;
    return fogColor * fogFac + color * (1 - fogFac);
}

vec3 calcLitColor( in Pixel pixel ) {
    vec3 lit = pixel.color * pixel.directLighting + 
               pixel.color * pixel.torchLighting +
               pixel.color * pixel.skyLighting;
    return (lit * (1.0 - pixel.emission)) + (pixel.color * pixel.emission);
}

void main() {
    curFrag = fillPixelStruct();
    vec3 finalColor = vec3( 0 );
    
    calcDirectLighting( curFrag );
    calcTorchLighting( curFrag );
    calcSkyLighting( curFrag );

    finalColor = calcLitColor( curFrag );
    //finalColor = calcSkyScattering( finalColor, curFrag.position.z );
    
    gl_FragData[0] = texture2D( gcolor, coord );
    gl_FragData[1] = texture2D( gdepth, coord );
    
    gl_FragData[2] = vec4( finalColor, 1.0 );
    //gl_FragData[2] = vec4( vec3( curFrag.smoothness ), 1.0 );
    
    gl_FragData[3] = texture2D( composite, coord );
    gl_FragData[4] = texture2D( gaux1, coord );
    gl_FragData[5] = texture2D( gaux2, coord );
    gl_FragData[6] = texture2D( gaux3, coord );
    
}
