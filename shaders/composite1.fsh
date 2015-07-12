#version 120

/////////ADJUSTABLE VARIABLES///////////////////////////////////////////////////////////////////
/////////ADJUSTABLE VARIABLES///////////////////////////////////////////////////////////////////
#define SHADOW_MAP_BIAS 0.80f

/////////////////////////CONFIGURABLE VARIABLES////////////////////////////////////////////////////////
/////////////////////////CONFIGURABLE VARIABLES////////////////////////////////////////////////////////

#define GI
//#define NO_GI				//NOTE: You Must Delete Files Composite.fsh AND Composite.vsh to fully turn GI off

/* Dethraid's CHS variables */
#define HARD            0
#define PCF             1
#define PCSS            2
#define POISSON         3

/*
 * Make this number bigger for softer PCSS shadows. A value of 13 or 12 makes
 * shadows about like you'd see on Earth, a value of 50 or 60 is closer to what
 * you'd see if the Earth's sun was as big in the sky as Minecraft's
 */
#define LIGHT_SIZE                  15

/*
 * Defined the minimum about of shadow blur when PCSS is enabled. A value of
 * 0.175 allows for reasonably hard shadows with a very minimal amount of
 * aliasing, a value of 0.45 almost completely removes aliasing but doesn't
 * allow hard shadows when the distance from the shadow caster to the shadow
 * receiver is very small
 */
#define MIN_PENUMBRA_SIZE           0.175

/*
 * The number of samples to use for PCSS's blocker search. A higher value allows
 * for higher quality shadows at the expense of framerate
 */
#define BLOCKER_SEARCH_SAMPLES_HALF 5

/*
 * The number of samples to use for shadow blurring. More samples means blurrier
 * shadows at the expense of framerate. A value of 5 is recommended
 */
#define PCF_SIZE_HALF               5

/*
 * If set to 1, a random rotation will be applied to the shadow filter to reduce
 * shadow banding. If set to 0, no rotation will be applied to the shadow filter,
 * resulting in ugly banding but giving you a few more frames per second.
 */
#define USE_RANDOM_ROTATION         1

/*
 * How to filter the shadows. HARD produces hard shadows with no blurring. PCF
 * produces soft shadows with a constant-size blur. PCSS produces contact-hardening
 * shadows with a variable-size blur. PCSS is the most realistic option but also
 * the slowest, HARD is the fastest at the expense of realism.
 */
#define SHADOW_MODE                 PCSS

const bool 		shadowHardwareFiltering0 = false;
/* End of Dethraid's CHS variables */

#define RAIN_FOG

#define ATMOSPHERIC_FOG

//----------New 2D clouds----------//
#define CLOUD_PLANE					// 2D clouds

// Only enable one or the other not both//
#define STANDARD_CLOUDS				// Best for 3D clouds	Comment out if not using 3d clouds

#define CLOUD_COVERAGE 0.51f + rainy * 0.335f;			//to increase the 2Dclouds:" 0.59f + rainy * 0.35f " is Default when not using 3DClouds," 0.5f + rainy * 0.35f " is best for when using 2D and 3D clouds
//----------End CONFIGURABLE 2D Clouds----------//


//----------3D clouds----------//
#define VOLUMETRIC_CLOUDS
#define CLOUD_DISPERSE 10.0f          // increase this for thicker clouds and so that they don't fizzle away when you fly close to them, 10 is default Dont Go Over 30 will lag and maybe crash
//----------End CONFIGURABLE 3D Clouds----------//


//----------New Cloud Shadows----------//
//--Only enable one or the other not both--//
#define CLOUD_SHADOW
//----------End CONFIGURABLE Cloud Shadows----------//

#define HELD_LIGHT				//Dynamic Torch Light when in player hand

////----------This feature is connected to ATMOSPHERIC_FOG----------//
//#define NEW_UNDERWATER

//----------GodRays----------//
#define GODRAYS
	const float grdensity = 0.7;
	const int NUM_SAMPLES = 10;			//increase this for better quality at the cost of performance /10 is default
	const float grnoise = 1.0;		//amount of noise /1.0 is default

#define GODRAY_LENGTH 0.75			//default is 0.65, to increase the distance/length of the godrays at the cost of slight increase of sky brightness

#define MOONRAYS					//Make sure if you enable/disable this to do the same in Composite1, PLEASE NOTE Moonrays have a bug at sunset/sunrise

//#define NO_GODRAYS				//NOTE!! if you disable GODRAYS then you MUST enable this so the shader wont crash, Do the same in Composite1.fsh

//----------End CONFIGURABLE GodRays----------//

#define BETTER_SPECULAR
/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////
/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////

/////////INTERNAL VARIABLES///////////////////////////////////////////////////////////////////////
/////////INTERNAL VARIABLES///////////////////////////////////////////////////////////////////////
//Do not change the name of these variables or their type. The Shaders Mod reads these lines and determines values to send to the inner-workings
//of the shaders mod. The shaders mod only reads these lines and doesn't actually know the real value assigned to these variables in GLSL.
//Some of these variables are critical for proper operation. Change at your own risk.

const int 		shadowMapResolution 	= 4096;
const float 	shadowDistance 			= 160.0f;
const float 	shadowIntervalSize 		= 4.0f;
//const bool 		shadowHardwareFiltering0 = true;

const bool 		shadowtex1Mipmap = true;
const bool 		shadowtex1Nearest = true;
const bool 		shadowcolor0Mipmap = true;
const bool 		shadowcolor0Nearest = false;
const bool 		shadowcolor1Mipmap = true;
const bool 		shadowcolor1Nearest = false;

#ifdef NO_GODRAYS
const int 		R8 						= 0;
const int 		RG8 					= 0;
const int 		RGB8 					= 1;
const int 		RGB16 					= 2;
const int 		gcolorFormat 			= RGB16;
const int 		gdepthFormat 			= RGB8;
const int 		gnormalFormat 			= RGB16;
const int 		compositeFormat 		= RGB8;
#endif

#ifdef GODRAYS
const int 		RA8 					= 0;
const int 		RGA8 					= 0;
const int 		RGBA8 					= 1;
const int 		RGBA16 					= 1;
const int 		gcolorFormat 			= RGBA16;
const int 		gdepthFormat 			= RGBA8;
const int 		gnormalFormat 			= RGBA16;
const int 		compositeFormat 		= RGBA8;
#endif

const float 	eyeBrightnessHalflife 	= 10.0f;
const float 	centerDepthHalflife 	= 2.0f;
const float 	wetnessHalflife 		= 100.0f;
const float 	drynessHalflife 		= 40.0f;

const int 		superSamplingLevel 		= 0;

const float		sunPathRotation 		= -40.0f;
const float 	ambientOcclusionLevel 	= 0.5f;

const int 		noiseTextureResolution  = 64;
//END OF INTERNAL VARIABLES//

///* DRAWBUFFERS:013 */
const bool gaux1MipmapEnabled = true;
const bool gaux2MipmapEnabled = true;

#define BANDING_FIX_FACTOR 1.0f

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gdepthtex;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D shadow;
//uniform sampler2D shadowcolor;
uniform sampler2D noisetex;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
//uniform sampler2D gaux3;
//uniform sampler2D gaux4;

varying vec4 texcoord;
varying vec3 lightVector;
varying vec3 upVector;

uniform int worldTime;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 cameraPosition;
uniform vec3 upPosition;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform float sunAngle;
uniform vec3 skyColor;

uniform int   isEyeInWater;
uniform float eyeAltitude;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;
uniform int   fogMode;

varying float timeSunrise;
varying float timeNoon;
varying float timeSunset;
varying float timeMidnight;
varying float timeSkyDark;

varying vec3 colorSunlight;
varying vec3 colorSkylight;
varying vec3 colorSunglow;
varying vec3 colorBouncedSunlight;
varying vec3 colorScatteredSunlight;
varying vec3 colorTorchlight;
varying vec3 colorWaterMurk;
varying vec3 colorWaterBlue;
varying vec3 colorSkyTint;

uniform int heldBlockLightValue;

/////////////////////////FUNCTIONS///////////////////////////////////////////////////////////////////
/////////////////////////FUNCTIONS///////////////////////////////////////////////////////////////////

//Get gbuffer textures

vec3  	GetAlbedoGamma(in vec2 coord) {			//Function that retrieves the diffuse texture and leaves it in gamma space.
	return texture2D(gcolor, coord).rgb;
}

vec3  	GetAlbedoLinear(in vec2 coord) {			//Function that retrieves the diffuse texture and convert it into linear space.
	return pow(GetAlbedoGamma( coord ), vec3(2.2f));
}

vec3  	GetNormals(in vec2 coord) {				//Function that retrieves the screen space surface normals. Used for lighting calculations
	return texture2D(gnormal, texcoord.st).rgb * 2.0f - 1.0f;
}

float 	GetDepth(in vec2 coord) {					//Function that retrieves the scene depth. 0 - 1, higher values meaning farther away
	return texture2D(gdepthtex, coord).r;
}

float 	GetDepthLinear(in vec2 coord) {					//Function that retrieves the scene depth. 0 - 1, higher values meaning farther away
	return 2.0f * near * far / (far + near - (2.0f * texture2D(gdepthtex, coord).x - 1.0f) * (far - near));
}

float 	ExpToLinearDepth(in float depth) {
	return 2.0f * near * far / (far + near - (2.0f * depth - 1.0f) * (far - near));
}

//Lightmaps
float 	GetLightmapTorch(in vec2 coord) {			//Function that retrieves the lightmap of light emitted by emissive blocks like torches and lava
	float lightmap = texture2D(gdepth, coord).g;

	//Apply inverse square law and normalize for natural light falloff
	lightmap 		= clamp(lightmap * 1.10f, 0.0f, 1.0f);
	lightmap 		= 1.0f - lightmap;
	lightmap 		*= 5.6f;
	lightmap 		= 1.0f / pow((lightmap + 0.8f), 2.0f);
	lightmap 		-= 0.02435f;

	lightmap 		= max(0.0f, lightmap);
	lightmap 		*= 0.008f;
	lightmap 		= clamp(lightmap, 0.0f, 1.0f);
	lightmap 		= pow(lightmap, 0.9f);
	return lightmap;
}

float 	GetLightmapSky(in vec2 coord) {			//Function that retrieves the lightmap of light emitted by the sky. This is a raw value from 0 (fully dark) to 1 (fully lit) regardless of time of day
	return pow(texture2D(gdepth, coord).b, 4.3f);
}

float 	GetUnderwaterLightmapSky(in vec2 coord) {
	return texture2D(composite, coord).r;
}

float   getMetalness( in vec2 coord ) {
    return step( 0.25, texture2D( composite, coord ).r );
}

// Retrieves the roughness of a given fragment
float 	GetRoughness(in vec2 coord) {
	return texture2D(composite, texcoord.st).g;
}

//Material IDs
float 	GetMaterialIDs(in vec2 coord) {			//Function that retrieves the texture that has all material IDs stored in it
	return texture2D(gdepth, coord).r;
}

bool  	GetSky(in vec2 coord) {					//Function that returns true for any pixel that is part of the sky, and false for any pixel that isn't part of the sky
	float matID = GetMaterialIDs(coord);		//Gets texture that has all material IDs stored in it
		  matID = floor(matID * 255.0f);		//Scale texture from 0-1 float to 0-255 integer format

	if (matID == 0.0f) {						//Checks to see if the current pixel's material ID is 0 = the sky
		return true;							//If the current pixel has the material ID of 0 (sky material ID), Return "this pixel is part of the sky"
	} else {
		return false;							//Return "this pixel is not part of the sky"
	}
}

bool 	GetMaterialMask(in vec2 coord, in int ID, in float matID) {
	matID = floor(matID * 255.0f);

	//Catch last part of sky
	if (matID > 254.0f) {
		matID = 0.0f;
	}

	return matID == ID;
}

//Water
float 	GetWaterTex(in vec2 coord) {				//Function that returns the texture used for water. 0 means "this pixel is not water". 0.5 and greater means "this pixel is water".
	return texture2D(composite, coord).b;		//values from 0.5 to 1.0 represent the amount of sky light hitting the surface of the water. It is used to simulate fake sky reflections in composite1.fsh
}

bool  	GetWaterMask(in vec2 coord, in float matID) {					//Function that returns "true" if a pixel is water, and "false" if a pixel is not water.
	matID = floor(matID * 255.0f);

	return matID >= 35.0f && matID <= 51;
}

//Surface calculations
vec4  	GetScreenSpacePosition(in vec2 coord, in float depth) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
		  //depth += float(GetMaterialMask(coord, 5)) * 0.38f;
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;

	return fragposition;
}

vec4  	GetScreenSpacePosition(in vec2 coord) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
	float depth = GetDepth(coord);
		  depth += float(GetMaterialMask(coord, 5, GetMaterialIDs(coord))) * 0.38f;
	return GetScreenSpacePosition( coord, depth );
}

vec4 	GetWorldSpacePosition(in vec2 coord, in float depth) {
	vec4 pos = GetScreenSpacePosition(coord, depth);
	pos = gbufferModelViewInverse * pos;
	pos.xyz += cameraPosition.xyz;

	return pos;
}

vec4 	GetCloudSpacePosition(in vec2 coord, in float depth, in float distanceMult) {
	float linDepth = depth;

	float expDepth = (far * (linDepth - near)) / (linDepth * (far - near));

	//Convert texture coordinates and depth into view space
	vec4 viewPos = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * expDepth - 1.0f, 1.0f);
		 viewPos /= viewPos.w;

	//Convert from view space to world space
	vec4 worldPos = gbufferModelViewInverse * viewPos;

	worldPos.xyz *= distanceMult;
	worldPos.xyz += cameraPosition.xyz;

	return worldPos;
}

vec4 	ScreenSpaceFromWorldSpace(in vec4 worldPosition) {
	worldPosition.xyz -= cameraPosition;
	worldPosition = gbufferModelView * worldPosition;
	return worldPosition;
}

void 	DoNightEye(inout vec3 color) {			//Desaturates any color input at night, simulating the rods in the human eye

	float amount = 0.8f; 						//How much will the new desaturated and tinted image be mixed with the original image
	vec3 rodColor = vec3(0.2f, 0.5f, 1.25f); 	//Cyan color that humans percieve when viewing extremely low light levels via rod cells in the eye
	float colorDesat = dot(color, vec3(1.0f)); 	//Desaturated color

	color = mix(color, vec3(colorDesat) * rodColor, timeSkyDark * amount);
}

float 	ExponentialToLinearDepth(in float depth) {
	vec4 worldposition = vec4(depth);
	worldposition = gbufferProjection * worldposition;
	return worldposition.z;
}

float 	LinearToExponentialDepth(in float linDepth) {
	float expDepth = (far * (linDepth - near)) / (linDepth * (far - near));
	return expDepth;
}

void 	DoLowlightEye(inout vec3 color) {			//Desaturates any color input at night, simulating the rods in the human eye

	float amount = 0.8f; 						//How much will the new desaturated and tinted image be mixed with the original image
	vec3 rodColor = vec3(0.2f, 0.5f, 1.0f); 	//Cyan color that humans percieve when viewing extremely low light levels via rod cells in the eye
	float colorDesat = dot(color, vec3(1.0f)); 	//Desaturated color

	color = mix(color, vec3(colorDesat) * rodColor, amount);
}

void 	FixLightFalloff(inout float lightmap) { //Fixes the ugly lightmap falloff and creates a nice linear one
	float additive = 5.35f;
	float exponent = 40.0f;

	lightmap += additive;							//Prevent ugly fast falloff
	lightmap = pow(lightmap, exponent);			//Curve light falloff
	lightmap = max(0.0f, lightmap);		//Make sure light properly falls off to zero
	lightmap /= pow(1.0f + additive, exponent);
}

float 	CalculateLuminance(in vec3 color) {
	return (color.r * 0.2126f + color.g * 0.7152f + color.b * 0.0722f);
}

vec3 	Glowmap(in vec3 albedo, in bool mask, in float curve, in vec3 emissiveColor) {
	vec3 color = albedo * float(mask);
		 color = pow(color, vec3(curve));
		 color = vec3(CalculateLuminance(color));
		 color *= emissiveColor;

	return color;
}

float 	ChebyshevUpperBound(in vec2 moments, in float distance) {
	if (distance <= moments.x)
		return 1.0f;

	float variance = moments.y - (moments.x * moments.x);
		  variance = max(variance, 0.000002f);

	float d = distance - moments.x;
	float pMax = variance / (variance + d*d);

	return pMax;
}

float  	CalculateDitherPattern() {
	const int[4] ditherPattern = int[4] (0, 2, 1, 4);

	vec2 count = vec2(0.0f);
	     count.x = floor(mod(texcoord.s * viewWidth, 2.0f));
		 count.y = floor(mod(texcoord.t * viewHeight, 2.0f));

	int dither = ditherPattern[int(count.x) + int(count.y) * 2];

	return float(dither) / 4.0f;
}

float  	CalculateDitherPattern1() {
	const int[16] ditherPattern = int[16] (0 , 9 , 3 , 11,
									 	   13, 5 , 15, 7 ,
									 	   4 , 12, 2,  10,
									 	   16, 8 , 14, 6 );

	vec2 count = vec2(0.0f);
	     count.x = floor(mod(texcoord.s * viewWidth, 4.0f));
		 count.y = floor(mod(texcoord.t * viewHeight, 4.0f));

	int dither = ditherPattern[int(count.x) + int(count.y) * 4];

	return float(dither) / 17.0f;
}

float  	CalculateDitherPattern2() {
	const int[64] ditherPattern = int[64] ( 1, 49, 13, 61,  4, 52, 16, 64,
										   33, 17, 45, 29, 36, 20, 48, 32,
										    9, 57,  5, 53, 12, 60,  8, 56,
										   41, 25, 37, 21, 44, 28, 40, 24,
										    3, 51, 15, 63,  2, 50, 14, 62,
										   35, 19, 47, 31, 34, 18, 46, 30,
										   11, 59,  7, 55, 10, 58,  6, 54,
										   43, 27, 39, 23, 42, 26, 38, 22);

	vec2 count = vec2(0.0f);
	     count.x = floor(mod(texcoord.s * viewWidth, 8.0f));
		 count.y = floor(mod(texcoord.t * viewHeight, 8.0f));

	int dither = ditherPattern[int(count.x) + int(count.y) * 8];

	return float(dither) / 65.0f;
}

vec3 	CalculateNoisePattern1(vec2 offset, float size) {
	vec2 coord = texcoord.st;

	coord *= vec2(viewWidth, viewHeight);
	coord = mod(coord + offset, vec2(size));
	coord /= noiseTextureResolution;

	return texture2D(noisetex, coord).xyz;
}

void DrawDebugSquare(inout vec3 color) {
	vec2 pix = vec2(1.0f / viewWidth, 1.0f / viewHeight);

	vec2 offset = vec2(0.5f);
	vec2 size = vec2(0.0f);
		 size.x = 1.0f / 2.0f;
		 size.y = 1.0f / 2.0f;

	vec2 padding = pix * 0.0f;
		 size += padding;

	if ( texcoord.s + offset.s / 2.0f + padding.x / 2.0f > offset.s &&
		 texcoord.s + offset.s / 2.0f + padding.x / 2.0f < offset.s + size.x &&
		 texcoord.t + offset.t / 2.0f + padding.y / 2.0f > offset.t &&
		 texcoord.t + offset.t / 2.0f + padding.y / 2.0f < offset.t + size.y
		) {
		int[16] ditherPattern = int[16] (0, 3, 0, 3,
										 2, 1, 2, 1,
										 0, 3, 0, 3,
										 2, 1, 2, 1);

		vec2 count = vec2(0.0f);
		     count.x = floor(mod(texcoord.s * viewWidth, 4.0f));
			 count.y = floor(mod(texcoord.t * viewHeight, 4.0f));

		int dither = ditherPattern[int(count.x) + int(count.y) * 4];
		color.rgb = vec3(float(dither) / 3.0f);
	}
}

/////////////////////////STRUCTS////////////////////////////////////////////////////////////////////
/////////////////////////STRUCTS////////////////////////////////////////////////////////////////////

struct MCLightmapStruct {		//Lightmaps directly from MC engine
	float torch;				//Light emitted from torches and other emissive blocks
	float sky;					//Light coming from the sky
	float lightning;			//Light coming from lightning

	vec3 torchVector; 			//Vector in screen space that represents the direction of average light transfered
	vec3 skyVector;
} mcLightmap;

struct DiffuseAttributesStruct {			//Diffuse surface shading attributes
	float roughness;			//Roughness of surface. More roughness will use Oren Nayar reflectance.
	float translucency; 		//How translucent the surface is. Translucency represents how much energy will be transfered through the surface
	vec3  translucencyColor; 	//Color that will be multiplied with sunlight for backsides of translucent materials.
};

struct SpecularAttributesStruct {			//Specular surface shading attributes
	vec3 specularColor;		    //How reflective a surface is
	float roughness;			//How smooth or rough a specular surface is
	float metallic;				//from 0 - 1. 0 representing non-metallic, 1 representing fully metallic.
	vec3 fresnel;
};

struct SkyStruct { 				//All sky shading attributes
	vec3 	albedo;				//Diffuse texture aka "color texture" of the sky
	vec3 	tintColor; 			//Color that will be multiplied with the sky to tint it
	vec3 	sunglow;			//Color that will be added to the sky simulating scattered light arond the sun/moon
	vec3 	sunSpot; 			//Actual sun surface
};

struct WaterStruct {
	vec3 albedo;
};

struct MaskStruct {
	float matIDs;

	bool sky;
	bool land;
	bool grass;
	bool leaves;
	bool ice;
	bool hand;
	bool translucent;
	bool glow;
	bool sunspot;
	bool goldBlock;
	bool ironBlock;
	bool diamondBlock;
	bool emeraldBlock;
	bool sand;
	bool sandstone;
	bool stone;
	bool cobblestone;
	bool wool;
	bool clouds;

	bool torch;
	bool lava;
	bool glowstone;
	bool fire;

	bool water;

	bool volumeCloud;
};

struct CloudsStruct {
	vec3 albedo;
};

struct AOStruct {
	float skylight;
	float scatteredUpLight;
	float bouncedSunlight;
	float scatteredSunlight;
	float constant;
};

struct Ray {
	vec3 dir;
	vec3 origin;
};

struct Plane {
	vec3 normal;
	vec3 origin;
};

struct SurfaceStruct { 			//Surface shading properties, attributes, and functions
	//Attributes that change how shading is applied to each pixel
	DiffuseAttributesStruct  diffuse;			//Contains all diffuse surface attributes
	SpecularAttributesStruct specular;			//Contains all specular surface attributes

	SkyStruct 	    sky;			//Sky shading attributes and properties
	WaterStruct 	water;			//Water shading attributes and properties
	MaskStruct 		mask;			//Material ID Masks
	CloudsStruct 	clouds;
	AOStruct 		ao;				//ambient occlusion

	//Properties that are required for lighting calculation
	vec3 	albedo;					//Diffuse texture aka "color texture"
	vec3 	normal;					//Screen-space surface normals
	float 	depth;					//Scene depth
	float   linearDepth; 			//Linear depth

	vec4	screenSpacePosition;	//Vector representing the screen-space position of the surface
	vec3 	viewVector; 			//Vector representing the viewing direction
	vec3 	lightVector; 			//Vector representing sunlight direction
	Ray 	viewRay;
	vec3 	worldLightVector;
	vec3  	upVector;				//Vector representing "up" direction
	float 	NdotL; 					//dot(normal, lightVector). used for direct lighting calculation
	vec3 	debug;

	float 	shadow;
	float 	cloudShadow;

	float 	cloudAlpha;
} surface;

struct LightmapStruct {			//Lighting information to light the scene. These are untextured colored lightmaps to be multiplied with albedo to get the final lit and textured image.
	vec3 sunlight;				//Direct light from the sun
	vec3 skylight;				//Ambient light from the sky
	vec3 bouncedSunlight;		//Fake bounced light, coming from opposite of sun direction and adding to ambient light
	vec3 scatteredSunlight;		//Fake scattered sunlight, coming from same direction as sun and adding to ambient light
	vec3 scatteredUpLight; 		//Fake GI from ground
	vec3 torchlight;			//Light emitted from torches and other emissive blocks
	vec3 lightning;				//Light caused by lightning
	vec3 nolight;				//Base ambient light added to everything. For lighting caves so that the player can barely see even when no lights are present
	vec3 specular;				//Reflected direct light from sun
	vec3 translucent;			//Light on the backside of objects representing thin translucent materials
	vec3 sky;					//Color and brightness of the sky itself
	vec3 underwater;			//underwater lightmap
	vec3 heldLight;
} lightmap;

struct ShadingStruct {			//Shading calculation variables
	float   direct;
	float 	waterDirect;
	float 	bounced; 			//Fake bounced sunlight
	float 	skylight; 			//Light coming from sky
	float 	scattered; 			//Fake scattered sunlight
	float   scatteredUp; 		//Fake GI from ground
	float 	specular; 			//Reflected direct light
	float 	translucent; 		//Backside of objects lit up from the sun via thin translucent materials
	float 	sunlightVisibility; //Shadows
	float 	heldLight;
} shading;

struct GlowStruct {
	vec3 torch;
	vec3 lava;
	vec3 glowstone;
	vec3 fire;
};

struct FinalStruct {			//Final textured and lit images sorted by what is illuminating them.
	GlowStruct 		glow;		//Struct containing emissive material final images

	vec3 sunlight;				//Direct light from the sun
	vec3 skylight;				//Ambient light from the sky
	vec3 bouncedSunlight;		//Fake bounced light, coming from opposite of sun direction and adding to ambient light
	vec3 scatteredSunlight;		//Fake scattered sunlight, coming from same direction as sun and adding to ambient light
	vec3 scatteredUpLight; 		//Fake GI from ground
	vec3 torchlight;			//Light emitted from torches and other emissive blocks
	vec3 lightning;				//Light caused by lightning
	vec3 nolight;				//Base ambient light added to everything. For lighting caves so that the player can barely see even when no lights are present
	vec3 translucent;			//Light on the backside of objects representing thin translucent materials
	vec3 sky;					//Color and brightness of the sky itself
	vec3 underwater;			//underwater colors
	vec3 heldLight;
} final;

struct Intersection {
	vec3 pos;
	float distance;
	float angle;
};

/////////////////////////STRUCT FUNCTIONS////////////////////////////////////////////////////////
/////////////////////////STRUCT FUNCTIONS////////////////////////////////////////////////////////

//Mask
void 	CalculateMasks(inout MaskStruct mask) {
		mask.sky 			= GetMaterialMask(texcoord.st, 0, mask.matIDs);
		mask.land	 		= GetMaterialMask(texcoord.st, 1, mask.matIDs);
		mask.grass 			= GetMaterialMask(texcoord.st, 2, mask.matIDs);
		mask.leaves	 		= GetMaterialMask(texcoord.st, 3, mask.matIDs);
		mask.ice		 	= GetMaterialMask(texcoord.st, 4, mask.matIDs);
		mask.hand	 		= GetMaterialMask(texcoord.st, 5, mask.matIDs);
		mask.translucent	= GetMaterialMask(texcoord.st, 6, mask.matIDs);

		mask.glow	 		= GetMaterialMask(texcoord.st, 10, mask.matIDs);
		mask.sunspot 		= GetMaterialMask(texcoord.st, 11, mask.matIDs);

		mask.goldBlock 		= GetMaterialMask(texcoord.st, 20, mask.matIDs);
		mask.ironBlock 		= GetMaterialMask(texcoord.st, 21, mask.matIDs);
		mask.diamondBlock	= GetMaterialMask(texcoord.st, 22, mask.matIDs);
		mask.emeraldBlock	= GetMaterialMask(texcoord.st, 23, mask.matIDs);
		mask.sand	 		= GetMaterialMask(texcoord.st, 24, mask.matIDs);
		mask.sandstone 		= GetMaterialMask(texcoord.st, 25, mask.matIDs);
		mask.stone	 		= GetMaterialMask(texcoord.st, 26, mask.matIDs);
		mask.cobblestone	= GetMaterialMask(texcoord.st, 27, mask.matIDs);
		mask.wool			= GetMaterialMask(texcoord.st, 28, mask.matIDs);
		mask.clouds 		= GetMaterialMask(texcoord.st, 29, mask.matIDs);

		mask.torch 			= GetMaterialMask(texcoord.st, 30, mask.matIDs);
		mask.lava 			= GetMaterialMask(texcoord.st, 31, mask.matIDs);
		mask.glowstone 		= GetMaterialMask(texcoord.st, 32, mask.matIDs);
		mask.fire 			= GetMaterialMask(texcoord.st, 33, mask.matIDs);

		mask.water 			= GetWaterMask(texcoord.st, mask.matIDs);

		mask.volumeCloud 	= false;
}

//Surface
void 	CalculateNdotL(inout SurfaceStruct surface) {		//Calculates direct sunlight without visibility check
	float direct = dot(surface.normal.rgb, surface.lightVector);
		  direct = direct * 1.0f + 0.0f;

	surface.NdotL = direct;
}

float 	CalculateDirectLighting(in SurfaceStruct surface) {
	//Tall grass translucent shading
	if (surface.mask.grass) {
		return 1.0f;
	} else if (surface.mask.leaves) {
		return 1.0f;
	} else if (surface.mask.clouds) {
		return 0.5f;
	} else if (surface.mask.ice) {
		return pow(surface.NdotL * 0.5 + 0.5, 2.0f);
	} else {
		//Default lambert shading
		return max(0.0f, surface.NdotL * 0.99f + 0.01f);
	}
}

/** DethRaid's shadowing stuff **/
//from SEUS v8
vec4 calcShadowCoordinate( in vec4 fragPosition, in vec3 fragNormal ) {
    vec4 shadowCoord = shadowModelView * fragPosition;
    shadowCoord = shadowProjection * shadowCoord;
    shadowCoord /= shadowCoord.w;

    float dist = sqrt(shadowCoord.x * shadowCoord.x + shadowCoord.y * shadowCoord.y);
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
	shadowCoord.xy *= 1.0f / distortFactor;

    shadowCoord = shadowCoord * 0.5 + 0.5;    //take it from [-1, 1] to [0, 1]

	float depthBias = distortFactor*distortFactor*(0.0097297*tan(acos(surface.NdotL)) + 0.01729729729)/2.8888888;
    return vec4( shadowCoord.xyz, dist-depthBias );
}

//Implements the Percentage-Closer Soft Shadow algorithm, as defined by nVidia
//Implemented by DethRaid - github.com/DethRaid
float calcPenumbraSize( vec3 shadowCoord ) {
	float dFragment = shadowCoord.z;
	float dBlocker = 0;
	float penumbra = 0;

	float temp;
	float numBlockers = 0;
    float searchSize = LIGHT_SIZE * (dFragment - 9.5) / dFragment;

    for( int i = -BLOCKER_SEARCH_SAMPLES_HALF; i <= BLOCKER_SEARCH_SAMPLES_HALF; i++ ) {
        for( int j = -BLOCKER_SEARCH_SAMPLES_HALF; j <= BLOCKER_SEARCH_SAMPLES_HALF; j++ ) {
            temp = texture2D( shadow, shadowCoord.st + (vec2( i, j ) * searchSize / (shadowMapResolution * 25)) ).r;
            if( dFragment - temp > 0.0015 ) {
                dBlocker += temp;// * temp;
                numBlockers += 1.0;
            }
        }
	}

    if( numBlockers > 0.1 ) {
		dBlocker /= numBlockers;
		penumbra = (dFragment - dBlocker) * LIGHT_SIZE / dFragment;
	}

    return max( penumbra, MIN_PENUMBRA_SIZE );
}

float calcShadowing( in vec4 fragPosition, in vec3 fragNormal ) {
    vec4 shadowCoord = calcShadowCoordinate( fragPosition, fragNormal );

    float visibility = 1.0;

	#if SHADOW_MODE == HARD
    float shadowDepth = texture2D( shadow, shadowCoord.st ).r;
    return step( shadowCoord.z - shadowDepth, 0.0 );

	#else
    float penumbraSize = 0.5;    // whoo magic number!

	#if SHADOW_MODE == PCSS
    penumbraSize = calcPenumbraSize( shadowCoord.xyz );
	#endif

    float numBlockers = 0.0;
    float numSamples = 0.0;

    float diffthresh = shadowCoord.w * 1.0f + 0.10f;
	diffthresh *= 3.0f / (shadowMapResolution / 2048.0f);

	#if USE_RANDOM_ROTATION
    float rotateAmount = texture2D(
        noisetex,
        texcoord.st * vec2(
            viewWidth / noiseTextureResolution,
            viewHeight / noiseTextureResolution
        ) ).r * 2.0f - 1.0f;

    mat2 kernelRotation = mat2(
        cos( rotateAmount ), -sin( rotateAmount ),
        sin( rotateAmount ), cos( rotateAmount )
    );
	#endif

	for( int i = -PCF_SIZE_HALF; i <= PCF_SIZE_HALF; i++ ) {
        for( int j = -PCF_SIZE_HALF; j <= PCF_SIZE_HALF; j++ ) {
            vec2 sampleCoord = vec2( j, i ) / shadowMapResolution;
            sampleCoord *= penumbraSize;
			#if USE_RANDOM_ROTATION
            sampleCoord = kernelRotation * sampleCoord;
			#endif
            float shadowDepth = texture2D( shadow, shadowCoord.st + sampleCoord ).r;
            numBlockers += step( shadowCoord.z - shadowDepth, 0.00018f );
            numSamples++;
        }
	}

    visibility = max( numBlockers / numSamples, 0 );

    return visibility;
	#endif
}

float 	CalculateSunlightVisibility(inout SurfaceStruct surface, in ShadingStruct shadingStruct) {				//Calculates shadows
	if (rainStrength >= 0.99f)
		return 1.0f;

	if (shadingStruct.direct > 0.0f) {
		float distance = sqrt(  surface.screenSpacePosition.x * surface.screenSpacePosition.x 	//Get surface distance in meters
							  + surface.screenSpacePosition.y * surface.screenSpacePosition.y
							  + surface.screenSpacePosition.z * surface.screenSpacePosition.z);

		vec4 worldposition = vec4(0.0f);
			worldposition = gbufferModelViewInverse * surface.screenSpacePosition;		//Transform from screen space to world space

		float CalcShad = calcShadowing( worldposition, surface.normal );

        float fademult = 0.15f;
		float shadowMult = clamp((shadowDistance * 0.85f * fademult) - (distance * fademult), 0.0f, 1.0f);	//Calculate shadowMult to fade shadows out;
		float shading = mix(1.0f, CalcShad, shadowMult);

		surface.shadow = shading;

		return shading;
	} else {
		return 0.0f;
	}
}

float 	CalculateBouncedSunlight(in SurfaceStruct surface) {

	float NdotL = surface.NdotL;
	float bounced = clamp(-NdotL + 0.95f, 0.0f, 1.95f) / 1.95f;
		  bounced = bounced * bounced * bounced;

	return bounced;
}

float 	CalculateScatteredSunlight(in SurfaceStruct surface) {
	float NdotL = surface.NdotL;
	float scattered = clamp(NdotL * 0.75f + 0.25f, 0.0f, 1.0f);

	return scattered;
}

float 	CalculateSkylight(in SurfaceStruct surface) {
	if (surface.mask.clouds) {
		return 1.0f;
	} else if (surface.mask.grass) {
		return 1.0f;
	} else {
		float skylight = dot(surface.normal, surface.upVector);
			  skylight = skylight * 0.4f + 0.6f;

		return skylight;
	}
}

float 	CalculateScatteredUpLight(in SurfaceStruct surface) {
	float scattered = dot(surface.normal, surface.upVector);
		  scattered = scattered * 0.5f + 0.5f;
		  scattered = 1.0f - scattered;

	return scattered;
}

float CalculateHeldLightShading(in SurfaceStruct surface) {
	vec3 lightPos = vec3(0.0f);
	vec3 lightVector = normalize(lightPos - surface.screenSpacePosition.xyz);
	float lightDist = length(lightPos.xyz - surface.screenSpacePosition.xyz);

	float atten = 1.0f / (pow(lightDist, 2.0f) + 0.001f);
	float NdotL = 1.0f;

	return atten * NdotL;
}

float   CalculateSunglow(in SurfaceStruct surface) {
	float curve = 4.0f;

	vec3 npos = normalize(surface.screenSpacePosition.xyz);
	vec3 halfVector2 = normalize(-surface.lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

float   CalculateAntiSunglow(in SurfaceStruct surface) {
	float curve = 4.0f;

	vec3 npos = normalize(surface.screenSpacePosition.xyz);
	vec3 halfVector2 = normalize(surface.lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

bool   CalculateSunspot(in SurfaceStruct surface) {
	//circular sun
	float curve = 1.0f;

	vec3 npos = normalize(surface.screenSpacePosition.xyz);
	vec3 halfVector2 = normalize(-surface.lightVector + npos);

	float sunProximity = 1.0f - dot(halfVector2, npos);

	if (sunProximity > 0.96f && sunAngle > 0.0f && sunAngle < 0.5f) {
		return true;
	} else {
		return false;
	}
}

void 	GetLightVectors(inout MCLightmapStruct mcLightmap, in SurfaceStruct surface) {
	vec2 torchDiff = vec2(0.0f);
		 torchDiff.x = GetLightmapTorch(texcoord.st) - GetLightmapTorch(texcoord.st + vec2(1.0f / viewWidth, 0.0f));
		 torchDiff.y = GetLightmapTorch(texcoord.st) - GetLightmapTorch(texcoord.st + vec2(0.0f, 1.0f / viewWidth));

	mcLightmap.torchVector.x = torchDiff.x * 200.0f;

	mcLightmap.torchVector.y = torchDiff.y * 200.0f;

	mcLightmap.torchVector.x = 1.0f;
	mcLightmap.torchVector.y = 0.0f;
	mcLightmap.torchVector.z = sqrt(1.0f - mcLightmap.torchVector.x * mcLightmap.torchVector.x + mcLightmap.torchVector.y + mcLightmap.torchVector.y);

	float torchNormal = dot(surface.normal.rgb, mcLightmap.torchVector.rgb);

	mcLightmap.torchVector.x = torchNormal;
}

void 	AddSkyGradient(inout SurfaceStruct surface) {
	float curve = 3.5f;
	vec3 npos = normalize(surface.screenSpacePosition.xyz);
	vec3 halfVector2 = normalize(-surface.upVector + npos);
	float skyGradientFactor = dot(halfVector2, npos);
	float skyDirectionGradient = skyGradientFactor;

	skyGradientFactor = pow(skyGradientFactor, curve);
	surface.sky.albedo *= mix(skyGradientFactor, 1.0f, clamp((0.145f - (timeNoon * 0.1f)) + rainStrength, 0.0f, 1.0f));

	vec3 skyBlueColor = vec3(0.25f, 0.4f, 1.0f) * 2.5f;
	skyBlueColor.g *= skyGradientFactor * 0.5f + 0.75f;
	skyBlueColor = mix(skyBlueColor, vec3(1.0f, 0.9f, 0.5f), vec3(timeSkyDark));
	skyBlueColor *= mix(vec3(1.0f), vec3(1.0f, 1.0f, 0.5f), vec3(timeSunrise + timeSunset));

	float fade1 = clamp(skyGradientFactor - 0.15f, 0.0f, 0.2f) / 0.2f;
	vec3 color1 = vec3(1.0f, 1.3, 1.0f);

	surface.sky.albedo *= mix(skyBlueColor, color1, vec3(fade1));

	float fade2 = clamp(skyGradientFactor - 0.18f, 0.0f, 0.2f) / 0.2f;
	vec3 color2 = vec3(1.7f, 1.0f, 0.8f);
		 color2 = mix(color2, vec3(1.0f, 0.15f, 0.0f), vec3(timeSunrise + timeSunset));

	surface.sky.albedo *= mix(vec3(1.0f), color2, vec3(fade2 * 0.5f));

	float horizonGradient = 1.0f - distance(skyDirectionGradient, 0.72f) / 0.72f;
		  horizonGradient = pow(horizonGradient, 10.0f);
		  horizonGradient = max(0.0f, horizonGradient);

	float sunglow = CalculateSunglow(surface);
		  horizonGradient *= sunglow * 2.0f + (0.65f - timeSunrise * 0.55f - timeSunset * 0.55f);

	vec3 horizonColor1 = vec3(1.5f, 1.5f, 1.5f);
		 horizonColor1 = mix(horizonColor1, vec3(1.5f, 1.95f, 1.5f) * 2.0f, vec3(timeSunrise + timeSunset));
	vec3 horizonColor2 = vec3(1.5f, 1.2f, 0.8f) * 1.0f;
		 horizonColor2 = mix(horizonColor2, vec3(1.9f, 0.6f, 0.4f) * 2.0f, vec3(timeSunrise + timeSunset));

	surface.sky.albedo *= mix(vec3(1.0f), horizonColor1, vec3(horizonGradient) * (1.0f - timeMidnight));
	surface.sky.albedo *= mix(vec3(1.0f), horizonColor2, vec3(pow(horizonGradient, 2.0f)) * (1.0f - timeMidnight));

	float grayscale = surface.sky.albedo.r + surface.sky.albedo.g + surface.sky.albedo.b;
		  grayscale /= 3.0f;

	surface.sky.albedo = mix(surface.sky.albedo, vec3(grayscale) * 1.4f, vec3(rainStrength));
}

void 	AddSunglow(inout SurfaceStruct surface) {
	float sunglowFactor = CalculateSunglow(surface);
	float antiSunglowFactor = CalculateAntiSunglow(surface);

	surface.sky.albedo *= 1.0f + pow(sunglowFactor, 1.1f) * (1.5f + timeNoon * 1.0f) * (1.0f - rainStrength);
	surface.sky.albedo *= mix(vec3(1.0f), colorSunlight * 5.0f, pow(clamp(vec3(sunglowFactor) * (1.0f - timeMidnight) * (1.0f - rainStrength), vec3(0.0f), vec3(1.0f)), vec3(2.0f)));

	surface.sky.albedo *= 1.0f + antiSunglowFactor * 2.0f * (1.0f - rainStrength);
}

void 	AddCloudGlow(inout vec3 color, in SurfaceStruct surface) {
	float glow = CalculateSunglow(surface);
		  glow = pow(glow, 1.0f);

	float mult = mix(50.0f, 800.0f, timeSkyDark);

	color.rgb *= 1.0f + glow * mult * float(surface.mask.clouds);
}

void 	CalculateUnderwaterFog(in SurfaceStruct surface, inout vec3 finalComposite) {
	vec3 fogColor = colorWaterMurk * vec3(colorSkylight);
	float fogFactor = GetDepthLinear(texcoord.st) / 100.0f;
		  fogFactor = min(fogFactor, 0.7f);
		  fogFactor = sin(fogFactor * 3.1415 / 2.0f);
		  fogFactor = pow(fogFactor, 0.5f);

	finalComposite.rgb = mix(finalComposite.rgb, fogColor * 0.002f, vec3(fogFactor));
	finalComposite.rgb *= mix(vec3(1.0f), colorWaterBlue * colorWaterBlue * colorWaterBlue * colorWaterBlue, vec3(fogFactor));
}

void 	TestRaymarch(inout vec3 color, in SurfaceStruct surface) {
	//visualize march steps
	float rayDepth = 0.0f;
	float rayIncrement = 0.05f;
	float fogFactor = 0.0f;

	while (rayDepth < 1.0f) {
		vec4 rayPosition = GetScreenSpacePosition(texcoord.st, pow(rayDepth, 0.002f));

		if (abs(rayPosition.z - surface.screenSpacePosition.z) < 0.025f) {
			color.rgb = vec3(0.01f, 0.0f, 0.0f);
		}

		rayDepth += rayIncrement;
	}
}

void InitializeAO(inout SurfaceStruct surface) {
	surface.ao.skylight = 1.0f;
	surface.ao.bouncedSunlight = 1.0f;
	surface.ao.scatteredUpLight = 1.0f;
	surface.ao.constant = 1.0f;
}

void CalculateAO(inout SurfaceStruct surface) {
	const int numSamples = 20;
	vec3[numSamples] kernel;

	vec3 stochastic = texture2D(noisetex, texcoord.st * vec2(viewWidth, viewHeight) / noiseTextureResolution).rgb;

	//Generate positions for sample points in hemisphere
	for (int i = 0; i < numSamples; i++) {
		//Random direction
		kernel[i] = vec3(texture2D(noisetex, vec2(0.0f + (i * 1.0f) / noiseTextureResolution)).r * 2.0f - 1.0f,
					     texture2D(noisetex, vec2(0.0f + (i * 1.0f) / noiseTextureResolution)).g * 2.0f - 1.0f,
					     texture2D(noisetex, vec2(0.0f + (i * 1.0f) / noiseTextureResolution)).b * 2.0f - 1.0f);
		kernel[i] = normalize(kernel[i]);

		//scale randomly to distribute within hemisphere;
		kernel[i] *= pow(texture2D(noisetex, vec2(0.3f + (i * 1.0f) / noiseTextureResolution)).r * CalculateNoisePattern1(vec2(43.0f), 64.0f).x * 1.0f, 1.2f);
	}

	//Determine origin position and normal
	vec3 origin = surface.screenSpacePosition.xyz;
	vec3 normal = surface.normal.xyz;

	vec3	randomRotation = CalculateNoisePattern1(vec2(0.0f), 64.0f).xyz * 2.0f - 1.0f;

	vec3 tangent = normalize(randomRotation - upVector * dot(randomRotation, upVector));
	vec3 bitangent = cross(upVector, tangent);
	mat3 tbn = mat3(tangent, bitangent, upVector);

	float ao = 0.0f;
	float aoSkylight	= 0.0f;
	float aoUp  		= 0.0f;
	float aoBounced  	= 0.0f;
	float aoScattered  	= 0.0f;

	float aoRadius   = 0.35f * -surface.screenSpacePosition.z;
	float zThickness = 0.35f * -surface.screenSpacePosition.z;
		  zThickness = 6.0f;

	vec3 	samplePosition 		= vec3(0.0f);
	float 	intersect 			= 0.0f;
	vec4 	sampleScreenSpace 	= vec4(0.0f);
	float 	sampleDepth 		= 0.0f;
	float 	distanceWeight 		= 0.0f;
	float 	finalRadius 		= 0.0f;

	float skylightWeight = 0.0f;
	float bouncedWeight  = 0.0f;
	float scatteredUpWeight = 0.0f;
	float scatteredSunWeight = 0.0f;
	vec3 bentNormal = vec3(0.0f);

	for (int i = 0; i < numSamples; i++) {
		samplePosition = tbn * kernel[i];
		samplePosition = samplePosition * aoRadius + origin;

		intersect = dot(normalize(samplePosition - origin), surface.normal);

		if (intersect > 0.2f) {
			//Convert camera space to screen space
			sampleScreenSpace = gbufferProjection * vec4(samplePosition, 1.0f);
			sampleScreenSpace.xyz /= sampleScreenSpace.w;
			sampleScreenSpace.xyz = sampleScreenSpace.xyz * 0.5f + 0.5f;

			//Check depth at sample point
			sampleDepth = GetScreenSpacePosition(sampleScreenSpace.xy).z;

			//If point is behind geometry, buildup AO
			if (sampleDepth >= samplePosition.z && !surface.mask.sky) {
				//Reduce halo
				float sampleLength = length(samplePosition - origin) * 4.0f;
				distanceWeight = 1.0f - step(sampleLength, distance(sampleDepth, origin.z));

				//Weigh samples based on light direction
				skylightWeight 			= clamp(dot(normalize(samplePosition - origin), upVector)		* 1.0f - 0.0f , 0.0f, 0.01f) / 0.01f;
				bouncedWeight 			= clamp(dot(normalize(samplePosition - origin), -lightVector)	* 1.0f - 0.0f , 0.0f, 0.51f) / 0.51f;
				scatteredUpWeight 		= clamp(dot(normalize(samplePosition - origin), -upVector)	 	* 1.0f - 0.0f , 0.0f, 0.51f) / 0.51f;
				scatteredSunWeight 		= clamp(dot(normalize(samplePosition - origin), lightVector)	* 1.0f - 0.25f, 0.0f, 0.51f) / 0.51f;

				//buildup occlusion more for further facing surfaces
				skylightWeight 			/= clamp(dot(normal, upVector) 			* 0.5f + 0.501f, 0.01f, 1.0f);
				bouncedWeight 			/= clamp(dot(normal, -lightVector) 		* 0.5f + 0.501f, 0.01f, 1.0f);
				scatteredUpWeight 		/= clamp(dot(normal, -upVector) 		* 0.5f + 0.501f, 0.01f, 1.0f);
				scatteredSunWeight 		/= clamp(dot(normal, lightVector) 		* 0.75f + 0.25f, 0.01f, 1.0f);


				//Accumulate ao
				ao 			+= 2.0f * distanceWeight;
				aoSkylight  += 2.0f * distanceWeight * skylightWeight		;
				aoUp 		+= 2.0f * distanceWeight * scatteredUpWeight	;
				aoBounced 	+= 2.0f * distanceWeight * bouncedWeight		;
				aoScattered += 2.0f * distanceWeight * scatteredSunWeight   ;
			} else {
				bentNormal.rgb += normalize(samplePosition - origin);
			}
		}
	}

	bentNormal.rgb /= numSamples;

	ao 			/= numSamples;
	aoSkylight  /= numSamples;
	aoUp 		/= numSamples;
	aoBounced 	/= numSamples;
	aoScattered /= numSamples;

	ao 			= 1.0f - ao;
	aoSkylight 	= 1.0f - aoSkylight;
	aoUp 		= 1.0f - aoUp;
	aoBounced   = 1.0f - aoBounced;
	aoScattered = 1.0f - aoScattered;

	ao 			= clamp(ao, 			0.0f, 1.0f);
	aoSkylight 	= clamp(aoSkylight, 	0.0f, 1.0f);
	aoUp 		= clamp(aoUp, 			0.0f, 1.0f);
	aoBounced 	= clamp(aoBounced,		0.0f, 1.0f);
	aoScattered = clamp(aoScattered, 	0.0f, 1.0f);

	surface.ao.constant 				= pow(ao, 			1.0f);
	surface.ao.skylight 				= pow(aoSkylight, 	3.0f);
	surface.ao.bouncedSunlight 			= pow(aoBounced, 	6.0f);
	surface.ao.scatteredUpLight 		= pow(aoUp, 		6.0f);
	surface.ao.scatteredSunlight 		= pow(aoScattered,  1.0f);

	surface.debug = vec3(pow(aoSkylight, 2.0f) * clamp((dot(surface.normal, upVector) * 0.75f + 0.25f), 0.0f, 1.0f));
}

Intersection 	RayPlaneIntersectionWorld(in Ray ray, in Plane plane) {
	float rayPlaneAngle = dot(ray.dir, plane.normal);

	float planeRayDist = 100000000.0f;
	vec3 intersectionPos = ray.dir * planeRayDist;

	if (rayPlaneAngle > 0.0001f || rayPlaneAngle < -0.0001f) {
		planeRayDist = dot((plane.origin), plane.normal) / rayPlaneAngle;
		intersectionPos = ray.dir * planeRayDist;
		intersectionPos = -intersectionPos;

		intersectionPos += cameraPosition.xyz;
	}

	Intersection i;

	i.pos = intersectionPos;
	i.distance = planeRayDist;
	i.angle = rayPlaneAngle;

	return i;
}

Intersection 	RayPlaneIntersection(in Ray ray, in Plane plane) {
	float rayPlaneAngle = dot(ray.dir, plane.normal);

	float planeRayDist = 100000000.0f;
	vec3 intersectionPos = ray.dir * planeRayDist;

	if (rayPlaneAngle > 0.0001f || rayPlaneAngle < -0.0001f) {
		planeRayDist = dot((plane.origin - ray.origin), plane.normal) / rayPlaneAngle;
		intersectionPos = ray.origin + ray.dir * planeRayDist;
	}

	Intersection i;

	i.pos = intersectionPos;
	i.distance = planeRayDist;
	i.angle = rayPlaneAngle;

	return i;
}

void 	CalculateRainFog(inout vec3 color, in SurfaceStruct surface) {
	vec3 fogColor = colorSkylight * 0.055f;

	float fogDensity = 0.0018f * rainStrength;
		  fogDensity *= mix(0.0f, 1.0f, pow(eyeBrightnessSmooth.y / 240.0f, 6.0f));
	float visibility = 1.0f / (pow(exp(distance(surface.screenSpacePosition.xyz, vec3(0.0f)) * fogDensity), 1.0f));
	float fogFactor = 1.0f - visibility;
		  fogFactor = clamp(fogFactor, 0.0f, 1.0f);
		  fogFactor = mix(fogFactor, 1.0f, float(surface.mask.sky) * 0.8f * rainStrength);
		  fogFactor = mix(fogFactor, 1.0f, float(surface.mask.clouds) * 0.8f * rainStrength);

	color = mix(color, fogColor, vec3(fogFactor));
}

void 	CalculateAtmosphericFog(inout vec3 color, in SurfaceStruct surface) {
	vec3 fogColor = colorSkylight * 0.11f;

	float sat = 0.5f;
		 fogColor.r = fogColor.r * (0.0f + sat) - (fogColor.g + fogColor.b) * 0.0f * sat;
		 fogColor.g = fogColor.g * (0.0f + sat) - (fogColor.r + fogColor.b) * 0.0f * sat;
		 fogColor.b = fogColor.b * (0.0f + sat) - (fogColor.r + fogColor.g) * 0.0f * sat;

	float sunglow = CalculateSunglow(surface);
	vec3 sunColor = colorSunlight;

	fogColor += mix(vec3(0.0f), sunColor, sunglow * 0.8f);

	float fogDensity = 0.01f;
	float visibility = 1.26f / (pow(exp(surface.linearDepth * fogDensity), 1.0f));
	float fogFactor = 1.0f - visibility;
		  fogFactor = clamp(fogFactor, 0.0f, 1.0f);

	fogFactor = pow(fogFactor, 2.7f);

	fogFactor = mix(fogFactor, 0.0f, min(1.0f, surface.sky.sunSpot.r));
	fogFactor *= mix(1.0f, 0.25f, float(surface.mask.sky));
	fogFactor *= mix(1.0f, 0.75f, float(surface.mask.clouds));

	float redshift = 1.20f;

	//scatter away high frequency light
	color.b *= 1.0f - clamp(fogFactor * 1.65 * redshift, 0.0f, 0.75f);
	color.g *= 1.0f - fogFactor * 0.2* redshift;
	color.g *= 1.0f - clamp(fogFactor - 0.26f, 0.0f, 1.0f) * 0.5* redshift;

	//add scattered low frequency light
	color += fogColor * fogFactor * 1.0f;
}

float CubicSmooth(float x) {
	return x * x * (3.0 - 2.0 * x);
}

#ifdef STANDARD_CLOUDS
float Get3DNoise(in vec3 pos) {
	pos.z += 0.0f;
	vec3 p = floor(pos);
	vec3 f = fract(pos);

	vec2 uv =  (p.xy + p.z * vec2(17.0f)) + f.xy;
	vec2 uv2 = (p.xy + (p.z + 1.0f) * vec2(17.0f)) + f.xy;
	vec2 coord =  (uv  + 0.5f) / noiseTextureResolution;
	vec2 coord2 = (uv2 + 0.5f) / noiseTextureResolution;
	float xy1 = texture2D(noisetex, coord).x;
	float xy2 = texture2D(noisetex, coord2).x;
	return mix(xy1, xy2, f.z);
}
#else

float Get3DNoise(in vec3 pos) {
	pos.z += 0.0f;

	pos.xyz += 0.5f;

	vec3 p = floor(pos);
	vec3 f = fract(pos);

	f.x = f.x * f.x * (3.0f - 2.0f * f.x);
	f.y = f.y * f.y * (3.0f - 2.0f * f.y);
	f.z = f.z * f.z * (3.0f - 2.0f * f.z);

	vec2 uv =  (p.xy + p.z * vec2(17.0f)) + f.xy;
	vec2 uv2 = (p.xy + (p.z + 1.0f) * vec2(17.0f)) + f.xy;

	vec2 coord =  (uv  + 0.5f) / 64.0f;
	vec2 coord2 = (uv2 + 0.5f) / 64.0f;
	float xy1 = texture2D(noisetex, coord).x;
	float xy2 = texture2D(noisetex, coord2).x;
	return mix(xy1, xy2, f.z);
}
#endif

float GetCoverage(in float coverage, in float density, in float clouds) {
	clouds = clamp(clouds - (1.0f - coverage), 0.0f, 1.0f -density) / (1.0f - density);
	clouds = max(0.0f, clouds * 1.1f - 0.1f);
	return clouds;
}

vec4 CloudColor2(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector, in float altitude, in float thickness, const bool isShadowPass) {

	float cloudHeight = altitude;
	float cloudDepth  = thickness;
	float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
	float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

	worldPosition.xz /= 1.0f + max(0.0f, length(worldPosition.xz - cameraPosition.xz) / 9001.0f);

	vec3 p = worldPosition.xyz / 100.0f;

	float t = frameTimeCounter * 1.0f;
		  t *= 0.4;

	p += (Get3DNoise(p * 2.0f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.10f;

	p.x -= (Get3DNoise(p * 0.125f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 1.2f;

	p.x *= 0.25f;
	p.x -= t * 0.003f;

	vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
	float noise  = 	Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));
	p *= 2.0f;
	p.x -= t * 0.017f;
	p.z += noise * 1.35f;
	p.x += noise * 0.5f;
	vec3 p2 = p;
	noise += (2.0f - abs(Get3DNoise(p) * 2.0f - 0.0f)) * (0.25f);
	p *= 3.0f;
	p.xz -= t * 0.005f;
	p.z += noise * 1.35f;
	p.x += noise * 0.5f;
	p.x *= 3.0f;
	p.z *= 0.55f;
	vec3 p3 = p;
	p.z -= (Get3DNoise(p * 0.25f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.4f;
	noise += (3.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * (0.035f);
	p *= 3.0f;
	p.xz -= t * 0.005f;
	vec3 p4 = p;
	noise += (3.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * (0.025f);
	p *= 3.0f;
	p.xz -= t * 0.005f;
	if (!isShadowPass) {
		noise += ((Get3DNoise(p))) * (0.022f);
		p *= 3.0f;
		noise += ((Get3DNoise(p))) * (0.024f);
	}
	noise /= 1.575f;

	//cloud edge
	float rainy = mix(wetness, 1.0f, rainStrength);

	float coverage = CLOUD_COVERAGE;

	float dist = length(worldPosition.xz - cameraPosition.xz);
	coverage *= max(0.0f, 1.0f - dist / mix(7000.0f, 3000.0f, rainStrength));
	float density = 0.0f;

	if (isShadowPass) {
		return vec4(GetCoverage(coverage + 0.2f, density + 0.2f, noise));
	} else {
		noise = GetCoverage(coverage, density, noise);
		noise = noise * noise * (3.0f - 2.0f * noise);

		const float lightOffset = 0.2f;

		float sundiff = Get3DNoise(p1 + worldLightVector.xyz * lightOffset);
			  sundiff += (2.0f - abs(Get3DNoise(p2 + worldLightVector.xyz * lightOffset / 2.0f) * 2.0f - 0.0f)) * (0.55f);
		float largeSundiff = sundiff;
			  largeSundiff = -GetCoverage(coverage, 0.0f, largeSundiff * 1.3f);
		sundiff += (3.0f - abs(Get3DNoise(p3 + worldLightVector.xyz * lightOffset / 5.0f) * 3.0f - 0.0f)) * (0.065f);
		sundiff += (3.0f - abs(Get3DNoise(p4 + worldLightVector.xyz * lightOffset / 8.0f) * 3.0f - 0.0f)) * (0.025f);
		sundiff /= 1.5f;
		sundiff = -GetCoverage(coverage * 1.0f, 0.0f, sundiff);
		float secondOrder 	= pow(clamp(sundiff * 1.00f + 1.35f, 0.0f, 1.0f), 7.0f);
		float firstOrder 	= pow(clamp(largeSundiff * 1.1f + 1.56f, 0.0f, 1.0f), 3.0f);

		float directLightFalloff = secondOrder;
		float anisoBackFactor = mix(clamp(pow(noise, 1.6f) * 2.5f, 0.0f, 1.0f), 1.0f, pow(sunglow, 1.0f));
			  directLightFalloff *= anisoBackFactor;
		 	  directLightFalloff *= mix(1.5f, 1.0f, pow(sunglow, 1.0f))*2;

		vec3 colorDirect = colorSunlight * 10.0f;
			 colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.5f, 1.0f), timeMidnight);
			 colorDirect *= 1.0f + pow(sunglow, 8.0f) * 100.0f;

		vec3 colorAmbient = mix(colorSkylight, colorSunlight, 0.15f) * 0.065f;
					 colorAmbient *= mix(1.0f, 0.3f, timeMidnight);


		directLightFalloff *= 1.0f - rainStrength * 0.99f;

		vec3 color = mix(colorAmbient, colorDirect, vec3(min(1.0f, directLightFalloff)));

		color *= 1.0f;

		vec4 result = vec4(color, noise);

		return result;
	}
}

void CloudPlane(inout SurfaceStruct surface) {
	//Initialize view ray
	vec4 worldVector = gbufferModelViewInverse * (-GetScreenSpacePosition(texcoord.st, 1.0f));

	surface.viewRay.dir = normalize(worldVector.xyz);
	surface.viewRay.origin = vec3(0.0f);

	float sunglow = CalculateSunglow(surface);

	float cloudsAltitude = 540.0f;
	float cloudsThickness = 150.0f;

	float cloudsUpperLimit = cloudsAltitude + cloudsThickness * 0.5f;
	float cloudsLowerLimit = cloudsAltitude - cloudsThickness * 0.5f;

	float density = 1.0f;

	if (cameraPosition.y < cloudsLowerLimit) {
		float planeHeight = cloudsUpperLimit;

		float stepSize = 25.5f;
		planeHeight -= cloudsThickness * 0.85f;

		Plane pl;
		pl.origin = vec3(0.0f, cameraPosition.y - planeHeight, 0.0f);
		pl.normal = vec3(0.0f, 1.0f, 0.0f);

		Intersection i = RayPlaneIntersectionWorld(surface.viewRay, pl);

		if (i.angle < 0.0f) {
			if (i.distance < surface.linearDepth || surface.mask.sky) {
				vec4 cloudSample = CloudColor2(vec4(i.pos.xyz * 0.5f + vec3(30.0f), 1.0f), sunglow, surface.worldLightVector, cloudsAltitude, cloudsThickness, false);
			 	cloudSample.a = min(1.0f, cloudSample.a * density);

				surface.sky.albedo.rgb = mix(surface.sky.albedo.rgb, cloudSample.rgb, cloudSample.a);

				cloudSample = CloudColor2(vec4(i.pos.xyz * 0.65f + vec3(10.0f) + vec3(i.pos.z * 0.5f, 0.0f, 0.0f), 1.0f), sunglow, surface.worldLightVector, cloudsAltitude, cloudsThickness, false);
				cloudSample.a = min(1.0f, cloudSample.a * density);

				surface.sky.albedo.rgb = mix(surface.sky.albedo.rgb, cloudSample.rgb, cloudSample.a);
			}
		}
	}
}

vec4 CloudColor(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector) {
	float cloudHeight = 230.0f;
	float cloudDepth  = 150.0f;
	float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
	float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

	if (worldPosition.y < cloudLowerHeight || worldPosition.y > cloudUpperHeight) {
		return vec4(0.0f);
	} else {
		vec3 p = worldPosition.xyz / 150.0f;

		float t = frameTimeCounter / 2.0f;
			  //t *= 0.001;
		p.x -= t * 0.02f;

		p += (Get3DNoise(p * 1.0f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.3f;

		vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
		float noise  = 	Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));	p *= 4.0f;	p.x -= t * 0.02f;	vec3 p2 = p;
			  noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.20f;				p *= 3.0f;	p.xz -= t * 0.05f;	vec3 p3 = p;
			  noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.075f;				p *= 2.0f;	p.xz -= t * 0.05f;
			  noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.05f;				p *= 2.0f;
			  noise /= 1.2f;


		const float lightOffset = 0.35f;

		float cloudAltitudeWeight = 1.0f - clamp(distance(worldPosition.y, cloudHeight) / (cloudDepth / 2.0f), 0.0f, 1.0f);
			  cloudAltitudeWeight = pow(cloudAltitudeWeight, 0.5f);

		noise *= cloudAltitudeWeight;

		//cloud edge
		float coverage = 0.45f;
			  coverage = mix(coverage, 0.77f, rainStrength);
		float density = 0.66f;
		noise = clamp(noise - (1.0f - coverage), 0.0f, 1.0f - density) / (1.0f - density);

		float directLightFalloff = clamp(pow(-(cloudLowerHeight - worldPosition.y) / cloudDepth, 3.5f), 0.0f, 1.0f);

		directLightFalloff *= mix(	clamp(pow(noise, 0.9f), 0.0f, 1.0f), 	clamp(pow(1.0f - noise, 10.3f), 0.0f, 0.5f), 	pow(sunglow, 0.2f));

		vec3 colorDirect = colorSunlight * 38.0f;
		colorDirect = mix(colorDirect, colorDirect * vec3(0.1f, 0.2f, 0.3f), timeMidnight);
		colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.2f, 0.2f), rainStrength);
		colorDirect *= 1.0f + pow(sunglow, 4.0f) * 100.0f;

		vec3 colorAmbient = mix(colorSkylight, colorSunlight, 0.15f) * 0.065f;
			 colorAmbient *= mix(1.0f, 0.3f, timeMidnight);

		vec3 color = mix(colorAmbient, colorDirect, vec3(directLightFalloff));

		vec4 result = vec4(color.rgb, noise);

		return result;
	}
}

void 	CalculateClouds (inout vec3 color, inout SurfaceStruct surface) {
	surface.cloudAlpha = 0.0f;

	vec2 coord = texcoord.st * 2.0f;

	vec4 worldPosition = gbufferModelViewInverse * surface.screenSpacePosition;
		 worldPosition.xyz += cameraPosition.xyz;

	float cloudHeight = 150.0f;
	float cloudDepth  = 60.0f;
	float cloudDensity = 2.25f;

	float startingRayDepth = far - 5.0f;

	float rayDepth = startingRayDepth;
	float rayIncrement = far / CLOUD_DISPERSE;
	rayDepth += CalculateDitherPattern1() * rayIncrement;

	int i = 0;

	vec3 cloudColor = colorSunlight;
	vec4 cloudSum = vec4(0.0f);
		 cloudSum.rgb = colorSkylight * 0.2f;
		 cloudSum.rgb = color.rgb;

	float sunglow = CalculateSunglow(surface);

	float cloudDistanceMult = 400.0f / far;

	float surfaceDistance = length(worldPosition.xyz - cameraPosition.xyz);

	while (rayDepth > 0.0f) {
		//determine worldspace ray position
		vec4 rayPosition = GetCloudSpacePosition(texcoord.st, rayDepth, cloudDistanceMult);

		float rayDistance = length((rayPosition.xyz - cameraPosition.xyz) / cloudDistanceMult);

		vec4 proximity =  CloudColor(rayPosition, sunglow, surface.worldLightVector);
			 proximity.a *= cloudDensity;

		if (surfaceDistance < rayDistance * cloudDistanceMult && !surface.mask.sky) {
			proximity.a = 0.0f;
		}

		color.rgb = mix(color.rgb, proximity.rgb, vec3(min(1.0f, proximity.a * cloudDensity)));

		surface.cloudAlpha += proximity.a;

		//Increment ray
		rayDepth -= rayIncrement;
		i++;
	}
}

float CloudShadow(in SurfaceStruct surface) {
	float cloudsAltitude = 540.0f;
	float cloudsThickness = 150.0f;

	float cloudsUpperLimit = cloudsAltitude + cloudsThickness * 0.5f;
	float cloudsLowerLimit = cloudsAltitude - cloudsThickness * 0.5f;

	float planeHeight = cloudsUpperLimit;

	planeHeight -= cloudsThickness * 0.85f;

	Plane pl;
	pl.origin = vec3(0.0f, planeHeight, 0.0f);
	pl.normal = vec3(0.0f, 1.0f, 0.0f);

	//Cloud shadow
	Ray surfaceToSun;
	vec4 sunDir = gbufferModelViewInverse * vec4(surface.lightVector, 0.0f);
	surfaceToSun.dir = normalize(sunDir.xyz);
	vec4 surfacePos = gbufferModelViewInverse * surface.screenSpacePosition;
	surfaceToSun.origin = surfacePos.xyz + cameraPosition.xyz;

	Intersection i = RayPlaneIntersection(surfaceToSun, pl);

	float cloudShadow = CloudColor2(vec4(i.pos.xyz * 0.5f + vec3(30.0f), 1.0f), 0.0f, vec3(1.0f), cloudsAltitude, cloudsThickness, true).x;
		  cloudShadow += CloudColor2(vec4(i.pos.xyz * 0.65f + vec3(10.0f) + vec3(i.pos.z * 0.5f, 0.0f, 0.0f), 1.0f), 0.0f, vec3(1.0f), cloudsAltitude, cloudsThickness, true).x;

		  cloudShadow = min(cloudShadow, 0.95f);
		  cloudShadow = 1.0f - cloudShadow;

	return cloudShadow;
}

void 	SnowShader(inout SurfaceStruct surface){
	float snowFactor = dot(surface.normal, upVector);
		  snowFactor = clamp(snowFactor - 0.1f, 0.0f, 0.05f) / 0.05f;
	surface.albedo = mix(surface.albedo.rgb, vec3(1.0f), vec3(snowFactor));
}

void 	Test(inout vec3 color, inout SurfaceStruct surface) {
	vec4 rayScreenSpace = GetScreenSpacePosition(texcoord.st, 1.0f);
		 rayScreenSpace = -rayScreenSpace;
	     rayScreenSpace = gbufferModelViewInverse * rayScreenSpace;

	float planeAltitude = 100.0f;

	vec3 rayDir = normalize(rayScreenSpace.xyz);
	vec3 planeOrigin = vec3(0.0f, 1.0f, 0.0f);
	vec3 planeNormal = vec3(0.0f, 1.0f, 0.0f);
	vec3 rayOrigin = vec3(0.0f);

	float denom = dot(rayDir, planeNormal);

	vec3 intersectionPos = vec3(0.0f);

	if (denom > 0.0001f || denom < -0.0001f)
	{
		float planeRayDist = dot((planeOrigin - rayOrigin), planeNormal) / denom;	//How far along the ray that the ray intersected with the plane

		//if (planeRayDist > 0.0f)
		intersectionPos = rayDir * planeRayDist;
		intersectionPos = -intersectionPos;

		intersectionPos.xz *= cameraPosition.y - 100.0f;

		intersectionPos += cameraPosition.xyz;

		intersectionPos.x = mod(intersectionPos.x, 1.0f);
		intersectionPos.y = mod(intersectionPos.y, 1.0f);
		intersectionPos.z = mod(intersectionPos.z, 1.0f);
	}


	color += intersectionPos.xyz * 0.1f;
}

vec3 Contrast(in vec3 color, in float contrast) {
	float colorLength = length(color);
	vec3 nColor = color / colorLength;

	colorLength = pow(colorLength, contrast);

	return nColor * colorLength;
}

float GetAO(in vec4 screenSpacePosition, in vec3 normal, in vec2 coord, in vec3 dither) {
	//Determine origin position
	vec3 origin = screenSpacePosition.xyz;

	vec3 randomRotation = normalize(dither.xyz * vec3(2.0f, 2.0f, 1.0f) - vec3(1.0f, 1.0f, 0.0f));

	vec3 tangent = normalize(randomRotation - normal * dot(randomRotation, normal));
	vec3 bitangent = cross(normal, tangent);
	mat3 tbn = mat3(tangent, bitangent, normal);

	float aoRadius   = 0.15f * -screenSpacePosition.z;
		  //aoRadius   = 0.8f;
	float zThickness = 0.15f * -screenSpacePosition.z;
		  //zThickness = 2.2f;

	vec3 	samplePosition 		= vec3(0.0f);
	float 	intersect 			= 0.0f;
	vec4 	sampleScreenSpace 	= vec4(0.0f);
	float 	sampleDepth 		= 0.0f;
	float 	distanceWeight 		= 0.0f;
	float 	finalRadius 		= 0.0f;

	int numRaysPassed = 0;

	float ao = 0.0f;

	for (int i = 0; i < 4; i++)
	{
		vec3 kernel = vec3(texture2D(noisetex, vec2(0.1f + (i * 1.0f) / 64.0f)).r * 2.0f - 1.0f,
					     texture2D(noisetex, vec2(0.1f + (i * 1.0f) / 64.0f)).g * 2.0f - 1.0f,
					     texture2D(noisetex, vec2(0.1f + (i * 1.0f) / 64.0f)).b * 1.0f);
			 kernel = normalize(kernel);
			 kernel *= pow(dither.x + 0.01f, 1.0f);

		samplePosition = tbn * kernel;
		samplePosition = samplePosition * aoRadius + origin;

			sampleScreenSpace = gbufferProjection * vec4(samplePosition, 0.0f);
			sampleScreenSpace.xyz /= sampleScreenSpace.w;
			sampleScreenSpace.xyz = sampleScreenSpace.xyz * 0.5f + 0.5f;

			//Check depth at sample point
			sampleDepth = GetScreenSpacePosition(sampleScreenSpace.xy).z;

			//If point is behind geometry, buildup AO
			if (sampleDepth >= samplePosition.z && sampleDepth - samplePosition.z < zThickness)
			{
				ao += 1.0f;
			} else {

			}
	}
	ao /= 4;
	ao = 1.0f - ao;
	ao = pow(ao, 2.1f);

	return ao;
}

vec4 BilateralUpsample(const in float scale, in vec2 offset, in float depth, in vec3 normal) {
	vec2 recipres = vec2(1.0f / viewWidth, 1.0f / viewHeight);

	vec4 light = vec4(0.0f);
	float weights = 0.0f;

	for (float i = -0.5f; i <= 0.5f; i += 1.0f)
	{
		for (float j = -0.5f; j <= 0.5f; j += 1.0f)
		{
			vec2 coord = vec2(i, j) * recipres * 2.0f;

			float sampleDepth = GetDepthLinear(texcoord.st + coord * 2.0f * (exp2(scale)));
			vec3 sampleNormal = GetNormals(texcoord.st + coord * 2.0f * (exp2(scale)));
			float weight = clamp(1.0f - abs(sampleDepth - depth) / 2.0f, 0.0f, 1.0f);
				  weight *= max(0.0f, dot(sampleNormal, normal) * 2.0f - 1.0f);

			light +=	pow(texture2DLod(gaux1, (texcoord.st) * (1.0f / exp2(scale )) + 	offset + coord, 1), vec4(2.2f, 2.2f, 2.2f, 1.0f)) * weight;

			weights += weight;
		}
	}

	light /= max(0.00001f, weights);

	if (weights < 0.01f)
	{
		light =	pow(texture2DLod(gaux1, (texcoord.st) * (1.0f / exp2(scale 	)) + 	offset, 2), vec4(2.2f, 2.2f, 2.2f, 1.0f));
	}

	return light;
}

vec4 Delta(vec3 albedo, vec3 normal, float skylight) {
	float depth = GetDepthLinear(texcoord.st);

	vec4 delta = BilateralUpsample(1.0f, vec2(0.0f, 0.0f), 		depth, normal);

	delta.rgb = delta.rgb * albedo * colorSunlight;

	delta.rgb *= 1.0f;

	delta.rgb *= 5.0f * delta.a * delta.a * (1.0 - rainStrength) * pow(skylight, 0.5);

	// delta.rgb *= sin(frameTimeCounter) > 0.6 ? 0.0 : 1.0;

	return delta;
}

float getnoise(vec2 pos) {
    return abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f));
}

vec3 calculateFresnelSchlick( in vec3 n, in float ndotv ) {
    vec3 F0 = (vec3( 1.0 ) - n) / (vec3( 1.0 ) + n);
    //F0 = F0 * F0;
    return F0 + ((vec3( 1.0 ) - F0) * pow(1.0 - ndotv, 5.0));
}

void initializeSky( inout SurfaceStruct surface ) {
    //Initialize sky surface properties
	surface.sky.albedo 		= GetAlbedoLinear(texcoord.st) * (min(1.0f, float(surface.mask.sky) + float(surface.mask.sunspot)));							//Gets the albedo texture for the sky

	surface.sky.tintColor 	= mix(colorSunlight, vec3(colorSunlight.r), vec3(0.8f));									//Initializes the defualt tint color for the sky
	surface.sky.tintColor 	*= mix(1.0f, 100.0f, timeSkyDark); //Boost sky color at night

    //Scale sunglow back to be less intense
    vec3 sunspot = vec3( float( CalculateSunspot( surface ) ) );
	surface.sky.sunSpot   	= sunspot * vec3(min(1.0f, float(surface.mask.sky) + float(surface.mask.sunspot))) * colorSunlight;
	surface.sky.sunSpot 	*= 1.0f - timeMidnight;
	surface.sky.sunSpot   	*= 300.0f;
	surface.sky.sunSpot 	*= 1.0f - rainStrength;
	//surface.sky.sunSpot     *= 1.0f - timeMidnight;

	AddSkyGradient(surface);
	AddSunglow(surface);
}

void initializeSurface( inout SurfaceStruct surface ) {
    //Initialize surface properties required for lighting calculation for any surface that is not part of the sky
	surface.albedo 				= GetAlbedoLinear(texcoord.st);
	surface.albedo 				= pow(surface.albedo, vec3(1.4f));
	surface.normal 				= GetNormals(texcoord.st);
	surface.depth  				= GetDepth(texcoord.st);
	surface.linearDepth 		= ExpToLinearDepth(surface.depth);
	surface.screenSpacePosition = GetScreenSpacePosition(texcoord.st);
	surface.viewVector 			= normalize(surface.screenSpacePosition.rgb);	//Gets the view vector
	surface.lightVector 		= lightVector;									//Gets the sunlight vector
	surface.upVector 			= upVector;

	surface.mask.matIDs 		= GetMaterialIDs(texcoord.st);
	CalculateMasks(surface.mask);

	surface.albedo *= 1.0f - float(surface.mask.sky);   //Remove the sky from surface albedo, because sky will be handled separately

	initializeSky( surface );

#ifdef GI
    vec4 wlv 					= shadowModelViewInverse * vec4(0.0f, 0.0f, 1.0f, 0.0f);
	surface.worldLightVector 	= normalize(wlv.xyz);
#endif
}

void initializeLightmap( inout MCLightmapStruct mcLightmap ) {
    //Initialize MCLightmap values
	mcLightmap.torch 		= GetLightmapTorch(texcoord.st);
	mcLightmap.sky   		= GetLightmapSky(texcoord.st);
	mcLightmap.lightning    = 0.0f;
}

void initializeDiffuseAndSpecular( inout SurfaceStruct surface ) {
  	//Initialize default surface shading attributes
	surface.diffuse.roughness 			= GetRoughness(texcoord.st);
	surface.diffuse.translucency 		= 0.0f;					//Default surface translucency
	surface.diffuse.translucencyColor 	= vec3(1.0f);			//Default translucency color

	surface.specular.roughness 		    = GetRoughness(texcoord.st);
  	// If the surface is more than 50% specular, I assume it's a metal. This is probably wrong. A PBR texture pack could fix this
	surface.specular.metallic 			= getMetalness( texcoord.st );
  	// For some reason, leaves are considered to be super specular. I need to get rid of that
  	if( surface.mask.leaves ) {
      	surface.specular.metallic = 0;
  	}

  	// Generate the specular color from the metalness
  	surface.specular.specularColor = mix( vec3( 0.03 ), surface.albedo, surface.specular.metallic);

  	float ndotv = max( dot( surface.normal, -normalize( surface.viewVector ) ), 0.0f );
	surface.specular.fresnel        = calculateFresnelSchlick( surface.specular.specularColor, ndotv );
	// Subtract the speculr color from the albedo to maintain conservaion of energy
	//surface.albedo -= surface.specular.fresnel;
}

void calculateDirectLighting( inout ShadingStruct shading ) {
    //Calculate surface shading
	CalculateNdotL(surface);
	shading.direct  			= CalculateDirectLighting(surface);				//Calculate direct sunlight without visibility check (shadows)
	shading.direct  			= mix(shading.direct, 1.0f, float(surface.mask.water)); //Remove shading from water
	shading.sunlightVisibility 	= CalculateSunlightVisibility(surface, shading);					//Calculate shadows and apply them to direct lighting
	shading.direct 				*= shading.sunlightVisibility;
	shading.direct 				*= mix(1.0f, 0.0f, rainStrength);
	shading.waterDirect 		= shading.direct;
	shading.direct 				*= pow(mcLightmap.sky, 0.1f);
	shading.skylight 	= CalculateSkylight(surface);					//Calculate scattered light from sky
	shading.heldLight 	= CalculateHeldLightShading(surface);

#ifndef GI
	shading.bounced 	= CalculateBouncedSunlight(surface);			//Calculate fake bounced sunlight
	shading.scattered 	= CalculateScatteredSunlight(surface);			//Calculate fake scattered sunlight
	shading.scatteredUp = CalculateScatteredUpLight(surface);
#endif
}

void calculateSkyLighting( inout LightmapStruct lightmap ) {
    //Colorize surface shading and store in lightmaps
	lightmap.sunlight 			= vec3(shading.direct) * colorSunlight;
	AddCloudGlow(lightmap.sunlight, surface);

	lightmap.skylight 			= vec3(mcLightmap.sky);

    float wetnessFactor = mix( 0.7f, 1.0f, wetness );
	lightmap.skylight 			*= mix(colorSkylight, colorBouncedSunlight, vec3(max(0.0f, (1.0f - pow(mcLightmap.sky + 0.1f, 0.45f) * 1.0f)))) + colorBouncedSunlight * wetnessFactor * (1.0f - rainStrength);
	lightmap.skylight 			*= shading.skylight;
	lightmap.skylight 			*= mix(1.0f, 5.0f, float(surface.mask.clouds));
	lightmap.skylight 			*= mix(1.0f, 50.0f, float(surface.mask.clouds) * timeSkyDark);
	lightmap.skylight 			*= surface.ao.skylight;
	lightmap.skylight 			+= mix(colorSkylight, colorSunlight, vec3(0.2f)) * vec3(mcLightmap.sky) * surface.ao.constant * 0.05f;
	lightmap.skylight 			*= mix(1.0f, 1.2f, rainStrength);
}

void calculateNonSkyLighting( inout LightmapStruct lightmap ) {
    lightmap.underwater 		= vec3(mcLightmap.sky) * colorSkylight;

	lightmap.torchlight 		= mcLightmap.torch * colorTorchlight;
	lightmap.torchlight 	 	*= surface.ao.constant * surface.ao.constant;

	lightmap.nolight 			= vec3(0.05f);
	lightmap.nolight 			*= surface.ao.constant;


	lightmap.heldLight 			= vec3(shading.heldLight);
	lightmap.heldLight 			*= colorTorchlight;
	lightmap.heldLight 			*= heldBlockLightValue / 16.0f;
}

void calculateWaterEye( inout LightmapStruct lightmap ) {
    vec3 halfColor = mix(colorWaterMurk, vec3(1.0f), vec3(0.5f));
    lightmap.sunlight *= mcLightmap.sky * halfColor;
	lightmap.skylight *= halfColor;
	lightmap.bouncedSunlight *= 0.0f;
	lightmap.scatteredSunlight *= halfColor;
	lightmap.nolight *= halfColor;
	lightmap.scatteredUpLight *= halfColor;
}

void applyLightmaps( inout FinalStruct final ) {
    //Apply lightmaps to albedo and generate final shaded surface
	final.nolight 			= surface.albedo * lightmap.nolight;
	final.sunlight 			= surface.albedo * lightmap.sunlight;
	final.skylight 			= surface.albedo * lightmap.skylight;
	final.bouncedSunlight 	= surface.albedo * lightmap.bouncedSunlight;
	final.scatteredSunlight = surface.albedo * lightmap.scatteredSunlight;
	final.scatteredUpLight  = surface.albedo * lightmap.scatteredUpLight;
	final.torchlight 		= surface.albedo * lightmap.torchlight;

	final.underwater        = surface.water.albedo * colorWaterBlue;
	final.underwater 		*= (lightmap.sunlight * 0.3f) + (lightmap.skylight * 0.06f) + (lightmap.torchlight * 0.0165) + (lightmap.nolight * 0.002f);

	//final.glow.torch 				= pow(surface.albedo, vec3(4.0f)) * float(surface.mask.torch);
	final.glow.lava 				= Glowmap(surface.albedo, surface.mask.lava,      3.0f, vec3(1.0f, 0.05f, 0.00f));

	final.glow.glowstone 			= Glowmap(surface.albedo, surface.mask.glowstone, 1.9f, colorTorchlight);
	final.torchlight 			   *= 1.0f - float(surface.mask.glowstone);

	final.glow.fire 				= surface.albedo * float(surface.mask.fire);
	final.glow.fire 				= pow(final.glow.fire, vec3(1.0f));

	final.glow.torch 				= pow(surface.albedo * float(surface.mask.torch), vec3(4.4f));

	//Remove glow items from torchlight to keep control
	final.torchlight *= 1.0f - float(surface.mask.lava);

	final.heldLight = lightmap.heldLight * surface.albedo;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////MAIN//////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main() {

	initializeSurface( surface );
    initializeLightmap( mcLightmap );
    initializeDiffuseAndSpecular( surface );

    calculateDirectLighting( shading );
	InitializeAO( surface );
    calculateSkyLighting( lightmap );
    calculateNonSkyLighting( lightmap );

#ifndef GI
    // Calculate GI
	lightmap.bouncedSunlight	= vec3(shading.bounced) * colorBouncedSunlight;
	lightmap.bouncedSunlight 	*= pow(vec3(mcLightmap.sky), vec3(1.75f));
	lightmap.bouncedSunlight 	*= mix(1.0f, 0.25f, timeSunrise + timeSunset);
	lightmap.bouncedSunlight 	*= mix(1.0f, 0.0f, rainStrength);
	lightmap.bouncedSunlight 	*= surface.ao.bouncedSunlight;

	lightmap.scatteredSunlight  = vec3(shading.scattered) * colorScatteredSunlight * (1.0f - rainStrength);
	lightmap.scatteredSunlight 	*= pow(vec3(mcLightmap.sky), vec3(1.0f));

    lightmap.scatteredUpLight 	= vec3(shading.scatteredUp) * mix(colorSunlight, colorSkylight, vec3(0.0f));
	lightmap.scatteredUpLight   *= pow(mcLightmap.sky, 0.5f);
	lightmap.scatteredUpLight 	*= surface.ao.scatteredUpLight;
	lightmap.scatteredUpLight 	*= mix(1.0f, 0.1f, rainStrength);
#else
	float ao = 1.0;

	vec4 delta = vec4(0.0);
	delta.a = 1.0;

	delta = Delta(surface.albedo.rgb, surface.normal.xyz, mcLightmap.sky);

	ao = delta.a;

	lightmap.torchlight 		*= ao;
	lightmap.nolight 			*= ao;
#endif

	//If eye is in water
	if (isEyeInWater > 0) {
		calculateWaterEye( lightmap );
	}

	surface.albedo.rgb = mix(surface.albedo.rgb, pow(surface.albedo.rgb, vec3(2.0f)), vec3(float(surface.mask.fire)));

	applyLightmaps( final );


	//Do night eye effect on outdoor lighting and sky
	DoNightEye(final.sunlight);
	DoNightEye(final.skylight);
	DoNightEye(final.bouncedSunlight);
	DoNightEye(final.scatteredSunlight);
	DoNightEye(surface.sky.albedo);
	DoNightEye(final.underwater);

	DoLowlightEye(final.nolight);

#ifdef CLOUD_SHADOW
	surface.cloudShadow = CloudShadow(surface);
	float sunlightMult = surface.cloudShadow * 2.0f + 0.1f;
#else
	surface.cloudShadow = 1.0f;
	const float sunlightMult = 1.45f;
#endif

	//Apply lightmaps to albedo and generate final shaded surface
	vec3 finalComposite = final.sunlight 		* 0.9f 	* 1.5f * sunlightMult	//Add direct sunlight
						+ final.skylight 		* 0.05f				//Add ambient skylight
						+ final.nolight 		* 0.00005f 			//Add base ambient light
						+ final.torchlight 		* 5.0f 			//Add light coming from emissive blocks
						+ final.glow.lava		* 2.6f
						+ final.glow.glowstone	* 2.1f
						+ final.glow.fire		* 0.35f
						+ final.glow.torch		* 1.15f
						#ifdef HELD_LIGHT
						+ final.heldLight 		* 0.05f
						#endif
						;

	//Apply sky to final composite
	surface.sky.albedo *= 0.85f;
	surface.sky.albedo = surface.sky.albedo * surface.sky.tintColor + surface.sky.sunglow + surface.sky.sunSpot;
#ifdef CLOUD_PLANE
		 CloudPlane(surface);
#endif
		 //DoNightEye(surface.sky.albedo);
		 finalComposite 	+= surface.sky.albedo;		//Add sky to final image

#ifdef GI
		finalComposite 	+= delta.rgb * sunlightMult;
#endif

		vec4 cloudsTexture = pow(texture2DLod(gaux2, texcoord.st / 4.0, 0).rgba, vec4(2.2, 2.2, 2.2, 1.0));
		//if eye is in water, do underwater fog
		if (isEyeInWater > 0) {
			CalculateUnderwaterFog(surface, finalComposite);
		}

#ifdef RAIN_FOG
	CalculateRainFog(finalComposite.rgb, surface);

#endif
////////////////////////////////////

////////////////////////////////////
#ifdef NEW_UNDERWATER
	#ifdef ATMOSPHERIC_FOG
		if (isEyeInWater > 0) {
			//CalculateAtmosphericFog(finalComposite.rgb, surface);
		} else {
			CalculateAtmosphericFog(finalComposite.rgb, surface);
		}
	#endif
#else
	#ifdef ATMOSPHERIC_FOG
		CalculateAtmosphericFog(finalComposite.rgb, surface);
	#endif
#endif

//////////////////////////////////////

#ifdef VOLUMETRIC_CLOUDS
	CalculateClouds(finalComposite.rgb, surface);
#endif

#ifdef GODRAYS
	float gr = 0.0f;
	vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
	tpos = vec4(tpos.xyz/tpos.w,1.0);
	vec2 pos1 = tpos.xy/tpos.z;
	vec2 lightPos = pos1*0.5+0.5;


	float truepos = sign(sunPosition.z);

	if (truepos < 0.0) {
		vec2 deltaTextCoord = vec2( texcoord.st - lightPos.xy );
		vec2 textCoord = texcoord.st;
		deltaTextCoord *= 1.0 / float(NUM_SAMPLES) * grdensity;

			float avgdecay = 0.0;
			float distx = abs(texcoord.x*aspectRatio-lightPos.x*aspectRatio);
			float disty = abs(texcoord.y-lightPos.y);
			float fallof = 1.0;
			float noise = getnoise(textCoord);

			for(int i=0; i < NUM_SAMPLES ; i++) {
				textCoord -= deltaTextCoord;

				fallof *= GODRAY_LENGTH;
				float sample = step(texture2D(gdepth, textCoord+ deltaTextCoord*noise*grnoise).r,0.001);
				gr += sample*fallof;
		}
	}
#ifdef MOONRAYS
	else {
	vec4 tpos = vec4(-sunPosition,1.0)*gbufferProjection;
	tpos = vec4(tpos.xyz/tpos.w,1.0);
	vec2 pos1 = tpos.xy/tpos.z;
	vec2 lightPos = pos1*0.5+0.5;


	//float truepos = sign(sunPosition.z);

		if (truepos > 0.0) {
		vec2 deltaTextCoord = vec2( texcoord.st - lightPos.xy );
		vec2 textCoord = texcoord.st;
		deltaTextCoord *= 1.0 / float(NUM_SAMPLES) * grdensity;

			float avgdecay = 0.0;
			float distx = abs(texcoord.x*aspectRatio-lightPos.x*aspectRatio);
			float disty = abs(texcoord.y-lightPos.y);
			float fallof = 1.0;
			float noise = getnoise(textCoord);

			for(int i=0; i < NUM_SAMPLES ; i++) {
				textCoord -= deltaTextCoord;

				fallof *= 0.65;
				float sample = step(texture2D(gdepth, textCoord+ deltaTextCoord*noise*grnoise).r,0.001);
				gr += sample*fallof;
			}
		}
	}
#endif

#endif

	finalComposite *= 0.0007f;	//Scale image down for HDR
	finalComposite.b *= 1.0f;

	finalComposite = pow(finalComposite, vec3(1.0f / 2.2f)); 					//Convert final image into gamma 0.45 space to compensate for gamma 2.2 on displays
	finalComposite = pow(finalComposite, vec3(1.0f / BANDING_FIX_FACTOR)); 	//Convert final image into banding fix space to help reduce color banding

	if (finalComposite.r > 1.0f) {
		finalComposite.r = 0.0f;
	}

	if (finalComposite.g > 1.0f) {
		finalComposite.g = 0.0f;
	}

	if (finalComposite.b > 1.0f) {
		finalComposite.b = 0.0f;
	}

	//finalComposite = mix( finalComposite, surface.specular.specularColor, surface.specular.metallic );
	finalComposite = vec3( surface.specular.fresnel );

#ifdef NO_GODRAYS
	gl_FragData[0] = vec4(finalComposite, 1.0f);
#endif

#ifdef GODRAYS
	gl_FragData[0] = vec4(finalComposite, (gr/NUM_SAMPLES));
#endif

#ifdef BETTER_SPECULAR
		gl_FragData[1] = vec4(surface.mask.matIDs, mcLightmap.torch + surface.shadow * surface.cloudShadow * pow(mcLightmap.sky, 0.2f), mcLightmap.sky, 1.0f);
#else
		gl_FragData[1] = vec4(surface.mask.matIDs, surface.shadow * surface.cloudShadow * pow(mcLightmap.sky, 0.2f), mcLightmap.sky, 1.0f);
#endif
	gl_FragData[2] = vec4(surface.normal.rgb * 0.5f + 0.5f, 1.0f);
	gl_FragData[3] = vec4(surface.specular.metallic, surface.cloudAlpha, surface.specular.roughness, 1.0f);
}
