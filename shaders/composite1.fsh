#version 120
#extension GL_ARB_shader_texture_lod : enable

/*
 _______ _________ _______  _______  _
(  ____ \\__   __/(  ___  )(  ____ )( )
| (    \/   ) (   | (   ) || (    )|| |
| (_____    | |   | |   | || (____)|| |
(_____  )   | |   | |   | ||  _____)| |
      ) |   | |   | |   | || (      (_)
/\____) |   | |   | (___) || )       _
\_______)   )_(   (_______)|/       (_)

Do not modify this code until you have read the LICENSE.txt contained in the root directory of this shaderpack!

*/

#include "lib/test.glsl"


/////////ADJUSTABLE VARIABLES//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////ADJUSTABLE VARIABLES//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define SHADOW_MAP_BIAS 0.80

#define Global_Illumination
#define GI_FILTER_QUALITY 0.5 		//[0.5 1.5 2.5 3.5 4.5 5.5 6.5 7.5] //Sets the actual quality of the GI

//#define ENABLE_SOFT_SHADOWS
#define VARIABLE_PENUMBRA_SHADOWS
#define USE_RANDOM_ROTATION

#define Brightness 1.25				//[0.10 0.25 0.50 0.75 1.0 1.25 1.35 1.5]
#define Shadow_Brightness 0.55		//[0.05 0.1 0.25 0.35 0.45 0.55 0.63 0.7 1.0 3.0 5.0 10.0]

#define Torch_Brightness 0.008		//[0.005 0.008 0.01 0.04 0.06 0.08 0.1]

#define HELD_LIGHT				//Dynamic Torch Light when in player hand

#define CAVE_BRIGHTNESS	0.0007		//[0.0002 0.0005 0.0007 0.003]

#define RAIN_FOG
	#define FOG_DENSITY	0.0030f			//default is 0.0018f and is best if using RainFog2 from final[0.0018 0.0025 0.0030 0.0038]

#define ATMOSPHERIC_FOG
#define NO_ATMOSPHERIC_FOG_INSIDE		//removes distant fog in caves/buildings
#define MORNING_FOG
#define EVENING_FOG

//#define NO_LEAVE_GRASS_LIGHTING		//This removes Sunlight from the tree leaves so you dont get over bright tree leaves that are far away

//----------3D clouds----------//
//#define VOLUMETRIC_CLOUDS				//Original 3D Clouds from 1.0 and 1.1, bad dither pattern ripple, ONLY ENABLE ONE VOLUMETRIC CLOUDS
//#define VOLUMETRIC_CLOUDS2				//latest 3D clouds, Reduced dither pattern ripple, ONLY ENABLE ONE VOLUMETRIC CLOUDS
#define VOLUMETRIC_CLOUDS3
#define SOFT_FLUFFY_CLOUDS				// dissable to fully remove dither Pattern ripple, adds a little pixel noise on cloud edge
#define CLOUD_DISPERSE 10.0f          // increase this for thicker clouds and so that they don't fizzle away when you fly close to them, 10 is default Dont Go Over 30 will lag and maybe crash
#define Vol_Cloud_Coverage 0.45f		// Vol_Cloud_Coverage. 0.20 = Lowest Cover. 0.60 = Highest Cover [0.20 0.30 0.45 0.50 0.60 0.70]

#define Cloud3Height 200				//[100 120 140 160 180 200 220 240 250] //Sets the Volumetric clouds3 Height
//#define CLOUD3_TYPE
//----------New 2D clouds----------//
//#define CLOUD_PLANE					// 2D clouds
#define CLOUD_PLANE_Coverage 0.40f		// CLOUD_PLANE_Coverage. 0.20 = Lowest Cover. 0.60 = Highest Cover [0.20 0.30 0.40 0.50 0.60 0.70]

#define CLOUD_COVERAGE CLOUD_PLANE_Coverage + rainy * 0.65f;			//to increase the 2Dclouds:" 0.59f + rainy * 0.35f " is Default when not using 3DClouds," 0.5f + rainy * 0.35f " is best for when using 2D and 3D clouds

//----------End CONFIGURABLE 2D Clouds----------//

//----------New Cloud Shadows----------//

//#define CLOUD_SHADOW

//----------End CONFIGURABLE Cloud Shadows----------//

#define UnderwaterFog					//dissable for clear underwater

#define Water_DepthFog

//----------2D GodRays----------//
#define GODRAYS
	const float grdensity = 0.7;
	const int NUM_SAMPLES = 10;			//increase this for better quality at the cost of performance /10 is default
	const float grnoise = 1.0;		//amount of noise /1.0 is default

#define GODRAY_LENGTH 0.75			//default is 0.65, to increase the distance/length of the godrays at the cost of slight increase of sky brightness

#define MOONRAYS					//Make sure if you enable/disable this to do the same in Composite1, PLEASE NOTE Moonrays have a bug at sunset/sunrise

#define VOLUMETRIC_LIGHT			//True GodRays, not 2D ScreenSpace
//----------End CONFIGURABLE 2D GodRays----------//

////----------This feature is connected to ATMOSPHERIC_FOG----------//
//#define NEW_UNDERWATER

//#define GTX500_FIX					//disable this to fix strange colours on GTX 500 cards

/////////INTERNAL VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////INTERNAL VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Do not change the name of these variables or their type. The Shaders Mod reads these lines and determines values to send to the inner-workings
//of the shaders mod. The shaders mod only reads these lines and doesn't actually know the real value assigned to these variables in GLSL.
//Some of these variables are critical for proper operation. Change at your own risk.

const int   shadowMapResolution  = 2048;		 // Shadow Resolution. 1024 = Lowest Quality. 4096 = Highest Quality [1024 2048 3072 4096]
const float 	shadowDistance 			= 140;	// shadowDistance. 60 = Lowest Quality. 200 = Highest Quality [60 100 120 160 180 200]
const float 	shadowIntervalSize 		= 4.0f;
const bool 		shadowHardwareFiltering0 = true;

const bool 		shadowtex1Mipmap = true;
const bool 		shadowtex1Nearest = true;
const bool 		shadowcolor0Mipmap = true;
const bool 		shadowcolor0Nearest = false;
const bool 		shadowcolor1Mipmap = true;
const bool 		shadowcolor1Nearest = false;

const int 		RA8 					= 0;
const int 		RA16 					= 4;
const int 		RGA8 					= 0;
const int 		RGBA8 					= 1;
const int 		RGBA16 					= 1;
const int 		gcolorFormat 			= RGBA16;
const int 		gdepthFormat 			= RGBA8;
const int 		gnormalFormat 			= RGBA16;
const int 		compositeFormat 		= RGBA8;
const int     gaux3Format         	= RGBA16;


const float 	eyeBrightnessHalflife 	= 10.0f;
const float 	centerDepthHalflife 	= 2.0f;
const float 	wetnessHalflife 		= 200.0f;
const float 	drynessHalflife 		= 40.0f;

const int 		superSamplingLevel 		= 0;

const float		sunPathRotation 		= -40.0f;
const float 	ambientOcclusionLevel 	= 0.5f;

const int 		noiseTextureResolution  = 64;


//END OF INTERNAL VARIABLES//

/* DRAWBUFFERS:0136 */

const bool gaux1MipmapEnabled = true;
const bool gaux2MipmapEnabled = true;

#define BANDING_FIX_FACTOR 1.0f

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2DShadow shadow;
uniform sampler2D shadowtex1;
uniform sampler2D noisetex;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;

varying vec4 texcoord;
varying vec3 lightVector;
varying vec3 upVector;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform vec3 sunPosition;
uniform vec3 cameraPosition;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform float sunAngle;

uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

varying float timeSunrise;
varying float timeSunset;
varying float timeSunriseSunset;
varying float timeNoon;
varying float timeMidnight;
varying float timeSkyDark;
varying float transition_fading;

varying vec3 colorSunlight;
varying vec3 colorSkylight;
varying vec3 colorBouncedSunlight;
varying vec3 colorScatteredSunlight;
varying vec3 colorTorchlight;
varying vec3 colorWaterMurk;
varying vec3 colorWaterBlue;

uniform int heldBlockLightValue;

/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

float saturate(float x) {
	return clamp(x, 0.0, 1.0);
}

//Get gbuffer textures
vec3 GetAlbedoLinear(in vec2 coord) {			//Function that retrieves the diffuse texture and convert it into linear space.
	return pow(texture2D(gcolor, coord).rgb, vec3(2.2f));
}

vec3 GetWaterNormals(in vec2 coord) {				//Function that retrieves the screen space surface normals. Used for lighting calculations
	return normalize(texture2DLod(gnormal, coord.st, 0).rgb * 2.0f - 1.0f);
}

vec3 GetNormals(in vec2 coord) {				//Function that retrieves the screen space surface normals. Used for lighting calculations
	return normalize(texture2DLod(gaux2, coord.st, 0).rgb * 2.0f - 1.0f);
}

float GetDepth(in vec2 coord) {					//Function that retrieves the scene depth. 0 - 1, higher values meaning farther away
	return texture2D(gdepthtex, coord).r;
}

float GetDepthSolid(in vec2 coord) {					//Function that retrieves the scene depth. 0 - 1, higher values meaning farther away
	return texture2D(depthtex1, coord).r;
}

float GetDepthLinear(in vec2 coord) {					//Function that retrieves the scene depth. 0 - 1, higher values meaning farther away
	return 2.0f * near * far / (far + near - (2.0f * texture2D(gdepthtex, coord).x - 1.0f) * (far - near));
}

float ExpToLinearDepth(in float depth) {
	return 2.0f * near * far / (far + near - (2.0f * depth - 1.0f) * (far - near));
}

float getnoise(vec2 pos) {
	return abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f));
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
	lightmap 		*= Torch_Brightness;
	lightmap 		= clamp(lightmap, 0.0f, 1.0f);
	lightmap 		= pow(lightmap, 0.9f);
	return lightmap;
}

float 	GetLightmapSky(in vec2 coord) {			//Function that retrieves the lightmap of light emitted by the sky. This is a raw value from 0 (fully dark) to 1 (fully lit) regardless of time of day
	return pow(texture2D(gdepth, coord).b, 4.3f);
}

//Specularity
float 	GetSpecularity(in vec2 coord) {			//Function that retrieves how reflective any surface/pixel is in the scene. Used for reflections and specularity
	return texture2D(composite, texcoord.st).r;
}

float 	GetGlossiness(in vec2 coord) {			//Function that retrieves how reflective any surface/pixel is in the scene. Used for reflections and specularity
	return texture2D(composite, texcoord.st).g;
}

//Material IDs
float 	GetMaterialIDs(in vec2 coord) {			//Function that retrieves the texture that has all material IDs stored in it
	return texture2D(gdepth, coord).r;
}

float 	GetMaterialMask(in vec2 coord ,const in int ID, in float matID) {
	matID = (matID * 255.0f);

	//Catch last part of sky
	if (matID > 254.0f) {
		matID = 0.0f;
	}

	if (matID == ID) {
		return 1.0f;
	} else {
		return 0.0f;
	}
}


float GetWaterMask(in vec2 coord, in float matID) {					//Function that returns "true" if a pixel is water, and "false" if a pixel is not water.
	matID = (matID * 255.0f);

	if (matID >= 35.0f && matID <= 51) {
		return 1.0f;
	} else {
		return 0.0f;
	}
}


//Surface calculations
vec4 GetScreenSpacePosition(in vec2 coord) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
	float depth = GetDepth(coord);
	depth += float(GetMaterialMask(coord, 5, GetMaterialIDs(coord))) * 0.38f;

	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
	fragposition /= fragposition.w;

	return fragposition;
}

vec4 GetScreenSpacePositionSolid(in vec2 coord) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
	float depth = GetDepthSolid(coord);
	depth += float(GetMaterialMask(coord, 5, GetMaterialIDs(coord))) * 0.38f;

	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
	fragposition /= fragposition.w;

	return fragposition;
}

vec4 GetScreenSpacePosition(in vec2 coord, in float depth) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
	fragposition /= fragposition.w;

	return fragposition;
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

void 	DoNightEye(inout vec3 color) {			//Desaturates any color input at night, simulating the rods in the human eye
	float amount = 0.8f; 						//How much will the new desaturated and tinted image be mixed with the original image
	vec3 rodColor = vec3(0.2f, 0.5f, 1.25f); 	//Cyan color that humans percieve when viewing extremely low light levels via rod cells in the eye
	float colorDesat = dot(color, vec3(1.0f)); 	//Desaturated color

	color = mix(color, vec3(colorDesat) * rodColor, timeSkyDark * amount);
}


float 	LinearToExponentialDepth(in float linDepth) {
	return (far * (linDepth - near)) / (linDepth * (far - near));
}

void 	DoLowlightEye(inout vec3 color) {			//Desaturates any color input at night, simulating the rods in the human eye
	float amount = 0.8f; 						//How much will the new desaturated and tinted image be mixed with the original image
	vec3 rodColor = vec3(0.2f, 0.5f, 1.0f); 	//Cyan color that humans percieve when viewing extremely low light levels via rod cells in the eye
	float colorDesat = dot(color, vec3(1.0f)); 	//Desaturated color

	color = mix(color, vec3(colorDesat) * rodColor, amount);
}


float 	CalculateLuminance(in vec3 color) {
	return (color.r * 0.2126f + color.g * 0.7152f + color.b * 0.0722f);
}

vec3 	Glowmap(in vec3 albedo, in float mask, in float curve, in vec3 emissiveColor) {
	vec3 color = albedo * (mask);
	color = pow(color, vec3(curve));
	color = vec3(CalculateLuminance(color));
	color *= emissiveColor;

	return color;
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
	const int[16] ditherPattern = int[16] (0 , 8 , 2 , 10,
									 	   12, 4 , 14, 6 ,
									 	   3 , 11, 1,  9 ,
									 	   15, 7 , 13, 5 );

	vec2 count = vec2(0.0f);
	count.x = floor(mod(texcoord.s * viewWidth, 4.0f));
	count.y = floor(mod(texcoord.t * viewHeight, 4.0f));

	int dither = ditherPattern[int(count.x) + int(count.y) * 4];

	return float(dither) / 16.0f;
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

	return float(dither) / 64.0f;
}

vec3 	CalculateNoisePattern1(vec2 offset, float size) {
	vec2 coord = texcoord.st;

	coord *= vec2(viewWidth, viewHeight);
	coord = mod(coord + offset, vec2(size));
	coord /= noiseTextureResolution;

	return texture2D(noisetex, coord).xyz;
}

/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
	float specularity;			//How reflective a surface is
	float extraSpecularity;		//Additional reflectance for specular reflections from sun only
	float glossiness;			//How smooth or rough a specular surface is
	float metallic;				//from 0 - 1. 0 representing non-metallic, 1 representing fully metallic.
	float gain;					//Adjust specularity further
	float base;					//Reflectance when the camera is facing directly at the surface normal. 0 allows only the fresnel effect to add specularity
	float fresnelPower; 		//Curve of fresnel effect. Higher values mean the surface has to be viewed at more extreme angles to see reflectance
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

	float sky;
	float land;
	float grass;
	float leaves;
	float ice;
	float hand;
	float translucent;
	float glow;
	float sunspot;
	float goldBlock;
	float ironBlock;
	float diamondBlock;
	float emeraldBlock;
	float sand;
	float sandstone;
	float stone;
	float cobblestone;
	float wool;
	float clouds;

	float torch;
	float lava;
	float glowstone;
	float fire;

	float water;

	float volumeCloud;

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
	vec4	screenSpacePosition1;	//Vector representing the screen-space position of the surface
	vec4	screenSpacePositionSolid;	//Vector representing the screen-space position of the surface
	vec3 	viewVector; 			//Vector representing the viewing direction
	vec3 	lightVector; 			//Vector representing sunlight direction
	Ray 	viewRay;
	vec3 	worldLightVector;
	vec3  	upVector;				//Vector representing "up" direction
	float 	NdotL; 					//dot(normal, lightVector). used for direct lighting calculation

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

/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//Mask
void 	CalculateMasks(inout MaskStruct mask) {
		if (isEyeInWater > 0) {
			mask.sky = 0.0f;
		} else {
			mask.sky 			= GetMaterialMask(texcoord.st, 0, mask.matIDs);
		}

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

		mask.volumeCloud 	= 0.0f;
}

//Surface
void 	CalculateNdotL(inout SurfaceStruct surface) {		//Calculates direct sunlight without visibility check
	float direct = dot(surface.normal.rgb, surface.lightVector);
	direct = direct * 1.0f + 0.0f;

	surface.NdotL = direct;
}

float 	CalculateDirectLighting(in SurfaceStruct surface) {
	//Tall grass translucent shading
	if (surface.mask.grass > 0.5f) {

		#ifdef NO_LEAVE_GRASS_LIGHTING
			if (surface.NdotL > -0.01f) {
		 		return surface.NdotL * 0.99f + 0.01f;
		 	} else {
		 		return abs(surface.NdotL) * 0.25f;
		 	}
		#endif
		return 1.0f;

	//Leaves
	} else if(surface.mask.leaves > 0.5f) {

		#ifdef NO_LEAVE_GRASS_LIGHTING
			if (surface.NdotL > -0.01f) {
		 		return surface.NdotL * 0.99f + 0.01f;
		 	} else {
		 		return abs(surface.NdotL) * 0.25f;
		 	}
		#endif
	return 1.0f;

	//clouds
	} else if(surface.mask.clouds > 0.5f) {
		return 0.5f;
	} else if (surface.mask.ice > 0.5f) {
		return pow(surface.NdotL * 0.5 + 0.5, 2.0f);
	//Default lambert shading
	} else {
		return max(0.0f, surface.NdotL * 0.99f + 0.01f);
	}
}


//Optifine temp fix, this does nothing except trick optifine into thinking these are doing something
#ifdef ENABLE_SOFT_SHADOWS
float doNothing;
#endif

#ifdef VARIABLE_PENUMBRA_SHADOWS
float doNothing1;
#endif

float CalculateSunlightVisibility(inout SurfaceStruct surface, in ShadingStruct shadingStruct) {                              //Calculates shadows
	if (rainStrength > 0.99f)
		return 1.0f;

	float waterFix = 1.0;
	if(isEyeInWater > 0.5)
		waterFix = 60 / 70;

	if (shadingStruct.direct > 0.0f) {
		float distance = length(surface.screenSpacePosition.xyz);

		vec4 worldposition = vec4(0.0f);
    worldposition = gbufferModelViewInverse * surface.screenSpacePosition;         //Transform from screen space to world space

		float yDistanceSquared  = worldposition.y * worldposition.y;

    worldposition = shadowModelView * worldposition;        //Transform from world space to shadow space
	  float comparedepth = -worldposition.z;                          //Surface distance from sun to be compared to the shadow map

    worldposition = shadowProjection * worldposition;
    worldposition /= worldposition.w;

		float dist = sqrt(dot(worldposition.xy, worldposition.xy));
		vec2 pos = abs(worldposition.xy * 1.165);
		dist = pow(pow(pos.x, 8) + pow(pos.y, 8), 1.0 / 8.0);
    float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
    worldposition.xy *= 1.0f / distortFactor;
    worldposition.z /= 4.0;
    worldposition = worldposition * 0.5f + 0.5f;            //Transform from shadow space to shadow map coordinates

    float shadowMult = 0.0f;                                                                                                                                                        //Multiplier used to fade out shadows at distance
    float shading = 0.0f;

    float fademult = 0.15f;
    shadowMult = clamp((shadowDistance * 0.85f * fademult) - (distance * fademult), 0.0f, 1.0f);    //Calculate shadowMult to fade shadows out

    float diffthresh = dist * 1.0f + 0.10f;
    diffthresh *= 3.0f / (shadowMapResolution / 2048.0f);

		#if defined ENABLE_SOFT_SHADOWS
			float numBlockers = 0.0;
			float numSamples = 0.0;

			int PCFSizeHalf = 3;

			float penumbraSize = 0.5;

			#ifdef USE_RANDOM_ROTATION
				float rotateAmount = texture2D(noisetex, texcoord.st * vec2(viewWidth / noiseTextureResolution, viewHeight / noiseTextureResolution)).r * 2.0f - 1.0f;
        mat2 kernelRotation = mat2(cos(rotateAmount), -sin(rotateAmount), sin(rotateAmount), cos(rotateAmount));
			#endif

			for( int i = -PCFSizeHalf; i <= PCFSizeHalf; i++ ) {
				for( int j = -PCFSizeHalf; j <= PCFSizeHalf; j++ ) {
					vec2 sampleCoord = vec2( j, i ) / shadowMapResolution;
          sampleCoord *= penumbraSize;

          #ifdef USE_RANDOM_ROTATION
            sampleCoord = kernelRotation * sampleCoord;
          #endif

					float shadowDepth = shadow2DLod(shadow, vec3(worldposition.st + sampleCoord, worldposition.z - 0.0006f * diffthresh), 0).r;
					numBlockers +=  step(worldposition.z - shadowDepth, 0.0006f);
					numSamples++;
				}
			}

			shading = ( numBlockers / numSamples);

			#elif defined VARIABLE_PENUMBRA_SHADOWS
				float vpsSpread = 0.5 / distortFactor;

				float avgDepth = 0.0;
				float minDepth = 11.0;
				int c;

				for (int i = -1; i <= 1; i++) {
					for (int j = -1; j <= 1; j++) {
						vec2 lookupCoord = worldposition.xy + (vec2(i, j) / shadowMapResolution) * 8.0 * vpsSpread;

						float depthSample = texture2DLod(shadowtex1, lookupCoord, 3).x;
						minDepth = min(minDepth, texture2DLod(shadowtex1, lookupCoord, 3).x);
						avgDepth += pow(min(max(0.0, worldposition.z - depthSample) * 1.0, 0.15), 1.6);
						c++;
					}
				}

				avgDepth /= c;
				avgDepth = pow(avgDepth, 1.0 / 2.0);

				float penumbraSize = avgDepth;

				int count = 0;
				float spread = penumbraSize * 0.0062 * vpsSpread + 0.085 / shadowMapResolution;
				spread = min(0.2, spread);

				vec3 noise = CalculateNoisePattern1(vec2(0.0), 64.0);

				diffthresh *= 1.0 + avgDepth * 40.0;

				for (float i = -2.0f; i <= 2.0f; i += 1.0f) {
					for (float j = -2.0f; j <= 2.0f; j += 1.0f) {
						float angle = noise.x * 3.14159 * 2.0;

						mat2 rot = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));

						vec2 coord = vec2(i, j) * rot;

						shading += shadow2D(shadow, vec3(worldposition.st + coord * spread, worldposition.z - 0.0003f * diffthresh)).x;
						count += 1;
					}
				}

				shading /= count;

			#else
				shading = shadow2DLod(shadow, vec3(worldposition.st, worldposition.z - 0.0006f * diffthresh), 0).x;
			#endif


		shading = mix(1.0f, shading, 1.0) * pow(1-rainStrength, 2.0f);
		shading = min(shading, transition_fading);

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

float CalculateSkylight(in SurfaceStruct surface) {
	if (surface.mask.clouds > 0.5f) {
		return 1.0f;
	} else if (surface.mask.grass > 0.5f) {
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
	vec3 lightVector = normalize(lightPos - surface.screenSpacePosition1.xyz);
	float lightDist = length(lightPos.xyz - surface.screenSpacePosition1.xyz);

	float atten = 1.0f / (pow(lightDist, 2.0f) + 0.001f);
	float NdotL = 1.0f;

	return atten * NdotL;
}

float CalculateSunglow(in SurfaceStruct surface) {
	float curve = 4.0f;

	vec3 npos = normalize(surface.screenSpacePosition1.xyz);
	vec3 halfVector2 = normalize(-surface.lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

float CalculateAntiSunglow(in SurfaceStruct surface) {
	float curve = 4.0f;

	vec3 npos = normalize(surface.screenSpacePosition1.xyz);
	vec3 halfVector2 = normalize(surface.lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

bool CalculateSunspot(in SurfaceStruct surface) {
	//circular sun
	float curve = 1.0f;

	vec3 npos = normalize(surface.screenSpacePosition1.xyz);
	vec3 halfVector2 = normalize(-surface.lightVector + npos);

	float sunProximity = 1.0f - dot(halfVector2, npos);

	if (sunProximity > 0.96f && sunAngle > 0.0f && sunAngle < 0.5f) {
		return true;
	} else {
		return false;
	}
}



void 	AddSkyGradient(inout SurfaceStruct surface) {
	float curve = 3.5f;
	vec3 npos = normalize(surface.screenSpacePosition1.xyz);
	vec3 halfVector2 = normalize(-surface.upVector + npos);
	float skyGradientFactor = dot(halfVector2, npos);
	float skyDirectionGradient = skyGradientFactor;

	skyGradientFactor = pow(skyGradientFactor, curve);
	surface.sky.albedo *= mix(skyGradientFactor, 1.0f, clamp((0.145f - (timeNoon * 0.1f)) + rainStrength, 0.0f, 1.0f));

	vec3 skyBlueColor = vec3(0.25f, 0.4f, 1.0f) * 2.5f;
	skyBlueColor.g *= skyGradientFactor * 0.5f + 0.75f;
	skyBlueColor = mix(skyBlueColor, vec3(1.0f, 0.9f, 0.5f), vec3(timeSkyDark));
	skyBlueColor *= mix(vec3(1.0f), vec3(1.0f, 1.0f, 0.5f), vec3(timeSunriseSunset));

	float fade1 = clamp(skyGradientFactor - 0.15f, 0.0f, 0.2f) / 0.2f;
	vec3 color1 = vec3(1.0f, 1.3, 1.0f);

	surface.sky.albedo *= mix(skyBlueColor, color1, vec3(fade1));

	float fade2 = clamp(skyGradientFactor - 0.18f, 0.0f, 0.2f) / 0.2f;
	vec3 color2 = vec3(1.7f, 1.0f, 0.8f);
	color2 = mix(color2, vec3(1.0f, 0.15f, 0.0f), vec3(timeSunriseSunset));

	surface.sky.albedo *= mix(vec3(1.0f), color2, vec3(fade2 * 0.5f));

	float horizonGradient = 1.0f - distance(skyDirectionGradient, 0.72f) / 0.72f;
	horizonGradient = pow(horizonGradient, 10.0f);
	horizonGradient = max(0.0f, horizonGradient);

	float sunglow = CalculateSunglow(surface);
	//horizonGradient *= sunglow * 2.0f + (0.65f - timeSunriseSunset * 0.55f - timeSunriseSunset * 0.55f);

	vec3 horizonColor1 = vec3(1.5f, 1.5f, 1.5f);
	horizonColor1 = mix(horizonColor1, vec3(1.5f, 1.95f, 1.5f) * 2.0f, vec3(timeSunriseSunset));
	vec3 horizonColor2 = vec3(1.5f, 1.2f, 0.8f) * 1.0f;
	horizonColor2 = mix(horizonColor2, vec3(1.9f, 0.6f, 0.4f) * 2.0f, vec3(timeSunriseSunset));

	surface.sky.albedo *= mix(vec3(1.0f), horizonColor1, vec3(horizonGradient) * (1.0f - timeMidnight));
	surface.sky.albedo *= mix(vec3(1.0f), horizonColor2, vec3(pow(horizonGradient, 2.0f)) * (1.0f - timeMidnight));

	float grayscale = surface.sky.albedo.r + surface.sky.albedo.g + surface.sky.albedo.b;
	grayscale /= 3.0f;

	surface.sky.albedo = mix(surface.sky.albedo, vec3(grayscale) * 1.4f, vec3(rainStrength));
}

void AddSunglow(inout SurfaceStruct surface) {
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

	color.rgb *= 1.0f + glow * mult * (surface.mask.clouds);
}


void 	CalculateUnderwaterFog(in SurfaceStruct surface, inout vec3 finalComposite) {
	vec3 fogColor = colorWaterMurk * vec3(colorSkylight);

	float fogFactor = GetDepthLinear(texcoord.st) / 100.0f;
	fogFactor = min(fogFactor, 0.7f);
	fogFactor = sin(fogFactor * 3.1415 * 0.5f);
	fogFactor = pow(fogFactor, 0.5f);


	finalComposite.rgb = mix(finalComposite.rgb, fogColor * 0.002f, vec3(fogFactor));
	finalComposite.rgb *= mix(vec3(1.0f), colorWaterBlue * colorWaterBlue * colorWaterBlue * colorWaterBlue, vec3(fogFactor));
}

void InitializeAO(inout SurfaceStruct surface) {
	surface.ao.skylight = 1.0f;
	surface.ao.bouncedSunlight = 1.0f;
	surface.ao.scatteredUpLight = 1.0f;
	surface.ao.constant = 1.0f;
}


void 	CalculateRainFog(inout vec3 color, in SurfaceStruct surface) {
	vec3 fogColor = colorSkylight * 0.055f;

	float fogDensity = 0.0018f * rainStrength;
	fogDensity *= mix(0.0f, 1.0f, pow(eyeBrightnessSmooth.y / 240.0f, 6.0f));
	float visibility = 1.0f / (pow(exp(distance(surface.screenSpacePosition1.xyz, vec3(0.0f)) * fogDensity), 1.0f));

	float fogFactor = 1.0f - visibility;
	fogFactor = clamp(fogFactor, 0.0f, 1.0f);
	fogFactor = mix(fogFactor, 1.0f, float(surface.mask.sky) * 0.8f * rainStrength);
	fogFactor = mix(fogFactor, 1.0f, float(surface.mask.clouds) * 0.8f * rainStrength);

	color = mix(color, fogColor, vec3(fogFactor));
}

void 	CalculateAtmosphericScattering(inout vec3 color, in SurfaceStruct surface) {
	vec3 fogColor = colorSkylight * 0.11f;

	float sat = 0.5f;
	fogColor.r = fogColor.r * (0.0f + sat) - (fogColor.g + fogColor.b) * 0.0f * sat;
	fogColor.g = fogColor.g * (0.0f + sat) - (fogColor.r + fogColor.b) * 0.0f * sat;
	fogColor.b = fogColor.b * (0.0f + sat) - (fogColor.r + fogColor.g) * 0.0f * sat;

	float sunglow = CalculateSunglow(surface);
	vec3 sunColor = colorSunlight;

	fogColor += mix(vec3(0.0f), sunColor, sunglow * 0.8f);

	float fogDensity = 0.01f;

	#ifdef MORNING_FOG
		fogDensity += 0.04f * timeSunriseSunset * 0.25;
	#endif

	#ifdef 	EVENING_FOG
		fogDensity += 0.04f * timeSunriseSunset * 0.25;
	#endif

	float visibility = 1.26f / (pow(exp(surface.linearDepth * fogDensity), 1.0f));

	float fogFactor = 1.0f - visibility;
	fogFactor = clamp(fogFactor, 0.0f, 1.0f);
	fogFactor = pow(fogFactor, 2.7f);
	fogFactor = mix(fogFactor, 0.0f, min(1.0f, surface.sky.sunSpot.r));
	fogFactor *= mix(1.0f, 0.25f, float(surface.mask.sky));
	fogFactor *= mix(1.0f, 0.75f, float(surface.mask.clouds));

	#ifdef NO_ATMOSPHERIC_FOG_INSIDE
		fogFactor *= mix(0.0f, 1.0f, pow(eyeBrightnessSmooth.y / 240.0f, 3.0f));
	#endif

	float redshift = 1.20f;

	//scatter away high frequency light
	color.b *= 1.0f - clamp(fogFactor * 1.65 * redshift, 0.0f, 0.75f);
	color.g *= 1.0f - fogFactor * 0.2* redshift;
	color.g *= 1.0f - clamp(fogFactor - 0.26f, 0.0f, 1.0f) * 0.5* redshift;

	//add scattered low frequency light
	color += fogColor * fogFactor * 1.0f;
}


Intersection RayPlaneIntersectionWorld(in Ray ray, in Plane plane) {
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

Intersection RayPlaneIntersection(in Ray ray, in Plane plane) {
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


float GetCoverage(in float coverage, in float density, in float clouds) {
	clouds = clamp(clouds - (1.0f - coverage), 0.0f, 1.0f -density) / (1.0f - density);
	clouds = max(0.0f, clouds * 1.1f - 0.1f);

	return clouds;
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

		vec4 worldPosition = gbufferModelViewInverse * surface.screenSpacePosition1;
		worldPosition.xyz += cameraPosition.xyz;

		float cloudHeight = 150.0f;
		float cloudDepth  = 60.0f;
		float cloudDensity = 2.25f;

		float startingRayDepth = far - 5.0f;

		float rayDepth = startingRayDepth;
		float rayIncrement = far / CLOUD_DISPERSE;

		#ifdef SOFT_FLUFFY_CLOUDS
			rayDepth += CalculateDitherPattern1() * rayIncrement;
		#else
			rayDepth += CalculateDitherPattern2() * rayIncrement;
		#endif

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

			if (surfaceDistance < rayDistance * cloudDistanceMult  && surface.mask.sky == 0.0)
			proximity.a = 0.0f;

			color.rgb = mix(color.rgb, proximity.rgb, vec3(min(1.0f, proximity.a * cloudDensity)));

			surface.cloudAlpha += proximity.a;

			//Increment ray
			rayDepth -= rayIncrement;
			i++;
		}
}

vec4 CloudColors(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector) {
	float cloudHeight = Cloud3Height;
	float cloudDepth  = 150.0f;
	float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
	float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

	if (worldPosition.y < cloudLowerHeight || worldPosition.y > cloudUpperHeight) {
		return vec4(0.0f);
	} else {
		vec3 p = worldPosition.xyz / 150.0f;
		float t = frameTimeCounter / 2.0f;
		p.x -= t * 0.02f;
		p += (Get3DNoise(p * 1.0f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.3f;

		vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
		float noise  = 	Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));	p *= 2.0f;	p.x -= t * 0.097f;	vec3 p2 = p;
		noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.20f;				p *= 3.0f;	p.xz -= t * 0.05f;	vec3 p3 = p;
		noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.075f;				p *= 2.0f;	p.xz -= t * 0.05f;
		noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.05f;				p *= 2.0f;
		noise /= 1.2f;

		const float lightOffset = 0.33f;

		float cloudAltitudeWeight = 1.0f - clamp(distance(worldPosition.y, cloudHeight) / (cloudDepth / 2.0f), 0.0f, 1.0f);
		cloudAltitudeWeight = pow(cloudAltitudeWeight, 0.5f);

		noise *= cloudAltitudeWeight;

		//cloud edge
		float rainy = mix(wetness, 1.0f, rainStrength);
		float coverage = Vol_Cloud_Coverage + rainy * 0.335f;
		coverage = mix(coverage, 0.77f, rainStrength);
		float density = 0.66f;
		noise = clamp(noise - (1.0f - coverage), 0.0f, 1.0f - density) / (1.0f - density);

		float directLightFalloff = clamp(pow(-(cloudLowerHeight - worldPosition.y) / cloudDepth, 3.5f), 0.0f, 1.0f);
		directLightFalloff *= mix(	clamp(pow(noise, 0.9f), 0.0f, 1.0f), 	clamp(pow(1.0f - noise, 10.3f), 0.0f, 0.5f), 	pow(sunglow, 0.2f));

		vec3 colorDirect = colorSunlight * 25.0f;
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

void 	CalculateClouds2 (inout vec3 color, inout SurfaceStruct surface) {
	surface.cloudAlpha = 0.0f;

	vec2 coord = texcoord.st * 2.0f;

	vec4 worldPosition = gbufferModelViewInverse * surface.screenSpacePosition1;
	worldPosition.xyz += cameraPosition.xyz;

	float cloudHeight = 150.0f;
	float cloudDepth  = 60.0f;
	float cloudDensity = 2.25f;

	float startingRayDepth = far - 5.0f;

	float rayDepth = startingRayDepth;

	float rayIncrement = far / CLOUD_DISPERSE;

	#ifdef SOFT_FLUFFY_CLOUDS
		rayDepth += CalculateDitherPattern1() * rayIncrement;
	#else
		rayDepth += CalculateDitherPattern2() * rayIncrement;
	#endif

	int i = 0;

	vec3 cloudColors = colorSunlight;
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

		vec4 proximity =  CloudColors(rayPosition, sunglow, surface.worldLightVector);
		proximity.a *= cloudDensity;

		if(surfaceDistance < rayDistance * cloudDistanceMult  && surface.mask.sky == 0.0)
			proximity.a = 0.0f;

		color.rgb = mix(color.rgb, proximity.rgb, vec3(min(1.0f, proximity.a * cloudDensity)));
		surface.cloudAlpha += proximity.a;

		//Increment ray
		rayDepth -= rayIncrement;
		i++;
	}
}

float Get3DNoise3(in vec3 pos) {
	pos.z += 0.0f;
	pos.xyz += 0.5f;

	vec3 p = floor(pos);
	vec3 f = fract(pos);

	f.x = f.x * f.x * (3.0f - 2.0f * f.x);
	f.y = f.y * f.y * (3.0f - 2.0f * f.y);
	f.z = f.z * f.z * (3.0f - 2.0f * f.z);

	vec2 uv =  (p.xy + p.z * vec2(17.0f)) + f.xy;
	vec2 uv2 = (p.xy + (p.z + 1.0f) * vec2(17.0f)) + f.xy;
	uv += 0.5f;
	uv2 += 0.5f;

	vec2 coord =  (uv  + 0.5f) / noiseTextureResolution;
	vec2 coord2 = (uv2 + 0.5f) / noiseTextureResolution;

	float xy1 = texture2D(noisetex, coord).x;
	float xy2 = texture2D(noisetex, coord2).x;

	return mix(xy1, xy2, f.z);
}

float GetCoverage2(in float coverage, in float density, in float clouds) {
	clouds = clamp(clouds - (1.0f - coverage), 0.0f, 1.0f -density) / (1.0f - density);
	clouds = max(0.0f, clouds * 1.1f - 0.1f);
	clouds = clouds = clouds * clouds * (3.0f - 2.0f * clouds);

	return clouds;
}

vec4 CloudColor3(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector) {
	float cloudHeight = Cloud3Height;

	#ifdef CLOUD3_TYPE
		float cloudDepth  = 150.0f;
	#else
		float cloudDepth  = 120.0f;
	#endif

	float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
	float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

	if (worldPosition.y < cloudLowerHeight || worldPosition.y > cloudUpperHeight) {
		return vec4(0.0f);
	} else {

	vec3 p = worldPosition.xyz / 150.0f;

	#ifdef CLOUD3_TYPE
		float t = frameTimeCounter / 2.0f ;
		p.x -= t * 0.02f;

		vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
		float noise  = 	Get3DNoise3(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));	p *= 2.0f;	p.x -= t * 0.097f;	vec3 p2 = p;
		noise += (1.0 - abs(Get3DNoise3(p) * 1.0f - 0.5f) - 0.1) * 0.55f;					p *= 2.5f;	p.xz -= t * 0.065f;	vec3 p3 = p;
		noise += (1.0 - abs(Get3DNoise3(p) * 3.0f - 1.5f) - 0.2) * 0.065f;  p *= 2.5f;	p.xz -= t * 0.165f;	vec3 p4 = p;
		noise += (1.0 - abs(Get3DNoise3(p) * 3.0f - 1.5f)) * 0.032f;						p *= 2.5f;	p.xz -= t * 0.165f;
		noise += (1.0f - abs(Get3DNoise(p) * 1.0f - 1.5f)) * 0.05f;	p *= 2.0f;												p *= 2.5f;
		noise /= 1.315f;

		const float lightOffset = 0.3f;

		float heightGradient = clamp(( - (cloudLowerHeight - worldPosition.y) / (cloudDepth * 1.0f)), 0.0f, 1.0f);
		float heightGradient2 = clamp(( - (cloudLowerHeight - (worldPosition.y + worldLightVector.y * lightOffset * 150.0f)) / (cloudDepth * 1.0f)), 0.0f, 1.0f);

		float cloudAltitudeWeight = 1.0f - clamp(distance(worldPosition.y, cloudHeight) / (cloudDepth / 2.0f), 0.0f, 1.0f);
		cloudAltitudeWeight = (-cos(cloudAltitudeWeight * 3.1415f)) * 0.5 + 0.5;
		cloudAltitudeWeight = pow(cloudAltitudeWeight, mix(0.33f, 0.8f, rainStrength));

		float cloudAltitudeWeight2 = 1.0f - clamp(distance(worldPosition.y + worldLightVector.y * lightOffset * 150.0f, cloudHeight) / (cloudDepth / 2.0f), 0.0f, 1.0f);
		cloudAltitudeWeight2 = (-cos(cloudAltitudeWeight2 * 3.1415f)) * 0.5 + 0.5;
		cloudAltitudeWeight2 = pow(cloudAltitudeWeight2, mix(0.33f, 0.8f, rainStrength));

		noise *= cloudAltitudeWeight;

		//cloud edge
		float rainy = mix(wetness, 1.0f, rainStrength);
		float coverage = 0.275 + rainy * 0.335;
		coverage = mix(coverage, 0.77f, rainStrength);

		float dist = length(worldPosition.xz - cameraPosition.xz);
		coverage *= max(0.0f, 1.0f - dist / 40000.0f);
		float density = 0.90f;
		noise = GetCoverage2(coverage, density, noise);
		noise = pow(noise, 1.5);
	#else
		float t = frameTimeCounter * 2 ;
		p.x -= t * 0.02f;

		vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
		float noise  = 			   Get3DNoise(p) 				 * 1.0f;	p *= 4.0f;	p.x += t * 0.02f; vec3 p2 = p;
		noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.20f;	p *= 3.0f;	p.xz += t * 0.05f;
		noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.5f)-0.2) * 0.065f;	p.xz -=t * 0.165f;	p.xz += t * 0.05f;
		noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.05f;	p *= 2.0f;
		noise += (1.0 - abs(Get3DNoise3(p) * 2.0 - 1.0)) * 0.015f;
		noise /= 1.2f;

		const float lightOffset = 0.3f;

		float heightGradient = clamp(( - (cloudLowerHeight - worldPosition.y) / (cloudDepth * 1.0f)), 0.0f, 1.0f);
		float heightGradient2 = clamp(( - (cloudLowerHeight - (worldPosition.y + worldLightVector.y * lightOffset * 150.0f)) / (cloudDepth * 1.0f)), 0.0f, 1.0f);

		float cloudAltitudeWeight = 1.0f - clamp(distance(worldPosition.y, cloudHeight) / (cloudDepth / 2.0f), 0.0f, 1.0f);
		cloudAltitudeWeight = (-cos(cloudAltitudeWeight * 3.1415f)) * 0.5 + 0.5;
		cloudAltitudeWeight = pow(cloudAltitudeWeight, mix(0.33f, 0.8f, rainStrength));

		float cloudAltitudeWeight2 = 1.0f - clamp(distance(worldPosition.y + worldLightVector.y * lightOffset * 150.0f, cloudHeight) / (cloudDepth / 2.0f), 0.0f, 1.0f);
		cloudAltitudeWeight2 = (-cos(cloudAltitudeWeight2 * 3.1415f)) * 0.5 + 0.5;
		cloudAltitudeWeight2 = pow(cloudAltitudeWeight2, mix(0.33f, 0.8f, rainStrength));

		noise *= cloudAltitudeWeight;

		//cloud edge
		float rainy = mix(wetness, 1.0f, rainStrength);
		float coverage = 0.48f + rainy * 0.335;
		coverage = mix(coverage, 0.77f, rainStrength);

		float dist = length(worldPosition.xz - cameraPosition.xz);
		coverage *= max(0.0f, 1.0f - dist / 40000.0f);
		float density = 0.90f;
		noise = GetCoverage2(coverage, density, noise);
		noise = pow(noise, 1.5);
	#endif

	if(noise <= 0.001f) {
		return vec4(0.0f, 0.0f, 0.0f, 0.0f);
	}


	float sundiff = Get3DNoise3(p1 + worldLightVector.xyz * lightOffset);
	sundiff += (1.0 - abs(Get3DNoise3(p2 + worldLightVector.xyz * lightOffset / 2.0f) * 1.0f - 0.5f) - 0.1) * 0.55f;
	sundiff *= 0.955f;
	sundiff *= cloudAltitudeWeight2;

	float preCoverage = sundiff;
	sundiff = -GetCoverage2(coverage * 1.0f, density * 0.5, sundiff);
	float sundiff2 = -GetCoverage2(coverage * 1.0f, 0.0, preCoverage);
	float firstOrder 	= pow(clamp(sundiff * 1.2f + 1.7f, 0.0f, 1.0f), 8.0f);
	float secondOrder 	= pow(clamp(sundiff2 * 1.2f + 1.1f, 0.0f, 1.0f), 4.0f);

	float anisoBackFactor = mix(clamp(pow(noise, 1.6f) * 2.5f, 0.0f, 1.0f), 1.0f, pow(sunglow, 1.0f));
	firstOrder *= anisoBackFactor * 0.99 + 0.01;
	secondOrder *= anisoBackFactor * 1.19 + 0.9;

	float directLightFalloff = clamp(pow(-(cloudLowerHeight - worldPosition.y) / cloudDepth, 3.5f), 0.0f, 1.0f);
	directLightFalloff *= mix(	clamp(pow(noise, 0.9f), 0.0f, 1.0f), 	clamp(pow(1.0f - noise, 10.3f), 0.0f, 0.5f), 	pow(sunglow, 0.2f));

	vec3 colorDirect = colorSunlight * 12.5f;
	colorDirect = mix(colorDirect, colorDirect * vec3(0.1f, 0.2f, 0.3f), timeMidnight);
	colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.2f, 0.2f), rainStrength);
	colorDirect *= 1.0f + pow(sunglow, 4.0f) * 100.0f;

	vec3 colorAmbient = mix(colorSkylight, colorSunlight, 0.15f) * 0.065f;
	colorAmbient *= mix(1.0f, 0.3f, timeMidnight);

	vec3 colorBounced = colorBouncedSunlight * 0.35f;
	colorBounced *= pow((1.0f - heightGradient), 8.0f);
	colorBounced *= anisoBackFactor + 0.5;
	colorBounced *= 1.0 - rainStrength;

	vec3 color = mix(colorAmbient, colorDirect, vec3(directLightFalloff));
	color *= 1.0f;

	vec4 result = vec4(color.rgb, noise);
	return result;
	}
}

void 	CalculateClouds3 (inout vec3 color, inout SurfaceStruct surface) {
	surface.cloudAlpha = 0.0f;

	vec2 coord = texcoord.st * 2.0f;

	vec4 worldPosition = gbufferModelViewInverse * surface.screenSpacePosition1;
	worldPosition.xyz += cameraPosition.xyz;

	float cloudHeight = 150.0f;
	float cloudDepth  = 140.0f;
	float cloudDensity = 1.0f;

	float startingRayDepth = far - 5.0f;

	float rayDepth = startingRayDepth;
	float rayIncrement = far / CLOUD_DISPERSE;

	#ifdef SOFT_FLUFFY_CLOUDS
		rayDepth += CalculateDitherPattern1() * rayIncrement;
	#else
		rayDepth += CalculateDitherPattern2() * rayIncrement;
	#endif

	int i = 0;

	vec3 cloudColor3 = colorSunlight;
	vec4 cloudSum = vec4(0.0f);
	cloudSum.rgb = color.rgb;

	float sunglow = CalculateSunglow(surface);

	float cloudDistanceMult = 400.0f / far;

	float surfaceDistance = length(worldPosition.xyz - cameraPosition.xyz);

	while (rayDepth > 0.0f) {
		//determine worldspace ray position
		vec4 rayPosition = GetCloudSpacePosition(texcoord.st, rayDepth, cloudDistanceMult);

		float rayDistance = length((rayPosition.xyz - cameraPosition.xyz) / cloudDistanceMult);

		vec4 proximity =  CloudColor3(rayPosition, sunglow, surface.worldLightVector);
		proximity.a *= cloudDensity;

		if(surfaceDistance < rayDistance * cloudDistanceMult  && surface.mask.sky == 0.0)
			proximity.a = 0.0f;

		cloudSum.rgb = mix( cloudSum.rgb, proximity.rgb, vec3(min(1.0f, proximity.a * cloudDensity)) );
		cloudSum.a += proximity.a * cloudDensity;

		surface.cloudAlpha += proximity.a;

		//Increment ray
		rayDepth -= rayIncrement;
		i++;
	}

	color.rgb = mix(color.rgb, cloudSum.rgb, vec3(min(1.0f, cloudSum.a * 50.0f)));

	if (cloudSum.a > 0.00f) {
		surface.mask.volumeCloud = 1.0;
	}
}

vec4 CloudColor(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector, in float altitude, in float thickness) {
	float cloudHeight = altitude;
	float cloudDepth  = thickness;
	float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
	float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

	worldPosition.xz /= 1.0f + max(0.0f, length(worldPosition.xz - cameraPosition.xz) / 3000.0f);

	vec3 p = worldPosition.xyz / 300.0f;

	float t = frameTimeCounter * 1.0f;
	p.x -= t * 0.01f;
	p += (Get3DNoise(p * 1.0f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.3f;

	vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
	float noise  = 	Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));	p *= 2.0f;	p.x -= t * 0.057f;	vec3 p2 = p;
	noise += (1.0f - abs(Get3DNoise(p) * 1.0f - 0.5f)) * 0.15f;						p *= 3.0f;	p.xz -= t * 0.035f;	vec3 p3 = p;
	noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * 0.045f;						p *= 3.0f;	p.xz -= t * 0.035f;	vec3 p4 = p;
	noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * 0.015f;						p *= 3.0f;	p.xz -= t * 0.035f;
	noise += ((Get3DNoise(p))) * 0.015f;												p *= 3.0f;
	noise += ((Get3DNoise(p))) * 0.006f;
	noise /= 1.175f;

	const float lightOffset = 0.2f;

	float heightGradient = clamp(( - (cloudLowerHeight - worldPosition.y) / (cloudDepth * 1.0f)), 0.0f, 1.0f);
	float heightGradient2 = clamp(( - (cloudLowerHeight - (worldPosition.y + worldLightVector.y * lightOffset * 50.0f)) / (cloudDepth * 1.0f)), 0.0f, 1.0f);

	float cloudAltitudeWeight = 1.0f;

	float cloudAltitudeWeight2 = 1.0f;

	noise *= cloudAltitudeWeight;

	//cloud edge
	float coverage = 0.39f;
	coverage = mix(coverage, 0.77f, rainStrength);

	float dist = length(worldPosition.xz - cameraPosition.xz);
	coverage *= max(0.0f, 1.0f - dist / 40000.0f);
	float density = 0.8f;
	noise = GetCoverage(coverage, density, noise);

	float sundiff = Get3DNoise(p1 + worldLightVector.xyz * lightOffset);
	sundiff += Get3DNoise(p2 + worldLightVector.xyz * lightOffset / 2.0f) * 0.15f;

	float largeSundiff = sundiff;
	largeSundiff = -GetCoverage(coverage, 0.0f, largeSundiff * 1.3f);

	sundiff += Get3DNoise(p3 + worldLightVector.xyz * lightOffset / 5.0f) * 0.045f;
	sundiff += Get3DNoise(p4 + worldLightVector.xyz * lightOffset / 8.0f) * 0.015f;
	sundiff *= 1.3f;
	sundiff *= cloudAltitudeWeight2;
	sundiff = -GetCoverage(coverage * 1.0f, 0.0f, sundiff);

	float firstOrder 	= pow(clamp(sundiff * 1.0f + 1.1f, 0.0f, 1.0f), 12.0f);
	float secondOrder 	= pow(clamp(largeSundiff * 1.0f + 0.9f, 0.0f, 1.0f), 3.0f);

	float directLightFalloff = mix(firstOrder, secondOrder, 0.1f);
	float anisoBackFactor = mix(clamp(pow(noise, 1.6f) * 2.5f, 0.0f, 1.0f), 1.0f, pow(sunglow, 1.0f));

	directLightFalloff *= anisoBackFactor;
	directLightFalloff *= mix(11.5f, 1.0f, pow(sunglow, 0.5f));

	vec3 colorDirect = colorSunlight * 0.815f;
	colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.5f, 1.0f), timeMidnight);
	colorDirect *= 1.0f + pow(sunglow, 2.0f) * 300.0f * pow(directLightFalloff, 1.1f) * (1.0f - rainStrength);

	vec3 colorAmbient = mix(colorSkylight, colorSunlight * 2.0f, vec3(heightGradient * 0.0f + 0.15f)) * 0.36f;
	colorAmbient *= mix(1.0f, 0.3f, timeMidnight);
	colorAmbient = mix(colorAmbient, colorAmbient * 3.0f + colorSunlight * 0.05f, vec3(clamp(pow(1.0f - noise, 12.0f) * 1.0f, 0.0f, 1.0f)));
	colorAmbient *= heightGradient * heightGradient + 0.1f;

	vec3 colorBounced = colorBouncedSunlight * 0.1f;
	colorBounced *= pow((1.0f - heightGradient), 8.0f);

	vec3 color = mix(colorAmbient, colorDirect, vec3(min(1.0f, directLightFalloff)));

	vec4 result = vec4(color.rgb, noise);
	return result;
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
	p.xz -= (Get3DNoise(p * 0.0525f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 1.7f;
	p.x *= 0.25f;
	p.x -= t * 0.003f;

	vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
	float noise  = 	Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));	p *= 2.0f;	p.x -= t * 0.017f;	p.z += noise * 1.35f;	p.x += noise * 0.5f; vec3 p2 = p;
	noise += (2.0f - abs(Get3DNoise(p) * 2.0f - 0.0f)) * (0.25f);	p *= 3.0f;	p.xz -= t * 0.005f;	p.z += noise * 1.35f;	p.x += noise * 0.5f; 	p.x *= 3.0f;	p.z *= 0.55f;	vec3 p3 = p;

	p.z -= (Get3DNoise(p * 0.25f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.4f;
	noise += (3.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * (0.035f); p *= 3.0f;	p.xz -= t * 0.005f;	vec3 p4 = p;
	noise += (3.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * (0.025f); p *= 3.0f;	p.xz -= t * 0.005f;

	if(!isShadowPass) {
		noise += ((Get3DNoise(p))) * (0.022f); p *= 3.0f;
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

		if(i.angle < 0.0f) {
			if(i.distance < surface.linearDepth || surface.mask.sky > 0.0f) {
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
	vec4 surfacePos = gbufferModelViewInverse * surface.screenSpacePosition1;
	surfaceToSun.origin = surfacePos.xyz + cameraPosition.xyz;

	Intersection i = RayPlaneIntersection(surfaceToSun, pl);

	float cloudShadow = CloudColor2(vec4(i.pos.xyz * 0.5f + vec3(30.0f), 1.0f), 0.0f, vec3(1.0f), cloudsAltitude, cloudsThickness, true).x;
	cloudShadow += CloudColor2(vec4(i.pos.xyz * 0.65f + vec3(10.0f) + vec3(i.pos.z * 0.5f, 0.0f, 0.0f), 1.0f), 0.0f, vec3(1.0f), cloudsAltitude, cloudsThickness, true).x;

	cloudShadow = min(cloudShadow, 0.95f);
	cloudShadow = 1.0f - cloudShadow;

	return cloudShadow;
}

vec4 BilateralUpsample(const in float scale, in vec2 offset, in float depth, in vec3 normal) {
	vec2 recipres = vec2(1.0f / viewWidth, 1.0f / viewHeight);

	vec4 light = vec4(0.0f);
	float weights = 0.0f;

	float gi_quality = GI_FILTER_QUALITY;

	for (float i = -gi_quality; i <= gi_quality; i += 1.0f) {
		for (float j = -gi_quality; j <= gi_quality; j += 1.0f) {
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

	if (weights < 0.01f) {
		light =	pow(texture2DLod(gaux1, (texcoord.st) * (1.0f / exp2(scale 	)) + 	offset, 2), vec4(2.2f, 2.2f, 2.2f, 1.0f));
	}

	return light;
}

vec4 Delta(vec3 albedo, vec3 normal, float skylight) {
	float depth = GetDepthLinear(texcoord.st);
	vec4 delta = BilateralUpsample(1.0f, vec2(0.0f, 0.0f), 		depth, normal);

	delta.rgb = delta.rgb * albedo * colorSunlight;

	delta.rgb *= 5.0f * delta.a * delta.a * (1.0 - rainStrength) * pow(skylight, 0.5);

	return delta;
}

float CrepuscularRays(in SurfaceStruct surface) {
	float rayDepth = 0.02f;
	float increment = 4.0f;

	const float rayLimit = 30.0f;
	float dither = CalculateDitherPattern2();

	float lightAccumulation = 0.0f;
	float ambientFogAccumulation = 0.0f;

	float numSteps = rayLimit / increment;

	int count = 0;

	while (rayDepth < rayLimit) {
		if(surface.linearDepth < rayDepth + dither * increment) {
			break;
		}

		vec4 rayPosition = GetScreenSpacePosition(texcoord.st, LinearToExponentialDepth(rayDepth + dither * increment));
		rayPosition = gbufferModelViewInverse * rayPosition;

		rayPosition = shadowModelView * rayPosition;
		rayPosition = shadowProjection * rayPosition;
		rayPosition /= rayPosition.w;

		float dist = sqrt(dot(rayPosition.xy, rayPosition.xy));
		vec2 pos = abs(rayPosition.xy * 1.165);
		dist = pow(pow(pos.x, 8) + pow(pos.y, 8), 1.0 / 8.0);
    float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
    rayPosition.xy *= 1.0f / distortFactor;
    rayPosition.z /= 4.0;
    rayPosition = rayPosition * 0.5f + 0.5f;            //Transform from shadow space to shadow map coordinates

		float shadowSample = shadow2DLod(shadow, vec3(rayPosition.st, rayPosition.z + 0.0005f), 2).x;

		lightAccumulation += shadowSample * increment;

		ambientFogAccumulation *= 1.0f;

		rayDepth += increment;
		count++;
		increment *= 1.5;
	}

	lightAccumulation /= numSteps;
	ambientFogAccumulation /= numSteps;

	float rays = lightAccumulation;
	float depth = GetDepthLinear(texcoord.st);

	rays = min(rays, transition_fading);
	return rays * 0.1;
}


///--2DGodRays--///
float Rays(in SurfaceStruct surface) {
	float gr = 0.0f;
	vec4 tpos = vec4(sunPosition, 1.0) * gbufferProjection;
	tpos = vec4(tpos.xyz / tpos.w,1.0);
	vec2 pos1 = tpos.xy / tpos.z;
	vec2 lightPos = pos1 * 0.5 + 0.5;

	float truepos = sign(sunPosition.z);

	if (truepos < 0.0) {
		vec2 deltaTextCoord = vec2(texcoord.st - lightPos.xy);
		vec2 textCoord = texcoord.st;
		deltaTextCoord *= 1.0 / float(NUM_SAMPLES) * grdensity;

		float avgdecay = 0.0;
		float distx = abs(texcoord.x * aspectRatio - lightPos.x * aspectRatio);
		float disty = abs(texcoord.y - lightPos.y);
		float fallof = 1.0;
		float noise = getnoise(textCoord);

		for(int i=0; i < NUM_SAMPLES ; i++) {
			textCoord -= deltaTextCoord;

			fallof *= GODRAY_LENGTH;
			float sample = step(texture2D(gdepth, textCoord + deltaTextCoord * noise * grnoise).r, 0.001);
			gr += sample * fallof;
		}
	}
	#ifdef MOONRAYS
		else {
			vec4 tpos = vec4(-sunPosition, 1.0) * gbufferProjection;
			tpos = vec4(tpos.xyz / tpos.w, 1.0);
			vec2 pos1 = tpos.xy / tpos.z;
			vec2 lightPos = pos1 * 0.5 + 0.5;

			if (truepos > 0.0) {
				vec2 deltaTextCoord = vec2(texcoord.st - lightPos.xy);
				vec2 textCoord = texcoord.st;
				deltaTextCoord *= 1.0 / float(NUM_SAMPLES) * grdensity;

				float avgdecay = 0.0;
				float distx = abs(texcoord.x * aspectRatio-lightPos.x * aspectRatio);
				float disty = abs(texcoord.y - lightPos.y);
				float fallof = 1.0;
				float noise = getnoise(textCoord);

				for(int i=0; i < NUM_SAMPLES ; i++) {
					textCoord -= deltaTextCoord;

					fallof *= 0.65;
					float sample = step(texture2D(gdepth, textCoord + deltaTextCoord * noise * grnoise).r, 0.001);
					gr += sample * fallof;
				}
			}
		}
	#endif
	return (gr/NUM_SAMPLES);
}

vec3 GetWavesNormal(vec3 position) {
	vec2 coord = position.xz / 50.0;
	coord.xy += position.y / 50.0;
	coord -= floor(coord);

	return texture2DLod(gaux3, coord / 2.0, 1).xyz * 2.0 - 1.0;
}

vec3 FakeRefract(vec3 vector, vec3 normal, float ior) {
	return refract(vector, normal, ior);
}

float CalculateWaterCaustics(SurfaceStruct surface, ShadingStruct shading) {
	if (surface.mask.water > 0.5 && isEyeInWater == 1) {
		return 1.0;
	}

	vec4 worldPos = gbufferModelViewInverse * surface.screenSpacePosition;
	worldPos.xyz += cameraPosition.xyz;

	vec2 dither = CalculateNoisePattern1(vec2(0.0), 2.0).xy;
	float waterPlaneHeight = 63.0;

	vec4 wlv = gbufferModelViewInverse * vec4(lightVector.xyz, 0.0);
	vec3 worldLightVector = -normalize(wlv.xyz);

	float pointToWaterVerticalLength = min(abs(worldPos.y - waterPlaneHeight), 2.0);
	vec3 flatRefractVector = FakeRefract(worldLightVector, vec3(0.0, 1.0, 0.0), 1.0 / 1.3333);
	float pointToWaterLength = pointToWaterVerticalLength / -flatRefractVector.y;
	vec3 lookupCenter = worldPos.xyz - flatRefractVector * pointToWaterLength;

	const float distanceThreshold = 0.15;

	const int numSamples = 1;
	int c = 0;

	float caustics = 0.0;

	for (int i = -numSamples; i <= numSamples; i++) {
		for (int j = -numSamples; j <= numSamples; j++) {
			vec2 offset = vec2(i + dither.x, j + dither.y) * 0.15;
			vec3 lookupPoint = lookupCenter + vec3(offset.x, 0.0, offset.y);
			vec3 wavesNormal = GetWavesNormal(lookupPoint).xzy;

			vec3 refractVector = FakeRefract(worldLightVector.xyz, wavesNormal.xyz, 1.0 / 1.3333);
			float rayLength = pointToWaterVerticalLength / refractVector.y;
			vec3 collisionPoint = lookupPoint - refractVector * rayLength;

			float dist = distance(collisionPoint, worldPos.xyz);

			caustics += 1.0 - saturate(dist / distanceThreshold);
			c++;
		}
	}

	caustics /= c;
	caustics /= distanceThreshold;

	return pow(caustics, 1.5) * 2.0;
}

void WaterDepthFog(inout vec3 color, in SurfaceStruct surface, in MCLightmapStruct mcLightmap) {
	if (surface.mask.water > 0.5 || isEyeInWater > 0) {
		float depth = texture2D(depthtex1, texcoord.st).x;
		float depthSolid = texture2D(gdepthtex, texcoord.st).x;

		vec4 viewSpacePosition = GetScreenSpacePosition(texcoord.st, depth);
		vec4 viewSpacePositionSolid = GetScreenSpacePosition(texcoord.st, depthSolid);

		vec3 viewVector = normalize(viewSpacePosition.xyz);

		float waterDepth = distance(viewSpacePosition.xyz, viewSpacePositionSolid.xyz);

		if (isEyeInWater > 0) {
			waterDepth = length(viewSpacePosition.xyz) * 0.5;
			if (surface.mask.water > 0.5) {
				waterDepth = length(viewSpacePositionSolid.xyz) * 0.5;
			}
		}

		float fogDensity = 0.30;
		float fogDensity2 = 0.010;
		float visibility = 1.0f / (pow(exp(waterDepth * fogDensity), 1.0f));
		float visibility2 = 1.0f / (pow(exp(waterDepth * fogDensity2), 1.0f));

		vec3 waterNormal = normalize(GetWaterNormals(texcoord.st));

		//Rainy water colour
		vec3 waterFogColors = vec3(0.05, 0.08, 0.1);	//murky water for the rainy weather

		//Depth water colour
		vec3 waterFogColors2 = vec3(0.0015, 0.004, 0.0098) * colorSunlight * pow(1-rainStrength, 2.0f);	//Depth water colour, ALT (0.0028,0.0107,0.0180)
		waterFogColors2 *=mix(0.0f, 1.0f, pow(eyeBrightnessSmooth.y / 240.0f, 10.0f));

		//Underwater colour
		vec3 waterFogColor = vec3(0.1, 0.5, 0.8); //clear water, Under water fog colour
		waterFogColor *= 0.01 * dot(vec3(0.33333), colorSunlight);


		vec3 viewVectorRefracted = refract(viewVector, waterNormal, 1.0 / 1.3333);
		float scatter = 1.0 / (pow(saturate(dot(-lightVector, viewVectorRefracted) * 0.5 + 0.5) * 20.0, 2.0) + 0.1);


		if (isEyeInWater < 1) {
			waterFogColor = mix(waterFogColor, colorSunlight * 21.0 * waterFogColor, vec3(scatter));
		}

		//this is to change the water colour when raining
		if (rainStrength > 0.9) {
			waterFogColors2 *= mix(waterFogColors, colorSunlight * waterFogColors, vec3(scatter * (1.0 - rainStrength)));
		}

		color *= pow(vec3(0.7, 0.88, 1.0) * 0.99, vec3(waterDepth * 0.45 + 0.8));

		//this is to separate water fog either in water or out
		if (isEyeInWater < 0.9) {
			color = mix(waterFogColors2, color, saturate(visibility));

			if (rainStrength > 0.9) {
					color = mix(waterFogColors2, color, saturate(visibility)) * pow(1.65 - rainStrength, 1.0f);
			}
		} else {
			color = mix(waterFogColor, color, saturate(visibility2));
		}
	}
}



///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main() {

	//Initialize surface properties required for lighting calculation for any surface that is not part of the sky
	surface.albedo = GetAlbedoLinear(texcoord.st);					//Gets the albedo texture
	surface.albedo = pow(surface.albedo, vec3(1.4f));

	surface.normal = GetNormals(texcoord.st);						//Gets the screen-space normals
	surface.depth = GetDepth(texcoord.st);						//Gets the scene depth
	surface.linearDepth = ExpToLinearDepth(surface.depth); 				//Get linear scene depth
	surface.screenSpacePosition1 = GetScreenSpacePosition(texcoord.st); 			//Gets the screen-space position
	surface.screenSpacePosition = GetScreenSpacePositionSolid(texcoord.st); 			//Gets the screen-space position
	surface.screenSpacePositionSolid = GetScreenSpacePositionSolid(texcoord.st); 			//Gets the screen-space position

	surface.viewVector = normalize(surface.screenSpacePosition1.rgb);	//Gets the view vector
	surface.lightVector = lightVector;									//Gets the sunlight vector
	surface.upVector = upVector;										//Store the up vector

	#ifdef GTX500_FIX
		//--causes GTX 500 cards yellow screen--//
		vec4 wlv = shadowModelViewInverse * vec4(0.0f, 0.0f, 1.0f, 0.0f);
		surface.worldLightVector = normalize(wlv.xyz);
		surface.upVector = upVector;
		//--causes GTX 500 cards yellow screen--//									//Store the up vector
	#endif

	surface.mask.matIDs = GetMaterialIDs(texcoord.st);					//Gets material ids
	CalculateMasks(surface.mask);

	if (surface.mask.water > 0.5) {
		surface.albedo *= 1.9;
	}

	surface.albedo *= 1.0f - float(surface.mask.sky); 						//Remove the sky from surface albedo, because sky will be handled separately

	//Initialize sky surface properties
	surface.sky.albedo = GetAlbedoLinear(texcoord.st) * (min(1.0f, float(surface.mask.sky) + float(surface.mask.sunspot)));							//Gets the albedo texture for the sky

	surface.sky.tintColor = mix(colorSunlight, vec3(colorSunlight.r), vec3(0.8f));									//Initializes the defualt tint color for the sky
	surface.sky.tintColor *= mix(1.0f, 100.0f, timeSkyDark); 														//Boost sky color at night																		//Scale sunglow back to be less intense

	surface.sky.sunSpot = vec3(float(CalculateSunspot(surface))) * vec3((min(1.0f, float(surface.mask.sky) + float(surface.mask.sunspot)))) * colorSunlight;
	surface.sky.sunSpot *= 1.0f - timeMidnight;
	surface.sky.sunSpot *= 300.0f;
	surface.sky.sunSpot *= 1.0f - rainStrength;

	AddSkyGradient(surface);
	AddSunglow(surface);



	//Initialize MCLightmap values
	mcLightmap.torch = GetLightmapTorch(texcoord.st);	//Gets the lightmap for light coming from emissive blocks

	mcLightmap.sky = GetLightmapSky(texcoord.st);		//Gets the lightmap for light coming from the sky
	mcLightmap.lightning = 0.0f;								//gets the lightmap for light coming from lightning

	//Initialize default surface shading attributes
	surface.diffuse.roughness = 0.0f;					//Default surface roughness
	surface.diffuse.translucency = 0.0f;					//Default surface translucency
	surface.diffuse.translucencyColor = vec3(1.0f);			//Default translucency color

	surface.specular.specularity = GetSpecularity(texcoord.st);	//Gets the reflectance/specularity of the surface
	surface.specular.extraSpecularity = 0.0f;							//Default value for extra specularity
	surface.specular.glossiness = GetGlossiness(texcoord.st);
	surface.specular.metallic = 0.0f;							//Default value of how metallic the surface is
	surface.specular.gain = 1.0f;							//Default surface specular gain
	surface.specular.base = 0.0f;							//Default reflectance when the surface normal and viewing normal are aligned
	surface.specular.fresnelPower = 5.0f;							//Default surface fresnel power

	//Calculate surface shading
	CalculateNdotL(surface);
	shading.direct = CalculateDirectLighting(surface);				//Calculate direct sunlight without visibility check (shadows)
	shading.sunlightVisibility = CalculateSunlightVisibility(surface, shading);					//Calculate shadows and apply them to direct lighting
	shading.direct *= shading.sunlightVisibility;
	shading.direct *= mix(1.0f, 0.0f, rainStrength);
	float caustics = 1.0;

	if(surface.mask.water > 0.5 || isEyeInWater > 0)
		caustics = CalculateWaterCaustics(surface, shading);

	shading.direct *= caustics;
	shading.waterDirect = shading.direct;

	#ifdef Global_Illumination
		shading.direct *= pow(mcLightmap.sky, 0.1f);
		shading.skylight = CalculateSkylight(surface);					//Calculate scattered light from sky
		shading.heldLight = CalculateHeldLightShading(surface);
	#else
		shading.direct *= pow(mcLightmap.sky, 0.1f);
		shading.bounced = CalculateBouncedSunlight(surface);			//Calculate fake bounced sunlight
		shading.scattered = CalculateScatteredSunlight(surface);			//Calculate fake scattered sunlight
		shading.skylight = CalculateSkylight(surface);					//Calculate scattered light from sky
		shading.scatteredUp = CalculateScatteredUpLight(surface);
		shading.heldLight = CalculateHeldLightShading(surface);
	#endif

	InitializeAO(surface);

	#ifdef Global_Illumination
		float ao = 1.0;
		vec4 delta = vec4(0.0);
		delta.a = 1.0;
		delta = Delta(surface.albedo.rgb, surface.normal.xyz, mcLightmap.sky);

		ao = delta.a;
	#endif

	//Colorize surface shading and store in lightmaps
	lightmap.sunlight = vec3(shading.direct) * colorSunlight;
	AddCloudGlow(lightmap.sunlight, surface);

	lightmap.skylight = vec3(mcLightmap.sky);
	lightmap.skylight *= mix(colorSkylight, colorBouncedSunlight, vec3(max(0.0f, (1.0f - pow(mcLightmap.sky + 0.1f, 0.45f) * 1.0f)))) + colorBouncedSunlight * (mix(Shadow_Brightness, 1.0f, wetness)) * (1.0f - rainStrength);
	lightmap.skylight *= shading.skylight;
	lightmap.skylight *= mix(1.0f, 5.0f, float(surface.mask.clouds));
	lightmap.skylight *= mix(1.0f, 50.0f, float(surface.mask.clouds) * timeSkyDark);
	lightmap.skylight *= surface.ao.skylight;
	lightmap.skylight += mix(colorSkylight, colorSunlight, vec3(0.2f)) * vec3(mcLightmap.sky) * surface.ao.constant * 0.05f;
	lightmap.skylight *= mix(1.0f, 1.2f, rainStrength);

	#ifdef Global_Illumination
		lightmap.skylight *= ao;

		lightmap.underwater = vec3(mcLightmap.sky) * colorSkylight;

		lightmap.torchlight = mcLightmap.torch * colorTorchlight;
		lightmap.torchlight *= surface.ao.constant * surface.ao.constant;
		lightmap.torchlight *= ao;

		lightmap.nolight = vec3(0.05f);
		lightmap.nolight *= surface.ao.constant;
		lightmap.nolight *= ao;
	#else
		lightmap.bouncedSunlight = vec3(shading.bounced) * colorBouncedSunlight;
		lightmap.bouncedSunlight *= pow(vec3(mcLightmap.sky), vec3(1.75f));
		lightmap.bouncedSunlight *= mix(1.0f, 0.25f, timeSunrise + timeSunset);
		lightmap.bouncedSunlight *= mix(1.0f, 0.0f, rainStrength);
		lightmap.bouncedSunlight *= surface.ao.bouncedSunlight;


		lightmap.scatteredSunlight = vec3(shading.scattered) * colorScatteredSunlight * (1.0f - rainStrength);
		lightmap.scatteredSunlight *= pow(vec3(mcLightmap.sky), vec3(1.0f));

		lightmap.underwater = vec3(mcLightmap.sky) * colorSkylight;

		lightmap.torchlight = mcLightmap.torch * colorTorchlight;
		lightmap.torchlight *= surface.ao.constant * surface.ao.constant;

		lightmap.nolight = vec3(0.05f);
		lightmap.nolight *= surface.ao.constant;

		lightmap.scatteredUpLight = vec3(shading.scatteredUp) * mix(colorSunlight, colorSkylight, vec3(0.0f));
		lightmap.scatteredUpLight *= pow(mcLightmap.sky, 0.5f);
		lightmap.scatteredUpLight *= surface.ao.scatteredUpLight;
		lightmap.scatteredUpLight *= mix(1.0f, 0.1f, rainStrength);
	#endif

	lightmap.heldLight = vec3(shading.heldLight);
	lightmap.heldLight *= colorTorchlight;
	lightmap.heldLight *= heldBlockLightValue * 0.070f;

	//If eye is in water
	if (isEyeInWater > 0) {
		vec3 halfColor = mix(colorWaterMurk, vec3(1.0f), vec3(0.5f));
		lightmap.sunlight *= mcLightmap.sky * halfColor;
		lightmap.skylight *= halfColor;
		lightmap.bouncedSunlight *= 0.0f;
		lightmap.scatteredSunlight *= halfColor;
		lightmap.nolight *= halfColor;
		lightmap.scatteredUpLight *= halfColor;
	}

	surface.albedo.rgb = mix(surface.albedo.rgb, pow(surface.albedo.rgb, vec3(2.0f)), vec3(float(surface.mask.fire)));

	//Apply lightmaps to albedo and generate final shaded surface
	final.nolight = surface.albedo * lightmap.nolight;
	final.sunlight = surface.albedo * lightmap.sunlight;
	final.skylight = surface.albedo * lightmap.skylight;
	final.bouncedSunlight = surface.albedo * lightmap.bouncedSunlight;
	final.scatteredSunlight = surface.albedo * lightmap.scatteredSunlight;
	final.scatteredUpLight = surface.albedo * lightmap.scatteredUpLight;
	final.torchlight = surface.albedo * lightmap.torchlight;
	final.underwater = surface.water.albedo * colorWaterBlue;
	final.underwater *= (lightmap.sunlight * 0.3f) + (lightmap.skylight * 0.06f) + (lightmap.torchlight * 0.0165) + (lightmap.nolight * 0.002f);

	//final.glow.torch 				= pow(surface.albedo, vec3(4.0f)) * float(surface.mask.torch);
	final.glow.lava = Glowmap(surface.albedo, surface.mask.lava,      3.0f, vec3(1.0f, 0.05f, 0.00f));
	final.glow.glowstone = Glowmap(surface.albedo, surface.mask.glowstone, 1.9f, colorTorchlight);
	final.torchlight *= 1.0f - float(surface.mask.glowstone);

	final.glow.fire = surface.albedo * float(surface.mask.fire);
	final.glow.fire = pow(final.glow.fire, vec3(1.0f));
	final.glow.torch = pow(surface.albedo * float(surface.mask.torch), vec3(4.4f));

	//Remove glow items from torchlight to keep control
	final.torchlight *= 1.0f - float(surface.mask.lava);

	final.heldLight = lightmap.heldLight * surface.albedo;

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
		const float sunlightMult = Brightness;
	#endif

	//Apply lightmaps to albedo and generate final shaded surface
	vec3 finalComposite = final.sunlight * 0.9f * 1.5f * sunlightMult				//Add direct sunlight
	+ final.skylight * 0.045f				//Add ambient skylight
	+ final.nolight * CAVE_BRIGHTNESS			//Add base ambient light

	#ifndef Global_Illumination
		+ final.bouncedSunlight * 0.05f * sunlightMult				//Add fake bounced sunlight
		+ final.scatteredSunlight * 0.02f	* sunlightMult			//Add fake scattered sunlight
		+ final.scatteredUpLight * 0.001f * sunlightMult
	#endif

	+ final.torchlight * 5.0f 			//Add light coming from emissive blocks
	+ final.glow.lava * 2.6f
	+ final.glow.glowstone * 2.1f
	+ final.glow.fire	* 0.35f
	+ final.glow.torch	* 1.15f

	#ifdef HELD_LIGHT
		+ final.heldLight * 0.05f
	#endif
	;

	//Apply sky to final composite
	surface.sky.albedo *= 0.85f;
	surface.sky.albedo = surface.sky.albedo * surface.sky.tintColor + surface.sky.sunglow + surface.sky.sunSpot;

	#ifdef CLOUD_PLANE
		CloudPlane(surface);
	#endif

	finalComposite 	+= surface.sky.albedo;		//Add sky to final image

	#ifdef Global_Illumination
		finalComposite 	+= delta.rgb * sunlightMult;
	#endif

	vec4 cloudsTexture = pow(texture2DLod(gaux2, texcoord.st / 4.0, 0).rgba, vec4(2.2, 2.2, 2.2, 1.0));

	//if eye is in water, do underwater fog
	if (isEyeInWater > 0) {
		#ifdef UnderwaterFog
			CalculateUnderwaterFog(surface, finalComposite);
		#endif
	}

	#ifdef RAIN_FOG
		CalculateRainFog(finalComposite.rgb, surface);
	#endif

////////////////////////////////////

	#ifdef NEW_UNDERWATER
		#ifdef ATMOSPHERIC_FOG
			if (isEyeInWater < 0)
				CalculateAtmosphericScattering(finalComposite.rgb, surface);
		#endif
	#else
		#ifdef ATMOSPHERIC_FOG
			CalculateAtmosphericScattering(finalComposite.rgb, surface);
		#endif
	#endif

//////////////////////////////////////


	#ifdef VOLUMETRIC_CLOUDS
		CalculateClouds(finalComposite.rgb, surface);
	#endif

	#ifdef VOLUMETRIC_CLOUDS2
		CalculateClouds2(finalComposite.rgb, surface);
	#endif

	#ifdef VOLUMETRIC_CLOUDS3
		CalculateClouds3(finalComposite.rgb, surface);
	#endif

	float Get2DGodRays = Rays( surface );

	#ifdef Water_DepthFog
		WaterDepthFog(finalComposite, surface, mcLightmap);
	#endif

	finalComposite *= 0.0007f;												//Scale image down for HDR
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

	vec4 finalCompositeCompiled = vec4(finalComposite, 1.0);

	#ifdef GODRAYS
		finalCompositeCompiled.a = Get2DGodRays;
	#endif

	#ifdef VOLUMETRIC_LIGHT
		finalCompositeCompiled.a = CrepuscularRays(surface);
	#endif

	gl_FragData[0] = finalCompositeCompiled;
	gl_FragData[1] = vec4(surface.mask.matIDs, surface.shadow * surface.cloudShadow * pow(mcLightmap.sky, 0.2f), mcLightmap.sky, 1.0f);
	gl_FragData[2] = vec4(surface.specular.specularity, surface.cloudAlpha, surface.specular.glossiness, 1.0f);

}
