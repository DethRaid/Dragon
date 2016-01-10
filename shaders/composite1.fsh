#version 120
#extension GL_ARB_shader_texture_lod : enable

 #include "/lib/clouds.glsl"
 #include "/lib/surface.glsl"

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

/////////ADJUSTABLE VARIABLES//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////ADJUSTABLE VARIABLES//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define SHADOW_MAP_BIAS 0.80

#define Global_Illumination

//#define ENABLE_SOFT_SHADOWS
#define VARIABLE_PENUMBRA_SHADOWS
#define USE_RANDOM_ROTATION

#define Shadow_Brightness 0.7		//[0.05 0.1 0.45 0.7 1.0 3.0 5.0 10.0]

#define Torch_Brightness 0.008		//[0.005 0.008 0.01 0.04 0.06 0.08 0.1]

#define HELD_LIGHT				//Dynamic Torch Light when in player hand

#define CAVE_BRIGHTNESS	0.0007		//[0.0002 0.0005 0.0007 0.003]

#define RAIN_FOG
	#define FOG_DENSITY	0.0030f			//default is 0.0018f and is best if using RainFog2 from final[0.0018 0.0025 0.0030 0.0038]

#define ATMOSPHERIC_FOG
#define NO_ATMOSPHERIC_FOG_INSIDE		//removes distant fog in caves/buildings
//#define MORNING_FOG
//#define EVENING_FOG

//#define NO_LEAVE_GRASS_LIGHTING		//This removes Sunlight from the tree leaves so you dont get over bright tree leaves that are far away

//#define UnderwaterFog		//only enable if not using Water_DepthFog

#define Water_DepthFog
#define FRAME_TIME frameTimeCounter

#define WaterCaustics

#define VOLUMETRIC_LIGHT			//True GodRays, not 2D ScreenSpace

//----------2D GodRays----------//
#define GODRAYS
	const float grdensity = 0.7;
	const int NUM_SAMPLES = 10;			//increase this for better quality at the cost of performance /10 is default
	const float grnoise = 1.0;		//amount of noise /1.0 is default

#define GODRAY_LENGTH 0.75			//default is 0.65, to increase the distance/length of the godrays at the cost of slight increase of sky brightness

#define MOONRAYS					//Make sure if you enable/disable this to do the same in Composite, PLEASE NOTE this is for 2D godrays not volumetric light

//----------End CONFIGURABLE 2D GodRays----------//

////----------This feature is connected to ATMOSPHERIC_FOG----------//


/////////END ADJUSTABLE VARIABLES//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////END ADJUSTABLE VARIABLES//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/////////INTERNAL VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////INTERNAL VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Do not change the name of these variables or their type. The Shaders Mod reads these lines and determines values to send to the inner-workings
//of the shaders mod. The shaders mod only reads these lines and doesn't actually know the real value assigned to these variables in GLSL.
//Some of these variables are critical for proper operation. Change at your own risk.

const int 		shadowMapResolution 	= 2048;			// Shadow Resolution. 1024 = Lowest Quality. 4096 = Highest Quality [1024 2048 3072 4096]
const float 	shadowDistance 			= 120;		// shadowDistance. 60 = Lowest Quality. 200 = Highest Quality [60 100 120 160 180 200]
const float 	shadowIntervalSize 		= 4.0f;
const bool 		shadowHardwareFiltering0 = true;

const bool 		shadowtex1Mipmap        = true;
const bool 		shadowtex1Nearest       = true;
const bool 		shadowcolor0Mipmap      = true;
const bool 		shadowcolor0Nearest     = false;
const bool 		shadowcolor1Mipmap      = true;
const bool 		shadowcolor1Nearest     = false;

const int 		RA8 					= 0;
const int 		RA16 					= 4;
const int 		RGA8 					= 0;
const int 		RGBA8 					= 1;
const int 		RGBA16 					= 1;
const int 		gcolorFormat 			= RGBA16;
const int 		gdepthFormat 			= RGBA8;
const int 		gnormalFormat 			= RGBA16;
const int 		compositeFormat 		= RGBA8;
const int       gaux3Format         	= RGBA16;

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
const bool guax3MipmapEnabled = true;

#define BANDING_FIX_FACTOR 1.0f

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2DShadow shadow;
uniform sampler2D shadowtex1;
//uniform sampler2D shadowcolor;
uniform sampler2D noisetex;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;

varying vec4 texcoord;
varying vec3 lightVector;
varying vec3 upVector;

uniform int worldTime;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
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
uniform vec3 skyColor;

uniform int   isEyeInWater;
uniform float eyeAltitude;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;
uniform int   fogMode;

varying float timeSunrise;
varying float timeSunset;
varying float timeSunriseSunset;
varying float timeNoon;
varying float timeMidnight;
varying float timeSkyDark;
varying float transition_fading;

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

/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

float saturate(float x)
{
	return clamp(x, 0.0, 1.0);
}

//Get gbuffer textures
vec3  	GetAlbedoLinear(in vec2 coord) {			//Function that retrieves the diffuse texture and convert it into linear space.
	return pow(texture2D(gcolor, coord).rgb, vec3(2.2f));
}

vec3  	GetAlbedoGamma(in vec2 coord) {			//Function that retrieves the diffuse texture and leaves it in gamma space.
	return texture2D(gcolor, coord).rgb;
}

vec3  	GetWaterNormals(in vec2 coord) {				//Function that retrieves the screen space surface normals. Used for lighting calculations
	return normalize(texture2DLod(gnormal, coord.st, 0).rgb * 2.0f - 1.0f);
}

vec3  	GetNormals(in vec2 coord) {				//Function that retrieves the screen space surface normals. Used for lighting calculations
	return texture2DLod(gnormal, coord.st, 0).rgb * 2.0f - 1.0f;
}

float 	GetDepth(in vec2 coord) {					//Function that retrieves the scene depth. 0 - 1, higher values meaning farther away
	return texture2D(gdepthtex, coord).r;
}

float 	GetDepthSolid(in vec2 coord) {					//Function that retrieves the scene depth. 0 - 1, higher values meaning farther away
	return texture2D(depthtex1, coord).r;
}

float 	GetDepthLinear(in vec2 coord) {					//Function that retrieves the scene depth. 0 - 1, higher values meaning farther away
	return 2.0f * near * far / (far + near - (2.0f * texture2D(gdepthtex, coord).x - 1.0f) * (far - near));
}

float 	ExpToLinearDepth(in float depth)
{
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

	// if (lightmap <= 0.0f)
		// lightmap = 1.0f;

	lightmap 		= max(0.0f, lightmap);
	lightmap 		*= Torch_Brightness;
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

bool  	GetSky(in vec2 coord) {					//Function that returns true for any pixel that is part of the sky, and false for any pixel that isn't part of the sky
	float matID = GetMaterialIDs(coord);		//Gets texture that has all material IDs stored in it
		  matID = floor(matID * 255.0f);		//Scale texture from 0-1 float to 0-255 integer format

	if (matID == 0.0f) {						//Checks to see if the current pixel's material ID is 0 = the sky
		return true;							//If the current pixel has the material ID of 0 (sky material ID), Return "this pixel is part of the sky"
	} else {
		return false;							//Return "this pixel is not part of the sky"
	}
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




//Water
float 	GetWaterTex(in vec2 coord) {				//Function that returns the texture used for water. 0 means "this pixel is not water". 0.5 and greater means "this pixel is water".
	return texture2D(composite, coord).b;		//values from 0.5 to 1.0 represent the amount of sky light hitting the surface of the water. It is used to simulate fake sky reflections in composite1.fsh
}

float  	GetWaterMask(in vec2 coord, in float matID) {					//Function that returns "true" if a pixel is water, and "false" if a pixel is not water.
	matID = (matID * 255.0f);

	if (matID >= 35.0f && matID <= 51) {
		return 1.0f;
	} else {
		return 0.0f;
	}
}




//Surface calculations
vec4  	GetScreenSpacePosition(in vec2 coord) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
	float depth = GetDepth(coord);
		  depth += float(GetMaterialMask(coord, 5, GetMaterialIDs(coord))) * 0.38f;
		  //float handMask = float(GetMaterialMask(coord, 5, GetMaterialIDs(coord)));
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;

		 //fragposition.xyz *= mix(1.0f, 15.0f, handMask);

	return fragposition;
}

vec4  	GetScreenSpacePositionSolid(in vec2 coord) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
	float depth = GetDepthSolid(coord);
		  depth += float(GetMaterialMask(coord, 5, GetMaterialIDs(coord))) * 0.38f;
		  //float handMask = float(GetMaterialMask(coord, 5, GetMaterialIDs(coord)));
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;

		 //fragposition.xyz *= mix(1.0f, 15.0f, handMask);

	return fragposition;
}

vec4  	GetScreenSpacePosition(in vec2 coord, in float depth) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
		  //depth += float(GetMaterialMask(coord, 5)) * 0.38f;
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;

	return fragposition;
}

vec4 	GetWorldSpacePosition(in vec2 coord, in float depth)
{
	vec4 pos = GetScreenSpacePosition(coord, depth);
	pos = gbufferModelViewInverse * pos;
	pos.xyz += cameraPosition.xyz;

	return pos;
}

vec4 	ScreenSpaceFromWorldSpace(in vec4 worldPosition)
{
	worldPosition.xyz -= cameraPosition;
	worldPosition = gbufferModelView * worldPosition;
	return worldPosition;
}



void 	DoNightEye(inout vec3 color) {			//Desaturates any color input at night, simulating the rods in the human eye

	float amount = 0.8f; 						//How much will the new desaturated and tinted image be mixed with the original image
	vec3 rodColor = vec3(0.2f, 0.5f, 1.25f); 	//Cyan color that humans percieve when viewing extremely low light levels via rod cells in the eye
	float colorDesat = dot(color, vec3(1.0f)); 	//Desaturated color

	color = mix(color, vec3(colorDesat) * rodColor, timeSkyDark * amount);
	//color.rgb = color.rgb;
}


float 	ExponentialToLinearDepth(in float depth)
{
	vec4 worldposition = vec4(depth);
	worldposition = gbufferProjection * worldposition;
	return worldposition.z;
}

float 	LinearToExponentialDepth(in float linDepth)
{
	float expDepth = (far * (linDepth - near)) / (linDepth * (far - near));
	return expDepth;
}

void 	DoLowlightEye(inout vec3 color) {			//Desaturates any color input at night, simulating the rods in the human eye

	float amount = 0.8f; 						//How much will the new desaturated and tinted image be mixed with the original image
	vec3 rodColor = vec3(0.2f, 0.5f, 1.0f); 	//Cyan color that humans percieve when viewing extremely low light levels via rod cells in the eye
	float colorDesat = dot(color, vec3(1.0f)); 	//Desaturated color

	color = mix(color, vec3(colorDesat) * rodColor, amount);
	// color.rgb = color.rgb;
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

vec3 	Glowmap(in vec3 albedo, in float mask, in float curve, in vec3 emissiveColor) {
	vec3 color = albedo * (mask);
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
		)
	{

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

/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct MCLightmapStruct {		//Lightmaps directly from MC engine
	float torch;				//Light emitted from torches and other emissive blocks
	float sky;					//Light coming from the sky
	float lightning;			//Light coming from lightning

	vec3 torchVector; 			//Vector in screen space that represents the direction of average light transfered
	vec3 skyVector;
} mcLightmap;

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


		if (isEyeInWater > 0)
			mask.sky = 0.0f;
		else
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

		mask.volumeCloud 	= 0.0f;
}

//Surface
void 	CalculateNdotL(inout SurfaceStruct surface) {		//Calculates direct sunlight without visibility check
	float direct = dot(surface.normal.rgb, surface.lightVector);
		  direct = direct * 1.0f + 0.0f;
		  //direct = clamp(direct, 0.0f, 1.0f);

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
	} else if (surface.mask.leaves > 0.5f) {

#ifdef NO_LEAVE_GRASS_LIGHTING
		 if (surface.NdotL > -0.01f) {
		 	return surface.NdotL * 0.99f + 0.01f;
		 } else {
		 	return abs(surface.NdotL) * 0.25f;
		 }
#endif
		return 1.0f;


	//clouds
	} else if (surface.mask.clouds > 0.5f) {

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

float CalculateSunlightVisibility(inout SurfaceStruct surface, in ShadingStruct shadingStruct) {    //Calculates shadows    // I should hope so
	if (rainStrength > 0.99f)
		return 1.0f;

	if (shadingStruct.direct > 0.0f) {
		float distance = length(surface.screenSpacePosition.xyz);

		float waterFOVFix = 1.0;
		if(isEyeInWater >= 0.9) {
			waterFOVFix = 60.0f / 70.0f;

		}

		vec4 worldposition = vec4(0.0f);
         worldposition = gbufferModelViewInverse * surface.screenSpacePosition;         //Transform from screen space to world space

		float yDistanceSquared  = worldposition.y * worldposition.y;

    worldposition = shadowModelView * worldposition;        //Transform from world space to shadow space
	  float comparedepth = -worldposition.z;                          //Surface distance from sun to be compared to the shadow map

    worldposition = shadowProjection * worldposition;
    worldposition /= worldposition.w;

    //float dist = sqrt(worldposition.x * worldposition.x + worldposition.y * worldposition.y);
		float dist = sqrt(dot(worldposition.xy, worldposition.xy));
    float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
    worldposition.xy *= 1.0f / distortFactor;
    worldposition = worldposition * 0.5f + 0.5f;            //Transform from shadow space to shadow map coordinates

    float shadowMult = 0.0f;                                                                                                                                                        //Multiplier used to fade out shadows at distance
    float shading = 0.0f;

    if (distance < shadowDistance && comparedepth > 0.0f && worldposition.s < 1.0f && worldposition.s > 0.0f && worldposition.t < 1.0f && worldposition.t > 0.0f) {

			float fademult = 0.15f;
      shadowMult = clamp((shadowDistance * 0.85f * fademult) - (distance * fademult), 0.0f, 1.0f);    //Calculate shadowMult to fade shadows out

      float diffthresh = dist * 1.0f + 0.10f;
            diffthresh *= 3.0f / (shadowMapResolution / 2048.0f);
            //diffthresh /= shadingStruct.direct + 0.1f;

			#if defined ENABLE_SOFT_SHADOWS

          float numBlockers = 0.0;
          float numSamples = 0.0;

          int PCFSizeHalf = 3;

          float penumbraSize = 0.5;

          #ifdef USE_RANDOM_ROTATION
          	float rotateAmount = texture2D( noisetex, texcoord.st * vec2(viewWidth / noiseTextureResolution, viewHeight / noiseTextureResolution)).r * 2.0f - 1.0f;

            mat2 kernelRotation = mat2(
                 cos(rotateAmount), -sin(rotateAmount),
                 sin(rotateAmount), cos(rotateAmount));
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

						float vpsSpread = 0.4 / distortFactor;

						float avgDepth = 0.0;
						float minDepth = 11.0;
						int c;

						for (int i = -1; i <= 1; i++) {
							for (int j = -1; j <= 1; j++) {
								vec2 lookupCoord = worldposition.xy + (vec2(i, j) / shadowMapResolution) * 8.0 * vpsSpread;
								//avgDepth += pow(texture2DLod(shadowtex1, lookupCoord, 2).x, 4.1);
								float depthSample = texture2DLod(shadowtex1, lookupCoord, 2).x;
								minDepth = min(minDepth, texture2DLod(shadowtex1, lookupCoord, 2).x);
								avgDepth += pow(min(max(0.0, worldposition.z - depthSample) * 1.0, 0.15), 2.0);
								c++;
							}
						}

						avgDepth /= c;
						avgDepth = pow(avgDepth, 1.0 / 2.0);

						//float penumbraSize = min(abs(worldposition.z - minDepth), 0.15);
						float penumbraSize = avgDepth;

						int count = 0;
						float spread = penumbraSize * 0.0062 * vpsSpread + 0.085 / shadowMapResolution;

						vec3 noise = CalculateNoisePattern1(vec2(0.0), 64.0);

						diffthresh *= 1.0 + avgDepth * 40.0;

						for (float i = -2.0f; i <= 2.0f; i += 1.0f) {
							for (float j = -2.0f; j <= 2.0f; j += 1.0f) {
								float angle = noise.x * 3.14159 * 2.0;

								mat2 rot = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));

								vec2 coord = vec2(i, j) * rot;

								shading += shadow2D(shadow, vec3(worldposition.st + coord * spread, worldposition.z - 0.0012f * diffthresh)).x;
								count += 1;
							}
						}
						shading /= count;
						#else

						//diffthresh *= 2.0f;
						shading = shadow2DLod(shadow, vec3(worldposition.st, worldposition.z - 0.0006f * diffthresh), 0).x;
					#endif
				}

				shading = mix(1.0f, shading, shadowMult) * pow(1-rainStrength, 2.0f);

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
		  //scattered *= scattered * scattered;

	return scattered;
}

float 	CalculateSkylight(in SurfaceStruct surface) {

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

float CalculateHeldLightShading(in SurfaceStruct surface)
{
	vec3 lightPos = vec3(0.0f);
	vec3 lightVector = normalize(lightPos - surface.screenSpacePosition1.xyz);
	float lightDist = length(lightPos.xyz - surface.screenSpacePosition1.xyz);

	float atten = 1.0f / (pow(lightDist, 2.0f) + 0.001f);
	float NdotL = 1.0f;

	return atten * NdotL;
}

float   CalculateSunglow(in SurfaceStruct surface) {

	float curve = 4.0f;

	vec3 npos = normalize(surface.screenSpacePosition1.xyz);
	vec3 halfVector2 = normalize(-surface.lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

float   CalculateAntiSunglow(in SurfaceStruct surface) {

	float curve = 4.0f;

	vec3 npos = normalize(surface.screenSpacePosition1.xyz);
	vec3 halfVector2 = normalize(surface.lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

bool   CalculateSunspot(in SurfaceStruct surface) {

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

void 	AddSunglow(inout SurfaceStruct surface) {
	float sunglowFactor = CalculateSunglow(surface);
	float antiSunglowFactor = CalculateAntiSunglow(surface);

	surface.sky.albedo *= 1.0f + pow(sunglowFactor, 1.1f) * (1.5f + timeNoon * 1.0f) * (1.0f - rainStrength);
	surface.sky.albedo *= mix(vec3(1.0f), colorSunlight * 5.0f, pow(clamp(vec3(sunglowFactor) * (1.0f - timeMidnight) * (1.0f - rainStrength), vec3(0.0f), vec3(1.0f)), vec3(2.0f)));

	surface.sky.albedo *= 1.0f + antiSunglowFactor * 2.0f * (1.0f - rainStrength);
	//surface.sky.albedo *= mix(vec3(1.0f), colorSunlight, antiSunglowFactor);
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

void 	TestRaymarch(inout vec3 color, in SurfaceStruct surface)
{

	//visualize march steps
	float rayDepth = 0.0f;
	float rayIncrement = 0.05f;
	float fogFactor = 0.0f;

	while (rayDepth < 1.0f)
	{
		vec4 rayPosition = GetScreenSpacePosition(texcoord.st, pow(rayDepth, 0.002f));



		if (abs(rayPosition.z - surface.screenSpacePosition1.z) < 0.025f)
		{
			color.rgb = vec3(0.01f, 0.0f, 0.0f);
		}

		// if (SphereTestDistance(vec3(surface.screenSpacePosition1.x, surface.screenSpacePosition1.y, surface.screenSpacePosition1.z)) <= 0.001f)
		// 	fogFactor += 0.001f;

		rayDepth += rayIncrement;

	}

	// color.rgb = mix(color.rgb, vec3(1.0f) * 0.01f, fogFactor);

	// vec4 newPosition = surface.screenSpacePosition1;

	// color.rgb = vec3(distance(newPosition.rgb, vec3(0.0f, 0.0f, 0.0f)) * 0.00001f);

}

void InitializeAO(inout SurfaceStruct surface)
{
	surface.ao.skylight = 1.0f;
	surface.ao.bouncedSunlight = 1.0f;
	surface.ao.scatteredUpLight = 1.0f;
	surface.ao.constant = 1.0f;
}

void CalculateAO(inout SurfaceStruct surface)
{
	const int numSamples = 20;
	vec3[numSamples] kernel;

	vec3 stochastic = texture2D(noisetex, texcoord.st * vec2(viewWidth, viewHeight) / noiseTextureResolution).rgb;

	//Generate positions for sample points in hemisphere
	for (int i = 0; i < numSamples; i++)
	{
		//Random direction
		kernel[i] = vec3(texture2D(noisetex, vec2(0.0f + (i * 1.0f) / noiseTextureResolution)).r * 2.0f - 1.0f,
					     texture2D(noisetex, vec2(0.0f + (i * 1.0f) / noiseTextureResolution)).g * 2.0f - 1.0f,
					     texture2D(noisetex, vec2(0.0f + (i * 1.0f) / noiseTextureResolution)).b * 2.0f - 1.0f);
		//kernel[i] += (stochastic * vec3(2.0f, 2.0f, 1.0f) - vec3(1.0f, 1.0f, 0.0f)) * 0.0f;
		kernel[i] = normalize(kernel[i]);

		//scale randomly to distribute within hemisphere;
		kernel[i] *= pow(texture2D(noisetex, vec2(0.3f + (i * 1.0f) / noiseTextureResolution)).r * CalculateNoisePattern1(vec2(43.0f), 64.0f).x * 1.0f, 1.2f);
	}

	//Determine origin position and normal
	vec3 origin = surface.screenSpacePosition1.xyz;
	vec3 normal = surface.normal.xyz;
		 //normal = lightVector;

	//Create matrix to orient hemisphere according to surface normal
	//vec3 randomRotation = texture2D(noisetex, texcoord.st * vec2(viewWidth / noiseTextureResolution, viewHeight / noiseTextureResolution)).rgb * 2.0f - 1.0f;
		//float dither1 = CalculateDitherPattern1() * 2.0f - 1.0f;
		//randomRotation = vec3(dither1, mod(dither1 + 0.5f, 2.0f), mod(dither1 + 1.0f, 2.0f));
	vec3	randomRotation = CalculateNoisePattern1(vec2(0.0f), 64.0f).xyz * 2.0f - 1.0f;
	//vec3	randomRotation = vec3(1.0f, 0.0f, 0.0f);


	vec3 tangent = normalize(randomRotation - upVector * dot(randomRotation, upVector));
	vec3 bitangent = cross(upVector, tangent);
	mat3 tbn = mat3(tangent, bitangent, upVector);

	float ao = 0.0f;
	float aoSkylight	= 0.0f;
	float aoUp  		= 0.0f;
	float aoBounced  	= 0.0f;
	float aoScattered  	= 0.0f;


	float aoRadius   = 0.35f * -surface.screenSpacePosition1.z;
		  //aoRadius   = 3.0f;
	float zThickness = 0.35f * -surface.screenSpacePosition1.z;
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

	for (int i = 0; i < numSamples; i++)
	{
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
			if (sampleDepth >= samplePosition.z && surface.mask.sky < 0.5f)
			{
				//Reduce halo
				float sampleLength = length(samplePosition - origin) * 4.0f;
				//distanceWeight = 1.0f - clamp(distance(sampleDepth, origin.z) - (sampleLength * 0.5f), 0.0f, sampleLength * 0.5f) / (sampleLength * 0.5f);
				distanceWeight = 1.0f - step(sampleLength, distance(sampleDepth, origin.z));

				//Weigh samples based on light direction
				skylightWeight 			= clamp(dot(normalize(samplePosition - origin), upVector)		* 1.0f - 0.0f , 0.0f, 0.01f) / 0.01f;
				//skylightWeight 		   += clamp(dot(normalize(samplePosition - origin), upVector), 0.0f, 1.0f);
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

	//surface.debug = vec3(pow(aoSkylight, 2.0f) * clamp((dot(surface.normal, upVector) * 0.75f + 0.25f), 0.0f, 1.0f));
	//surface.debug = vec3(dot(normalize(bentNormal), upVector));
}


void 	CalculateRainFog(inout vec3 color, in SurfaceStruct surface)
{
	vec3 fogColor = colorSkylight * 0.055f;

	float fogDensity = 0.0014f * rainStrength;
		  fogDensity *= mix(0.0f, 1.0f, pow(eyeBrightnessSmooth.y / 240.0f, 15.0f));
	float visibility = 1.0f / (pow(exp(distance(surface.screenSpacePosition1.xyz, vec3(0.0f)) * fogDensity), 1.0f));
	float fogFactor = 1.0f - visibility;
		  fogFactor = clamp(fogFactor, 0.0f, 1.0f);
		  fogFactor = mix(fogFactor, 1.0f, float(surface.mask.sky) * 0.8f * rainStrength);
		  fogFactor = mix(fogFactor, 1.0f, float(surface.mask.clouds) * 0.8f * rainStrength);
		  //fogFactor = mix(fogFactor, 1.0f, float(surface.mask.water) * rainStrength);


	color = mix(color, fogColor, vec3(fogFactor));
}

void 	CalculateAtmosphericScattering(inout vec3 color, in SurfaceStruct surface)
{
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


Intersection 	RayPlaneIntersectionWorld(in Ray ray, in Plane plane)
{
	float rayPlaneAngle = dot(ray.dir, plane.normal);

	float planeRayDist = 100000000.0f;
	vec3 intersectionPos = ray.dir * planeRayDist;

	if (rayPlaneAngle > 0.0001f || rayPlaneAngle < -0.0001f)
	{
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

Intersection 	RayPlaneIntersection(in Ray ray, in Plane plane)
{
	float rayPlaneAngle = dot(ray.dir, plane.normal);

	float planeRayDist = 100000000.0f;
	vec3 intersectionPos = ray.dir * planeRayDist;

	if (rayPlaneAngle > 0.0001f || rayPlaneAngle < -0.0001f)
	{
		planeRayDist = dot((plane.origin - ray.origin), plane.normal) / rayPlaneAngle;
		intersectionPos = ray.origin + ray.dir * planeRayDist;
		// intersectionPos = -intersectionPos;

		// intersectionPos += cameraPosition.xyz;
	}

	Intersection i;

	i.pos = intersectionPos;
	i.distance = planeRayDist;
	i.angle = rayPlaneAngle;

	return i;
}

float CubicSmooth(float x)
{
	return x * x * (3.0 - 2.0 * x);
}


float Get3DNoise(in vec3 pos)
{
	pos.z += 0.0f;
	vec3 p = floor(pos);
	vec3 f = fract(pos);
	//f = f * f * (3.0f - 2.0f * f);

	vec2 uv =  (p.xy + p.z * vec2(17.0f)) + f.xy;
	vec2 uv2 = (p.xy + (p.z + 1.0f) * vec2(17.0f)) + f.xy;
	vec2 coord =  (uv  + 0.5f) / noiseTextureResolution;
	vec2 coord2 = (uv2 + 0.5f) / noiseTextureResolution;
	float xy1 = texture2D(noisetex, coord).x;
	float xy2 = texture2D(noisetex, coord2).x;
	return mix(xy1, xy2, f.z);
}



/*
vec3 Contrast(in vec3 color, in float contrast)
{
	float colorLength = length(color);
	vec3 nColor = color / colorLength;

	colorLength = pow(colorLength, contrast);

	return nColor * colorLength;
}


float GetAO(in vec4 screenSpacePosition1, in vec3 normal, in vec2 coord, in vec3 dither)
{
	//Determine origin position
	vec3 origin = screenSpacePosition1.xyz;

	vec3 randomRotation = normalize(dither.xyz * vec3(2.0f, 2.0f, 1.0f) - vec3(1.0f, 1.0f, 0.0f));

	vec3 tangent = normalize(randomRotation - normal * dot(randomRotation, normal));
	vec3 bitangent = cross(normal, tangent);
	mat3 tbn = mat3(tangent, bitangent, normal);

	float aoRadius   = 0.15f * -screenSpacePosition1.z;
		  //aoRadius   = 0.8f;
	float zThickness = 0.15f * -screenSpacePosition1.z;
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
*/
vec4 BilateralUpsample(const in float scale, in vec2 offset, in float depth, in vec3 normal)
{
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
			//float weight = 1.0f / (pow(abs(sampleDepth - depth) * 1000.0f, 2.0f) + 0.001f);
			float weight = clamp(1.0f - abs(sampleDepth - depth) / 2.0f, 0.0f, 1.0f);
				  weight *= max(0.0f, dot(sampleNormal, normal) * 2.0f - 1.0f);
			//weight = 1.0f;

			light +=	pow(texture2DLod(gaux1, (texcoord.st) * (1.0f / exp2(scale )) + 	offset + coord, 1), vec4(2.2f, 2.2f, 2.2f, 1.0f)) * weight;

			weights += weight;
		}
	}


	light /= max(0.00001f, weights);

	if (weights < 0.01f)
	{
		light =	pow(texture2DLod(gaux1, (texcoord.st) * (1.0f / exp2(scale 	)) + 	offset, 2), vec4(2.2f, 2.2f, 2.2f, 1.0f));
	}


	// vec3 light =	texture2DLod(gcolor, (texcoord.st) * (1.0f / pow(2.0f, 	scale 	)) + 	offset, 2).rgb;


	return light;
}

vec4 Delta(vec3 albedo, vec3 normal, float skylight)
{
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
		float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
		rayPosition.xy *= 1.0f / distortFactor;
		rayPosition = rayPosition * 0.5f + 0.5f;

		float shadowSample = shadow2DLod(shadow, vec3(rayPosition.st, rayPosition.z + 0.0018f), 2).x;

			lightAccumulation += shadowSample * increment;

			ambientFogAccumulation *= 1.0f;

			rayDepth += increment;
			count++;
			increment *= 1.5;
	}

	lightAccumulation /= numSteps;
	ambientFogAccumulation /= numSteps;

	float sunglow = CalculateSunglow(surface);
	float antiSunglow = CalculateAntiSunglow(surface);

	float anisoHighlight = pow(1.0f / (pow((1.0f - sunglow) * 3.0f, 2.0f) + 0.0001f) * 1.5f, 1.5f) + 0.5;
				anisoHighlight *= sunglow + 0.0f;
				anisoHighlight += antiSunglow * 0.05f;

	float rays = lightAccumulation;

	//vec3 rayColor = colorSunlight * 3.0f + colorSkylight * 1.0f + colorSunlight * (anisoHighlight * 120.0f);

  //rays *= rayColor;
	float depth = GetDepthLinear(texcoord.st);


	//color += rays * (0.002f + float(isEyeInWater) * 0.0001f);
	rays = min(rays, transition_fading);
	return rays * 0.1;
}

vec4 textureSmooth(in sampler2D tex, in vec2 coord)
{
	vec2 res = vec2(64.0f, 64.0f);

	coord *= res;
	coord += 0.5f;

	vec2 whole = floor(coord);
	vec2 part  = fract(coord);

	part.x = part.x * part.x * (3.0f - 2.0f * part.x);
	part.y = part.y * part.y * (3.0f - 2.0f * part.y);
	// part.x = 1.0f - (cos(part.x * 3.1415f) * 0.5f + 0.5f);
	// part.y = 1.0f - (cos(part.y * 3.1415f) * 0.5f + 0.5f);

	coord = whole + part;

	coord -= 0.5f;
	coord /= res;

	return texture2D(tex, coord);
}

float AlmostIdentity(in float x, in float m, in float n)
{
	if (x > m) return x;

	float a = 2.0f * n - m;
	float b = 2.0f * m - 3.0f * n;
	float t = x / m;

	return (a * t + b) * t * t + n;
}

float GetWaves(vec3 position) {
	float speed = 0.9f;

  vec2 p = position.xz / 20.0f;

  p.xy -= position.y / 20.0f;

  p.x = -p.x;

  p.x += (FRAME_TIME / 40.0f) * speed;
  p.y -= (FRAME_TIME / 40.0f) * speed;

  float weight = 1.0f;
  float weights = weight;

  float allwaves = 0.0f;

  float wave = 0.0;
	//wave = textureSmooth(noisetex, (p * vec2(2.0f, 1.2f))  + vec2(0.0f,  p.x * 2.1f) ).x;
	p /= 2.1f; 	/*p *= pow(2.0f, 1.0f);*/ 	p.y -= (FRAME_TIME / 20.0f) * speed; p.x -= (FRAME_TIME / 30.0f) * speed;
  //allwaves += wave;

  weight = 4.1f;
  weights += weight;
      wave = textureSmooth(noisetex, (p * vec2(2.0f, 1.4f))  + vec2(0.0f,  -p.x * 2.1f) ).x;
			p /= 1.5f;/*p *= pow(2.0f, 2.0f);*/ 	p.x += (FRAME_TIME / 20.0f) * speed;
      wave *= weight;
  allwaves += wave;

  weight = 17.25f;
  weights += weight;
      wave = (textureSmooth(noisetex, (p * vec2(1.0f, 0.75f))  + vec2(0.0f,  p.x * 1.1f) ).x);		p /= 1.5f; 	p.x -= (FRAME_TIME / 55.0f) * speed;
      wave *= weight;
  allwaves += wave;

  weight = 15.25f;
  weights += weight;
      wave = (textureSmooth(noisetex, (p * vec2(1.0f, 0.75f))  + vec2(0.0f,  -p.x * 1.7f) ).x);		p /= 1.9f; 	p.x += (FRAME_TIME / 155.0f) * speed;
      wave *= weight;
  allwaves += wave;

  weight = 29.25f;
  weights += weight;
      wave = abs(textureSmooth(noisetex, (p * vec2(1.0f, 0.8f))  + vec2(0.0f,  -p.x * 1.7f) ).x * 2.0f - 1.0f);		p /= 2.0f; 	p.x += (FRAME_TIME / 155.0f) * speed;
      wave = 1.0f - AlmostIdentity(wave, 0.2f, 0.1f);
      wave *= weight;
  allwaves += wave;

  weight = 15.25f;
  weights += weight;
      wave = abs(textureSmooth(noisetex, (p * vec2(1.0f, 0.8f))  + vec2(0.0f,  p.x * 1.7f) ).x * 2.0f - 1.0f);
      wave = 1.0f - AlmostIdentity(wave, 0.2f, 0.1f);
      wave *= weight;
  allwaves += wave;

  allwaves /= weights;

  return allwaves;
}

vec3 GetWavesNormal(vec3 position) {

	vec2 coord = position.xz / 50.0;
	coord.xy += position.y / 50.0;
	coord -= floor(coord);

	return texture2DLod(gaux3, coord, 1).xyz * 2.0 - 1.0;
}

vec3 FakeRefract(vec3 vector, vec3 normal, float ior)
{
	return refract(vector, normal, ior);
	//return vector + normal * 0.5;
}


float CalculateWaterCaustics(SurfaceStruct surface, ShadingStruct shading)
{
	//if (shading.direct <= 0.0)
	//{
	//	return 0.0;
	//}
	if (isEyeInWater == 1)
	{
		if (surface.mask.water > 0.5)
		{
			return 1.0;
		}
	}
	vec4 worldPos = gbufferModelViewInverse * surface.screenSpacePosition;
	worldPos.xyz += cameraPosition.xyz;

	vec2 dither = CalculateNoisePattern1(vec2(0.0), 2.0).xy;
	// float waterPlaneHeight = worldPos.y + 8.0;
	float waterPlaneHeight = 63.0;

	// vec4 wlv = shadowModelViewInverse * vec4(0.0, 0.0, 1.0, 0.0);
	vec4 wlv = gbufferModelViewInverse * vec4(lightVector.xyz, 0.0);
	vec3 worldLightVector = -normalize(wlv.xyz);
	// worldLightVector = normalize(vec3(-1.0, 1.0, 0.0));

	float pointToWaterVerticalLength = min(abs(worldPos.y - waterPlaneHeight), 2.0);
	vec3 flatRefractVector = FakeRefract(worldLightVector, vec3(0.0, 1.0, 0.0), 1.0 / 1.3333);
	float pointToWaterLength = pointToWaterVerticalLength / -flatRefractVector.y;
	vec3 lookupCenter = worldPos.xyz - flatRefractVector * pointToWaterLength;


	const float distanceThreshold = 0.15;

	const int numSamples = 1;
	int c = 0;

	float caustics = 0.0;

	for (int i = -numSamples; i <= numSamples; i++)
	{
		for (int j = -numSamples; j <= numSamples; j++)
		{
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

void WaterDepthFog(inout vec3 color, in SurfaceStruct surface, in MCLightmapStruct mcLightmap)
{
	// return;
	if (surface.mask.water > 0.5 || isEyeInWater > 0)
	{
		float depth = texture2D(depthtex1, texcoord.st).x;
		float depthSolid = texture2D(gdepthtex, texcoord.st).x;

		vec4 viewSpacePosition = GetScreenSpacePosition(texcoord.st, depth);
		vec4 viewSpacePositionSolid = GetScreenSpacePosition(texcoord.st, depthSolid);

		vec3 viewVector = normalize(viewSpacePosition.xyz);


		float waterDepth = distance(viewSpacePosition.xyz, viewSpacePositionSolid.xyz);

		if (isEyeInWater > 0)
		{
			waterDepth = length(viewSpacePosition.xyz) * 0.5;
			if (surface.mask.water > 0.5)
			{
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
				 //waterFogColor *= mcLightmap.sky/4;							//seems to make under water clear, off by default

		// float scatter = CalculateSunglow(surface);

		vec3 viewVectorRefracted = refract(viewVector, waterNormal, 1.0 / 1.3333);
		float scatter = 1.0 / (pow(saturate(dot(-lightVector, viewVectorRefracted) * 0.5 + 0.5) * 20.0, 2.0) + 0.1);

		// scatter += pow(saturate(dot(-lightVector, viewVectorRefracted) * 0.5 + 0.5), 3.0) * 0.02;

	if (isEyeInWater < 1)
		{
			waterFogColor = mix(waterFogColor, colorSunlight * 21.0 * waterFogColor, vec3(scatter));
			//waterFogColor *= mix(waterFogColors, colorSunlight * 21.0 * waterFogColors, vec3(scatter))*rainStrength;	//dont think this is doing anything
		}

//this is to change the water colour when raining
	if (rainStrength > 0.9)
		{
			waterFogColors2 *= mix(waterFogColors, colorSunlight * waterFogColors, vec3(scatter * (1.0 - rainStrength)));
		}


		color *= pow(vec3(0.7, 0.88, 1.0) * 0.99, vec3(waterDepth * 0.45 + 0.8));



//this is to separate water fog either in water or out
	if (isEyeInWater < 0.9)
		{
			color = mix(waterFogColors2, color, saturate(visibility));
			if (rainStrength > 0.9)
				{
					color = mix(waterFogColors2, color, saturate(visibility))* pow(1.65-rainStrength, 1.0f);
				}
		}
		else
		{
			color = mix(waterFogColor, color, saturate(visibility2));
		}
	}
}

///--2DGodRays--///
float Rays(in SurfaceStruct surface)
{
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
		return (gr/NUM_SAMPLES);
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main() {

	//Initialize surface properties required for lighting calculation for any surface that is not part of the sky
	surface.albedo 				= GetAlbedoLinear(texcoord.st);					//Gets the albedo texture
	surface.albedo 				= pow(surface.albedo, vec3(1.4f));


	surface.normal 				= GetNormals(texcoord.st);						//Gets the screen-space normals
	surface.depth  				= GetDepth(texcoord.st);						//Gets the scene depth
	surface.linearDepth 		= ExpToLinearDepth(surface.depth); 				//Get linear scene depth
	surface.screenSpacePosition1 = GetScreenSpacePosition(texcoord.st); 			//Gets the screen-space position
	surface.screenSpacePosition = GetScreenSpacePositionSolid(texcoord.st); 			//Gets the screen-space position
	surface.screenSpacePositionSolid = GetScreenSpacePositionSolid(texcoord.st); 			//Gets the screen-space position

	surface.viewVector 			= normalize(surface.screenSpacePosition1.rgb);	//Gets the view vector
	surface.lightVector 		= lightVector;									//Gets the sunlight vector
	surface.upVector 			= upVector;										//Store the up vector
	vec4 wlv 					= shadowModelViewInverse * vec4(0.0f, 0.0f, 1.0f, 0.0f);
	surface.worldLightVector 	= normalize(wlv.xyz);
	surface.upVector 			= upVector;										//Store the up vector


	surface.mask.matIDs 		= GetMaterialIDs(texcoord.st);					//Gets material ids
	CalculateMasks(surface.mask);


if (surface.mask.water > 0.5)
	{
		surface.albedo *= 1.9;
	}
	surface.albedo *= 1.0f - float(surface.mask.sky); 						//Remove the sky from surface albedo, because sky will be handled separately




	//Initialize sky surface properties
	surface.sky.albedo 		= GetAlbedoLinear(texcoord.st) * (min(1.0f, float(surface.mask.sky) + float(surface.mask.sunspot)));							//Gets the albedo texture for the sky

	surface.sky.tintColor 	= mix(colorSunlight, vec3(colorSunlight.r), vec3(0.8f));									//Initializes the defualt tint color for the sky
	surface.sky.tintColor 	*= mix(1.0f, 100.0f, timeSkyDark); 														//Boost sky color at night																		//Scale sunglow back to be less intense

	surface.sky.sunSpot   	= vec3(float(CalculateSunspot(surface))) * vec3((min(1.0f, float(surface.mask.sky) + float(surface.mask.sunspot)))) * colorSunlight;
	surface.sky.sunSpot 	*= 1.0f - timeMidnight;
	surface.sky.sunSpot   	*= 300.0f;
	surface.sky.sunSpot 	*= 1.0f - rainStrength;

	AddSkyGradient(surface);
	AddSunglow(surface);



	//Initialize MCLightmap values
	mcLightmap.torch 		= GetLightmapTorch(texcoord.st);	//Gets the lightmap for light coming from emissive blocks


	mcLightmap.sky   		= GetLightmapSky(texcoord.st);		//Gets the lightmap for light coming from the sky

	mcLightmap.lightning    = 0.0f;								//gets the lightmap for light coming from lightning


	//Initialize default surface shading attributes
	surface.diffuse.roughness 			= 0.0f;					//Default surface roughness
	surface.diffuse.translucency 		= 0.0f;					//Default surface translucency
	surface.diffuse.translucencyColor 	= vec3(1.0f);			//Default translucency color

	surface.specular.specularity 		= GetSpecularity(texcoord.st);	//Gets the reflectance/specularity of the surface
	surface.specular.extraSpecularity 	= 0.0f;							//Default value for extra specularity
	surface.specular.glossiness 		= GetGlossiness(texcoord.st);
	surface.specular.metallic 			= 0.0f;							//Default value of how metallic the surface is
	surface.specular.gain 				= 1.0f;							//Default surface specular gain
	surface.specular.base 				= 0.0f;							//Default reflectance when the surface normal and viewing normal are aligned
	surface.specular.fresnelPower 		= 5.0f;							//Default surface fresnel power



#ifdef Global_Illumination
	//Calculate surface shading
	CalculateNdotL(surface);
	shading.direct  			= CalculateDirectLighting(surface);				//Calculate direct sunlight without visibility check (shadows)
	shading.sunlightVisibility 	= CalculateSunlightVisibility(surface, shading);					//Calculate shadows and apply them to direct lighting
	shading.direct 				*= shading.sunlightVisibility;
	shading.direct 				*= mix(1.0f, 0.0f, rainStrength);
	float caustics = 1.0;
	if (surface.mask.water > 0.5 || isEyeInWater > 0)
#ifdef WaterCaustics
		caustics = CalculateWaterCaustics(surface, shading);
#endif
	shading.direct *= caustics;
	shading.waterDirect 		= shading.direct;
	shading.direct 				*= pow(mcLightmap.sky, 0.1f);
	shading.skylight 	= CalculateSkylight(surface);					//Calculate scattered light from sky
	shading.skylight 	*= caustics * 0.2 + 0.8;
	shading.heldLight 	= CalculateHeldLightShading(surface);

	#else

	//Calculate surface shading
	CalculateNdotL(surface);
	shading.direct  			= CalculateDirectLighting(surface);				//Calculate direct sunlight without visibility check (shadows)
	shading.direct  			= mix(shading.direct, 1.0f, float(surface.mask.water)); //Remove shading from water
	shading.sunlightVisibility 	= CalculateSunlightVisibility(surface, shading);					//Calculate shadows and apply them to direct lighting
	shading.direct 				*= shading.sunlightVisibility;
	shading.direct 				*= mix(1.0f, 0.0f, rainStrength);
	float caustics = 1.0;
	if (surface.mask.water > 0.5 || isEyeInWater > 0)
#ifdef WaterCaustics
		caustics = CalculateWaterCaustics(surface, shading);
#endif
	shading.direct *= caustics;
	shading.waterDirect 		= shading.direct;
	shading.direct 				*= pow(mcLightmap.sky, 0.1f);
	shading.bounced 	= CalculateBouncedSunlight(surface);			//Calculate fake bounced sunlight
	shading.scattered 	= CalculateScatteredSunlight(surface);			//Calculate fake scattered sunlight
	shading.skylight 	= CalculateSkylight(surface);					//Calculate scattered light from sky
	shading.skylight 	*= caustics * 0.2 + 0.8;
	shading.scatteredUp = CalculateScatteredUpLight(surface);
	shading.heldLight 	= CalculateHeldLightShading(surface);

#endif


	InitializeAO(surface);
#ifdef Global_Illumination
float ao = 1.0;
	//if (texcoord.s < 0.5f && texcoord.t < 0.5f)
	//CalculateAO(surface);


	vec4 delta = vec4(0.0);
	delta.a = 1.0;

	delta = Delta(surface.albedo.rgb, surface.normal.xyz, mcLightmap.sky);

	ao = delta.a;
#endif


	//Colorize surface shading and store in lightmaps
	#ifdef Global_Illumination
	lightmap.sunlight 			= vec3(shading.direct) * colorSunlight;
	AddCloudGlow(lightmap.sunlight, surface);

	lightmap.skylight 			= vec3(mcLightmap.sky);
	lightmap.skylight 			*= mix(colorSkylight, colorBouncedSunlight, vec3(max(0.0f, (1.0f - pow(mcLightmap.sky + 0.1f, 0.45f) * 1.0f)))) + colorBouncedSunlight * (mix(Shadow_Brightness, 1.0f, wetness)) * (1.0f - rainStrength);
	lightmap.skylight 			*= shading.skylight;
	lightmap.skylight 			*= mix(1.0f, 5.0f, float(surface.mask.clouds));
	lightmap.skylight 			*= mix(1.0f, 50.0f, float(surface.mask.clouds) * timeSkyDark);
	lightmap.skylight 			+= vec3(0.5, 0.8, 1.0) * surface.mask.water * mcLightmap.sky * dot(vec3(0.3333), colorSunlight * colorSunlight) * 1.0;	//water ambient
	lightmap.skylight 			*= surface.ao.skylight;
	lightmap.skylight 			+= mix(colorSkylight, colorSunlight, vec3(0.2f)) * vec3(mcLightmap.sky) * surface.ao.constant * 0.05f;
	lightmap.skylight 			*= mix(1.0f, 1.2f, rainStrength);
	lightmap.skylight 			*= ao;



	lightmap.underwater 		= vec3(mcLightmap.sky) * colorSkylight;

	lightmap.torchlight 		= mcLightmap.torch * colorTorchlight;
	lightmap.torchlight 	 	*= surface.ao.constant * surface.ao.constant;
	lightmap.torchlight 		*= ao;

	lightmap.nolight 			= vec3(0.05f);
	lightmap.nolight 			*= surface.ao.constant;
	lightmap.nolight 			*= ao;


	lightmap.heldLight 			= vec3(shading.heldLight);
	lightmap.heldLight 			*= colorTorchlight;
	lightmap.heldLight 			*= heldBlockLightValue / 16.0f;

	#else

	lightmap.sunlight 			= vec3(shading.direct) * colorSunlight;
	AddCloudGlow(lightmap.sunlight, surface);

	lightmap.skylight 			= vec3(mcLightmap.sky);
	lightmap.skylight 			*= mix(colorSkylight, colorBouncedSunlight, vec3(max(0.0f, (1.0f - pow(mcLightmap.sky + 0.1f, 0.45f) * 1.0f)))) + colorBouncedSunlight * (mix(Shadow_Brightness, 1.0f, wetness)) * (1.0f - rainStrength);
	lightmap.skylight 			*= shading.skylight;
	lightmap.skylight 			*= mix(1.0f, 5.0f, float(surface.mask.clouds));
	lightmap.skylight 			*= mix(1.0f, 50.0f, float(surface.mask.clouds) * timeSkyDark);
	lightmap.skylight 			*= surface.ao.skylight;
	lightmap.skylight 			+= mix(colorSkylight, colorSunlight, vec3(0.2f)) * vec3(mcLightmap.sky) * surface.ao.constant * 0.05f;
	lightmap.skylight 			*= mix(1.0f, 1.2f, rainStrength);

	lightmap.bouncedSunlight	= vec3(shading.bounced) * colorBouncedSunlight;
	lightmap.bouncedSunlight 	*= pow(vec3(mcLightmap.sky), vec3(1.75f));
	lightmap.bouncedSunlight 	*= mix(1.0f, 0.25f, timeSunrise + timeSunset);
	lightmap.bouncedSunlight 	*= mix(1.0f, 0.0f, rainStrength);
	lightmap.bouncedSunlight 	*= surface.ao.bouncedSunlight;


	lightmap.scatteredSunlight  = vec3(shading.scattered) * colorScatteredSunlight * (1.0f - rainStrength);
	lightmap.scatteredSunlight 	*= pow(vec3(mcLightmap.sky), vec3(1.0f));

	lightmap.underwater 		= vec3(mcLightmap.sky) * colorSkylight;

	lightmap.torchlight 		= mcLightmap.torch * colorTorchlight;
	lightmap.torchlight 	 	*= surface.ao.constant * surface.ao.constant;

	lightmap.nolight 			= vec3(0.05f);
	lightmap.nolight 			*= surface.ao.constant;

	lightmap.scatteredUpLight 	= vec3(shading.scatteredUp) * mix(colorSunlight, colorSkylight, vec3(0.0f));
	lightmap.scatteredUpLight   *= pow(mcLightmap.sky, 0.5f);
	lightmap.scatteredUpLight 	*= surface.ao.scatteredUpLight;
	lightmap.scatteredUpLight 	*= mix(1.0f, 0.1f, rainStrength);

	lightmap.heldLight 			= vec3(shading.heldLight);
	lightmap.heldLight 			*= colorTorchlight;
	lightmap.heldLight 			*= heldBlockLightValue * 0.070f;

#endif




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
	const float sunlightMult = 1.25f;
#endif

	//Apply lightmaps to albedo and generate final shaded surface
	vec3 finalComposite = final.sunlight 			* 0.9f 	* 1.5f * sunlightMult				//Add direct sunlight
						+ final.skylight 			* 0.045f				//Add ambient skylight
						+ final.nolight 			* CAVE_BRIGHTNESS			//Add base ambient light
					#ifdef Global_Illumination
						+ final.bouncedSunlight 	* 0.05f 	* sunlightMult				//Add fake bounced sunlight
						+ final.scatteredSunlight 	* 0.02f		* sunlightMult			//Add fake scattered sunlight
						+ final.scatteredUpLight 	* 0.001f 	* sunlightMult
					#endif
						+ final.torchlight 			* 5.0f 			//Add light coming from emissive blocks
						+ final.glow.lava			* 2.6f
						+ final.glow.glowstone		* 2.1f
						+ final.glow.fire			* 0.35f
						+ final.glow.torch			* 1.15f
					#ifdef HELD_LIGHT
						+ final.heldLight 			* 0.05f
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
		 //delta.rgb = delta.rgb * sunlightMult * colorSunlight * (surface.cloudShadow * 0.9 + 0.1);
		 //delta.rgb *= 1.0 - surface.mask.water * 0.35;
		 //delta.rgb *= 1.0 - float(isEyeInWater) * 0.85;
		 //DoNightEye(delta.rgb);
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
/*
#ifdef NEW_UNDERWATER
	#ifdef ATMOSPHERIC_FOG
		if (isEyeInWater > 0) {
			//CalculateAtmosphericScattering(finalComposite.rgb, surface);
		} else {
			CalculateAtmosphericScattering(finalComposite.rgb, surface);
		}
	#endif
#else
	#ifdef ATMOSPHERIC_FOG
		CalculateAtmosphericScattering(finalComposite.rgb, surface);
	#endif
#endif
*/
//////////////////////////////////////


#ifdef VOLUMETRIC_CLOUDS
	CalculateClouds(finalComposite.rgb, surface);
#endif

#ifdef VOLUMETRIC_CLOUDS2
	CalculateClouds(finalComposite.rgb, surface);
#endif

#ifdef VOLUMETRIC_CLOUDS3
	CalculateClouds(finalComposite.rgb, surface);
#endif

	//finalComposite = mix(finalComposite, cloudsTexture.rgb, cloudsTexture.a);


	float volumetricLight = CrepuscularRays( surface );

	float Get2DGodRays = Rays( surface );



#ifdef Water_DepthFog
	WaterDepthFog(finalComposite, surface, mcLightmap);
#endif

	// finalComposite = texture2D(gaux1, texcoord.st).rgb * 0.001;

	finalComposite *= 0.0007f;												//Scale image down for HDR
	finalComposite.b *= 1.0f;



	 //TestRaymarch(finalComposite.rgb, surface);
	  //finalComposite.rgb = surface.debug * 0.00004f;

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

	//finalComposite *= ao;



vec4 finalCompositeCompiled = vec4(finalComposite, 1.0);

		#ifdef GODRAYS
			finalCompositeCompiled.a = Get2DGodRays;
		#endif

		#ifdef VOLUMETRIC_LIGHT
			finalCompositeCompiled.a = volumetricLight;
		#endif

	gl_FragData[0] = finalCompositeCompiled;
	gl_FragData[1] = vec4(surface.mask.matIDs, surface.shadow * surface.cloudShadow * pow(mcLightmap.sky, 0.2f), mcLightmap.sky, 1.0f);
	gl_FragData[2] = vec4(surface.specular.specularity, surface.cloudAlpha, surface.specular.glossiness, 1.0f);
	//gl_FragData[3] = vec4(crepuscularRays, 1.0, 1.0, 1.0f);
	// gl_FragData[4] = vec4(pow(surface.albedo.rgb, vec3(1.0f / 2.2f)), 1.0f);
	// gl_FragData[5] = vec4(surface.normal.rgb * 0.5f + 0.5f, 1.0f);

}
