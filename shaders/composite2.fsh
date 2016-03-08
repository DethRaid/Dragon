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
/////////////////////////CONFIGURABLE VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////CONFIGURABLE VARIABLES////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define BANDING_FIX_FACTOR 1.0f

#define SMOOTH_SKY


#define CLOUD_PLANE_Cloud			//New 2D clouds!
#define CLOUD_PLANE_Coverage 0.40f		// CLOUD_PLANE_Coverage. 0.20 = Lowest Cover. 0.60 = Highest Cover [0.20 0.30 0.40 0.50 0.60 0.70]
//#define CLOUD_COVERAGE CLOUD_PLANE_Coverage + rainy * 0.335f;		//Default is 0.49

#define Water_Refraction

#define VOLUMETRIC_LIGHT			//True GodRays, not 2D ScreenSpace
//----------GodRays----------//
#define GODRAYS
	#ifdef VOLUMETRIC_LIGHT
		float exposure = 0.00008;			//godrays intensity 0.0009 is default
	#else
		float exposure = 0.0009;
	#endif
	const float grdensity = 1.0;
	const int NUM_SAMPLES = 10;			//increase this for better quality at the cost of performance /8 is default
	const float Moon_exposure = 0.001;			//Moonrays intensity 0.0009 is default, increase to make brighter

#define MOONRAYS					//Make sure if you enable/disable this to do the same in Composite, PLEASE NOTE Moonrays have a bug at sunset/sunrise


//---Volumetric light strength--//
#define SUNRISEnSET		5.0	//default is 2.0
#define NOON			1.25		//default is 0.2 for least amount of haze at the cost of effect
#define NIGHT			0.65		//default is 0.7 for least amount of haze at the cost of effect, 1.5 for best looking but lots of haze
#define IN_SIDE_RAYS	2.5		//strength of rays when indoors, daytime
#define IN_SIDE_RAYS_NIGHT 100.3		//strength of rays when indoors, night


#define NO_UNDERWATER_RAYS


//----------End CONFIGURABLE GodRays----------//

/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////

/* DRAWBUFFERS:2 */

const bool gcolorMipmapEnabled = true;
const bool compositeMipmapEnabled = true;


uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D noisetex;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform int worldTime;
uniform int isEyeInWater;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;
uniform ivec2 eyeBrightnessSmooth;

varying vec4 texcoord;

varying vec3 lightVector;
varying vec3 upVector;
uniform vec3 sunPosition;

varying float timeSunriseSunset;
varying float timeSunrise;
varying float timeNoon;
varying float timeSunset;
varying float timeMidnight;
varying float timeSkyDark;

varying vec3 colorSunlight;
varying vec3 colorSkylight;

#define ANIMATION_SPEED 1.0f

//#define ANIMATE_USING_WORLDTIME

#ifdef ANIMATE_USING_WORLDTIME
	#define FRAME_TIME worldTime * ANIMATION_SPEED / 20.0f
#else
	#define FRAME_TIME frameTimeCounter * ANIMATION_SPEED
#endif


/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

float saturate(float x) {
	return clamp(x, 0.0, 1.0);
}

vec3 GetNormals(in vec2 coord) {
	vec3 normal = vec3(0.0f);
	normal = texture2DLod(gnormal, coord.st, 0).rgb;
	normal = normal * 2.0f - 1.0f;

	normal = normalize(normal);

	return normal;
}

float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

float ExpToLinearDepth(in float depth) {
	return 2.0f * near * far / (far + near - (2.0f * depth - 1.0f) * (far - near));
}

float GetDepthLinear(vec2 coord) {
    return 2.0 * near * far / (far + near - (2.0 * texture2D(gdepthtex, coord).x - 1.0) * (far - near));
}

vec4 GetViewSpacePosition(in vec2 coord) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
	float depth = GetDepth(coord);
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
	fragposition /= fragposition.w;

	return fragposition;
}

float GetMaterialIDs(in vec2 coord) {			//Function that retrieves the texture that has all material IDs stored in it
	return texture2D(gdepth, coord).r;
}

float GetSunlightVisibility(in vec2 coord) {
	return texture2D(gdepth, coord).g;
}

float cubicPulse(float c, float w, float x) {
	x = abs(x - c);
	if (x > w) return 0.0f;
	x /= w;

	return 1.0f - x * x * (3.0f - 2.0f * x);
}

bool GetMaterialMask(in vec2 coord, in int ID, in float matID) {
	matID = floor(matID * 255.0f);

	if (matID == ID) {
		return true;
	} else {
		return false;
	}
}

bool GetSkyMask(in vec2 coord, in float matID) {
	matID = floor(matID * 255.0f);

	if (matID < 1.0f || matID > 254.0f)
	{
		return true;
	} else {
		return false;
	}
}

float GetMetallic(in vec2 coord) {
	return texture2D(composite, coord).r;
}

float GetSmoothness(in vec2 coord) {
	return pow(texture2D(composite, coord).b, 2.2);
}

bool GetWaterMask(in float matID) {					//Function that returns "true" if a pixel is water, and "false" if a pixel is not water.
	matID = floor(matID * 255.0f);

	if (matID >= 35.0f && matID <= 51) {
		return true;
	} else {
		return false;
	}
}

bool GetWaterMask(in vec2 coord) {					//Function that returns "true" if a pixel is water, and "false" if a pixel is not water.
	float matID = floor(GetMaterialIDs(coord) * 255.0f);

	if (matID >= 35.0f && matID <= 51) {
		return true;
	} else {
		return false;
	}
}

float GetWaterMaskFloat(in vec2 coord) {
	float matID = floor(GetMaterialIDs(coord) * 255.0f);

	if (matID >= 35.0f && matID <= 51) {
		return 0.0;
	} else {
		return 1.0;
	}
}

float GetLightmapSky(in vec2 coord) {
	return texture2D(gdepth, texcoord.st).b;
}

vec3 convertScreenSpaceToWorldSpace(vec2 co) {
    vec4 fragposition = gbufferProjectionInverse * vec4(vec3(co, texture2DLod(gdepthtex, co, 0).x) * 2.0 - 1.0, 1.0);
    fragposition /= fragposition.w;

    return fragposition.xyz;
}

vec3 convertCameraSpaceToScreenSpace(vec3 cameraSpace) {
    vec4 clipSpace = gbufferProjection * vec4(cameraSpace, 1.0);
    vec3 NDCSpace = clipSpace.xyz / clipSpace.w;
    vec3 screenSpace = 0.5 * NDCSpace + 0.5;
		screenSpace.z = 0.1f;

    return screenSpace;
}

vec3 	CalculateNoisePattern1(vec2 offset, float size) {
	vec2 coord = texcoord.st;

	coord *= vec2(viewWidth, viewHeight);
	coord = mod(coord + offset, vec2(size));
	coord /= 64.0f;

	return texture2D(noisetex, coord).xyz;
}

float noise(in float offset) {
	vec2 coord = texcoord.st + vec2(offset);
	float noise = clamp(fract(sin(dot(coord ,vec2(12.9898f,78.233f))) * 43758.5453f),0.0f,1.0f)*2.0f-1.0f;
	return noise;
}

float noise(in vec2 coord, in float offset) {
	coord += vec2(offset);
	float noise = clamp(fract(sin(dot(coord ,vec2(12.9898f,78.233f))) * 43758.5453f),0.0f,1.0f)*2.0f-1.0f;

	return noise;
}

void 	DoNightEye(inout vec3 color) {					//Desaturates any color input at night, simulating the rods in the human eye
	float amount = 0.8f; 												//How much will the new desaturated and tinted image be mixed with the original image
	vec3 rodColor = vec3(0.2f, 0.5f, 1.0f); 		//Cyan color that humans percieve when viewing extremely low light levels via rod cells in the eye
	float colorDesat = dot(color, vec3(1.0f)); 	//Desaturated color

	color = mix(color, vec3(colorDesat) * rodColor, timeSkyDark * amount);
}

float Get3DNoise(in vec3 pos) {
	return texture2D(noisetex, pos.xz / 64.0f).x;
}


/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct MaskStruct {

	float matIDs;

	bool sky;
	bool land;
	bool tallGrass;
	bool leaves;
	bool ice;
	bool hand;
	bool translucent;
	bool glow;
	bool goldBlock;
	bool ironBlock;
	bool diamondBlock;
	bool emeraldBlock;
	bool sand;
	bool sandstone;
	bool stone;
	bool cobblestone;
	bool wool;

	bool torch;
	bool lava;
	bool glowstone;
	bool fire;

	bool water;

};

struct Ray {
	vec3 dir;
	vec3 origin;
};

struct Plane {
	vec3 normal;
	vec3 origin;
};

struct SurfaceStruct {
	MaskStruct 		mask;			//Material ID Masks

	//Properties that are required for lighting calculation
		vec3 	color;					//Diffuse texture aka "color texture"
		vec3 	normal;					//Screen-space surface normals
		float 	depth;					//Scene depth
		float 	linearDepth;			//Scene depth

		float 	rDepth;
		float  	metallic;
		vec3 	metallicColor;
		float 	smoothness;
		float   fresnelPower;
		Ray 	viewRay;

		vec4 	viewSpacePosition;
		vec4 	worldSpacePosition;
		vec3 	worldLightVector;
		vec3  	upVector;
		vec3 	lightVector;

		float 	sunlightVisibility;

		vec4 	reflection;

		float 	cloudAlpha;
} surface;

struct Intersection {
	vec3 pos;
	float distance;
	float angle;
};

/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

void 	CalculateMasks(inout MaskStruct mask) {
	mask.sky 			= GetSkyMask(texcoord.st, mask.matIDs);
	mask.land	 		= !mask.sky;
	mask.tallGrass 		= GetMaterialMask(texcoord.st, 2, mask.matIDs);
	mask.leaves	 		= GetMaterialMask(texcoord.st, 3, mask.matIDs);
	mask.ice		 	= GetMaterialMask(texcoord.st, 4, mask.matIDs);
	mask.hand	 		= GetMaterialMask(texcoord.st, 5, mask.matIDs);
	mask.translucent	= GetMaterialMask(texcoord.st, 6, mask.matIDs);

	mask.glow	 		= GetMaterialMask(texcoord.st, 10, mask.matIDs);

	mask.goldBlock 		= GetMaterialMask(texcoord.st, 20, mask.matIDs);
	mask.ironBlock 		= GetMaterialMask(texcoord.st, 21, mask.matIDs);
	mask.diamondBlock	= GetMaterialMask(texcoord.st, 22, mask.matIDs);
	mask.emeraldBlock	= GetMaterialMask(texcoord.st, 23, mask.matIDs);
	mask.sand	 		= GetMaterialMask(texcoord.st, 24, mask.matIDs);
	mask.sandstone 		= GetMaterialMask(texcoord.st, 25, mask.matIDs);
	mask.stone	 		= GetMaterialMask(texcoord.st, 26, mask.matIDs);
	mask.cobblestone	= GetMaterialMask(texcoord.st, 27, mask.matIDs);
	mask.wool			= GetMaterialMask(texcoord.st, 28, mask.matIDs);

	mask.torch 			= GetMaterialMask(texcoord.st, 30, mask.matIDs);
	mask.lava 			= GetMaterialMask(texcoord.st, 31, mask.matIDs);
	mask.glowstone 		= GetMaterialMask(texcoord.st, 32, mask.matIDs);
	mask.fire 			= GetMaterialMask(texcoord.st, 33, mask.matIDs);

	mask.water 			= GetWaterMask(mask.matIDs);
}

vec4 ComputeRaytraceReflection(inout SurfaceStruct surface) {
	float reflectionRange = 2.0f;
  	float initialStepAmount = 1.0 - clamp(1.0f / 100.0, 0.0, 0.99);
	initialStepAmount *= 1.0f;

	float stepRefinementAmount = .1;
	int maxRefinements = 0;

	vec2 screenSpacePosition2D = texcoord.st;
  	vec3 cameraSpacePosition = convertScreenSpaceToWorldSpace(screenSpacePosition2D);

	vec3 cameraSpaceNormal = surface.normal;

	vec3 cameraSpaceViewDir = normalize(cameraSpacePosition);
	vec3 cameraSpaceVector = initialStepAmount * normalize(reflect(cameraSpaceViewDir,cameraSpaceNormal));
	vec3 oldPosition = cameraSpacePosition;
	vec3 cameraSpaceVectorPosition = oldPosition + cameraSpaceVector;
	vec3 currentPosition = convertCameraSpaceToScreenSpace(cameraSpaceVectorPosition);
	vec4 color = vec4(pow(texture2D(gcolor, screenSpacePosition2D).rgb, vec3(3.0f + 1.2f)), 0.0);
	int numRefinements = 0;
	int count = 0;
	vec2 finalSamplePos = vec2(0.0f);

  	while(count < far/initialStepAmount*reflectionRange) {
    	if(currentPosition.x < 0 || currentPosition.x > 1 ||
           currentPosition.y < 0 || currentPosition.y > 1 ||
		   currentPosition.z < 0 || currentPosition.z > 1) {
		    break;
		}

    	vec2 samplePos = currentPosition.xy;
    	float sampleDepth = convertScreenSpaceToWorldSpace(samplePos).z;

	    float currentDepth = cameraSpaceVectorPosition.z;
	    float diff = sampleDepth - currentDepth;
	    float error = length(cameraSpaceVector);

	    if(diff >= 0 && diff <= error * 1.00f) {
			finalSamplePos = samplePos;
			break;
		}

		cameraSpaceVector *= 2.5f;	//Each step gets bigger
    	cameraSpaceVectorPosition += cameraSpaceVector;
		currentPosition = convertCameraSpaceToScreenSpace(cameraSpaceVectorPosition);
    	count++;
  	}

	float distance_travelled = length(oldPosition - currentPosition);
	float r = float(distance_travelled) + 4.0f;
	r *= (1.0 - surface.smoothness) * 0.8f;

	color = pow(texture2DLod(gcolor, finalSamplePos, r), vec4(2.2f));

	#ifdef GODRAYS
		color.a = 1.0;
	#endif

	#ifdef VOLUMETRIC_LIGHT
		color.a = 1.0;
	#endif

	if (finalSamplePos.x == 0.0f || finalSamplePos.y == 0.0f) {
		color.a = 0.0f;
	}

	color.a *= clamp(1 - pow(distance(vec2(0.5), finalSamplePos)*2.0, 2.0), 0.0, 1.0);
  	return color;
}

float CalculateLuminance(in vec3 color) {
	return (color.r * 0.2126f + color.g * 0.7152f + color.b * 0.0722f);
}

float CalculateSunglow(in SurfaceStruct surface) {
	float curve = 4.0f;

	vec3 npos = normalize(surface.viewSpacePosition.xyz);
	vec3 halfVector2 = normalize(-surface.lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

float CalculateReflectedSunglow(in SurfaceStruct surface) {
	float curve = 4.0f;

	vec3 npos = normalize(surface.viewSpacePosition.xyz);
	surface.lightVector = reflect(surface.lightVector, surface.normal);
	vec3 halfVector2 = normalize(-surface.lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

float CalculateAntiSunglow(in SurfaceStruct surface) {
	float curve = 4.0f;

	vec3 npos = normalize(surface.viewSpacePosition.xyz);
	vec3 halfVector2 = normalize(surface.lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

float CalculateSunspot(in SurfaceStruct surface) {
	float curve = 1.0f;

	vec3 npos = normalize(surface.viewSpacePosition.xyz);
	vec3 halfVector2 = normalize(-surface.lightVector + npos);

	float sunProximity = abs(1.0f - dot(halfVector2, npos));

	float sizeFactor = surface.smoothness * 0.7f;

	float sunSpot = (clamp(sunProximity, sizeFactor, 0.96f) - sizeFactor) / (0.96f - sizeFactor);
	sunSpot = pow(cubicPulse(1.0f, 1.0f, sunSpot), 2.0f);

	float result = sunSpot / ((1.0 - surface.smoothness) * 20.0f + 0.1f);
	result *= surface.sunlightVisibility;

	return result;
}

vec3 ComputeReflectedSkyGradient(in SurfaceStruct surface) {
	float curve = 5.0f;
	surface.viewSpacePosition.xyz = reflect(surface.viewSpacePosition.xyz, surface.normal);
	vec3 npos = normalize(surface.viewSpacePosition.xyz);

	vec3 halfVector2 = normalize(-surface.upVector + npos);
	float skyGradientFactor = dot(halfVector2, npos);
	float skyGradientRaw = skyGradientFactor;
	float skyDirectionGradient = skyGradientFactor;

	if (dot(halfVector2, npos) > 0.75)
		skyGradientFactor = 1.5f - skyGradientFactor;

	skyGradientFactor = pow(skyGradientFactor, curve);

	vec3 skyColor = CalculateLuminance(pow(gl_Fog.color.rgb, vec3(2.2f))) * colorSkylight;

	skyColor *= mix(skyGradientFactor, 1.0f, clamp((0.12f - (timeNoon * 0.1f)) + rainStrength, 0.0f, 1.0f));
	skyColor *= pow(skyGradientFactor, 2.5f) + 0.2f;
	skyColor *= (pow(skyGradientFactor, 1.1f) + 0.425f) * 0.5f;
	skyColor.g *= skyGradientFactor * 3.0f + 1.0f;

	vec3 linFogColor = pow(gl_Fog.color.rgb, vec3(2.2f));

	float fogLum = max(max(linFogColor.r, linFogColor.g), linFogColor.b);

	float fadeSize = 0.0f;

	float fade1 = clamp(skyGradientFactor - 0.05f - fadeSize, 0.0f, 0.2f + fadeSize) / (0.2f + fadeSize);
	fade1 = fade1 * fade1 * (3.0f - 2.0f * fade1);
	vec3 color1 = vec3(5.0f, 2.0, 0.7f) * 0.25f;
	color1 = mix(color1, vec3(1.0f, 0.55f, 0.2f), vec3(timeSunrise + timeSunset));

	skyColor *= mix(vec3(1.0f), color1, vec3(fade1));

	float fade2 = clamp(skyGradientFactor - 0.11f - fadeSize, 0.0f, 0.2f + fadeSize) / (0.2f + fadeSize);
	vec3 color2 = vec3(1.7f, 1.0f, 0.8f) * 0.5f;
	color2 = mix(color2, vec3(1.0f, 0.15f, 0.5f), vec3(timeSunrise + timeSunset));

	skyColor *= mix(vec3(1.0f), color2, vec3(fade2 * 0.5f));

	float horizonGradient = 1.0f - distance(skyDirectionGradient, 0.72f + fadeSize) / (0.72f + fadeSize);
	horizonGradient = pow(horizonGradient, 10.0f);
	horizonGradient = max(0.0f, horizonGradient);

	float sunglow = CalculateSunglow(surface);
	horizonGradient *= sunglow * 2.0f+ (0.65f - timeSunrise * 0.55f - timeSunset * 0.55f);

	vec3 horizonColor1 = vec3(1.5f, 1.5f, 1.5f);
	horizonColor1 = mix(horizonColor1, vec3(1.5f, 1.95f, 0.5f) * 2.0f, vec3(timeSunrise + timeSunset));

	vec3 horizonColor2 = vec3(1.5f, 1.2f, 0.8f) * 1.0f;
	horizonColor2 = mix(horizonColor2, vec3(1.9f, 0.6f, 0.4f) * 2.0f, vec3(timeSunrise + timeSunset));

	skyColor *= mix(vec3(1.0f), horizonColor1, vec3(horizonGradient) * (1.0f - timeMidnight));
	skyColor *= mix(vec3(1.0f), horizonColor2, vec3(pow(horizonGradient, 2.0f)) * (1.0f - timeMidnight));

	float grayscale = fogLum / 20.0f;
	grayscale /= 3.0f;

	float rainSkyBrightness = 1.2f;
	rainSkyBrightness *= mix(0.05f, 10.0f, timeMidnight);

	skyColor = mix(skyColor, vec3(grayscale * colorSkylight.r) * 0.06f * vec3(0.85f, 0.85f, 1.0f), vec3(rainStrength));
	skyColor /= fogLum;

	float antiSunglow = CalculateAntiSunglow(surface);

	skyColor *= 1.0f + pow(sunglow, 1.1f) * (7.0f + timeNoon * 1.0f) * (1.0f - rainStrength);
	skyColor *= mix(vec3(1.0f), colorSunlight * 11.0f, clamp(vec3(sunglow) * (1.0f - timeMidnight) * (1.0f - rainStrength), vec3(0.0f), vec3(1.0f)));
	skyColor *= 1.0f + antiSunglow * 2.0f * (1.0f - rainStrength);

	if (surface.mask.water) {
		vec3 sunspot = vec3(CalculateSunspot(surface)) * colorSunlight;
		sunspot *= 50.0f;
		sunspot *= 1.0f - timeMidnight;
		sunspot *= 1.0f - rainStrength;

		skyColor += sunspot;
	}

	skyColor *= pow(1.0f - clamp(skyGradientRaw - 0.75f, 0.0f, 0.25f) / 0.25f, 3.0f);
	skyColor *= mix(1.0f, 4.5f, timeNoon);

	return skyColor;
}

vec3 ComputeReflectedSkybox(in SurfaceStruct surface) {
	float curve = 3.0f;
	vec3 npos = normalize(surface.worldSpacePosition.xyz);

	surface.upVector = reflect(upVector, surface.normal);
	surface.lightVector = reflect(lightVector, surface.normal);

	vec3 halfVector2 = normalize(-surface.upVector + npos);
	float skyGradientFactor = dot(halfVector2, npos);
	float skyGradientRaw = skyGradientFactor;
	float skyDirectionGradient = skyGradientFactor;

	skyGradientFactor = pow(skyGradientFactor, curve);

	vec3 skyColor = CalculateLuminance(pow(gl_Fog.color.rgb, vec3(2.2f))) * colorSkylight;
	skyColor *= mix(skyGradientFactor, 1.0f, clamp((0.12f - (timeNoon * 0.1f)) + rainStrength, 0.0f, 1.0f));
	skyColor *= pow(skyGradientFactor, 2.5f) + 0.2f;
	skyColor *= (pow(skyGradientFactor, 1.1f) + 0.425f) * 0.5f;
	skyColor.g *= skyGradientFactor * 3.0f + 1.0f;

	vec3 skyBlueColor = vec3(0.5f, 0.6f, 1.0f) * 1.5f;

	float fade1 = clamp(skyGradientFactor - 0.15f, 0.0f, 0.2f) / 0.2f;
	vec3 color1 = vec3(1.0f, 1.3, 1.0f);

	skyColor *= mix(skyBlueColor, color1, vec3(fade1));

	float fade2 = clamp(skyGradientFactor - 0.18f, 0.0f, 0.2f) / 0.2f;
	vec3 color2 = vec3(1.7f, 1.0f, 0.8f);

	skyColor *= mix(vec3(1.0f), color2, vec3(fade2 * 0.5f));

	float horizonGradient = 1.0f - distance(skyDirectionGradient, 0.72f) / 0.72f;
	horizonGradient = pow(horizonGradient, 10.0f);
	horizonGradient = max(0.0f, horizonGradient);

	float sunglow = CalculateSunglow(surface);
	horizonGradient *= sunglow * 2.0f+ (0.65f - timeSunrise * 0.55f - timeSunset * 0.55f);

	vec3 horizonColor1 = vec3(1.5f, 1.5f, 1.5f);
	horizonColor1 = mix(horizonColor1, vec3(1.5f, 1.95f, 1.5f) * 2.0f, vec3(timeSunrise + timeSunset));

	vec3 horizonColor2 = vec3(1.5f, 1.2f, 0.8f) * 1.0f;
	horizonColor2 = mix(horizonColor2, vec3(1.9f, 0.6f, 0.4f) * 2.0f, vec3(timeSunrise + timeSunset));

	skyColor *= mix(vec3(1.0f), horizonColor1, vec3(horizonGradient));
	skyColor *= mix(vec3(1.0f), horizonColor2, vec3(pow(horizonGradient, 2.0f)));

	float grayscale = skyColor.r + skyColor.g + skyColor.b;
	grayscale /= 3.0f;

	skyColor = mix(skyColor, vec3(grayscale), vec3(rainStrength));

	float antiSunglow = CalculateAntiSunglow(surface);

	skyColor *= 1.0f + sunglow * (10.0f + timeNoon * 5.0f) * (1.0f - rainStrength);
	skyColor *= mix(vec3(1.0f), colorSunlight, clamp(vec3(sunglow) * (1.0f - timeMidnight) * (1.0f - rainStrength), vec3(0.0f), vec3(1.0f)));
	skyColor *= 1.0f + antiSunglow * 2.0f * (1.0f - rainStrength);

	vec3 sunspot = vec3(CalculateSunspot(surface)) * colorSunlight;
	sunspot *= 1500.0f;
	sunspot *= 1.0f - timeMidnight;
	sunspot *= 1.0f - rainStrength;

	skyColor += sunspot;

	vec3 skyTintColor = mix(colorSunlight, vec3(colorSunlight.r), vec3(0.8f));
	skyTintColor *= mix(1.0f, 1.0f, timeMidnight);

	skyColor *= skyTintColor;
	skyColor *= pow(1.0f - clamp(skyGradientRaw - 0.75f, 0.0f, 0.25f) / 0.25f, 3.0f);

	return skyColor;
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


float GetCoverage(in float coverage, in float density, in float clouds) {
	clouds = clamp(clouds - (1.0f - coverage), 0.0f, 1.0f - density) / (1.0f - density);
	clouds = max(0.0f, clouds * 1.1f - 0.1f);
	clouds = clouds = clouds * clouds * (3.0f - 2.0f * clouds);

	return clouds;
}

vec4 CloudColor2(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector, in float altitude, in float thickness, const bool isShadowPass) {
	float cloudHeight = altitude;
	float cloudDepth  = thickness;
	float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
	float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

	worldPosition.xz /= 1.0f + max(0.0f, length(worldPosition.xz - cameraPosition.xz) / 5000.0f);

	vec3 p = worldPosition.xyz / 150.0f;
	float t = frameTimeCounter * 0.25f;

	p += (Get3DNoise(p * 2.0f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.1f;
	p.z -= (Get3DNoise(p * 0.25f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.5f;
	p.x -= (Get3DNoise(p * 0.125f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 1.2f;
	p.xz -= (Get3DNoise(p * 0.0525f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 1.7f;


	p.x *= 0.5f;
	p.x -= t * 0.01f;

	vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
	float noise  = 	Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));	p *= 2.0f;	p.x -= t * 0.057f;	vec3 p2 = p;
	noise += (2.0f - abs(Get3DNoise(p) * 2.0f - 0.0f)) * (0.55f);	p *= 3.0f;	p.xz -= t * 0.035f;	p.x *= 2.0f;	vec3 p3 = p;
	noise += (3.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * (0.085f); p *= 3.0f;	p.xz -= t * 0.035f;	vec3 p4 = p;
	noise += (3.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * (0.045f); p *= 3.0f;	p.xz -= t * 0.035f;

	if (!isShadowPass) {
		noise += ((Get3DNoise(p))) * (0.049f);
		p *= 3.0f;
		noise += ((Get3DNoise(p))) * (0.024f);
	}

	noise /= 2.175f;

	//cloud edge
	float rainy = mix(wetness, 1.0f, rainStrength);

	float coverage = CLOUD_PLANE_Coverage + rainy * 0.335f;
	coverage = mix(coverage, 0.87f, rainStrength);

	float dist = length(worldPosition.xz - cameraPosition.xz);
	coverage *= max(0.0f, 1.0f - dist / mix(7000.0f, 3000.0f, rainStrength));
	float density = 0.0f;

	if (isShadowPass) {
		return vec4(GetCoverage(coverage + 0.2f, density + 0.2f, noise));
	}

	noise = GetCoverage(coverage, density, noise);

	const float lightOffset = 0.2f;

	float sundiff = Get3DNoise(p1 + worldLightVector.xyz * lightOffset);
	sundiff += (2.0f - abs(Get3DNoise(p2 + worldLightVector.xyz * lightOffset / 2.0f) * 2.0f - 0.0f)) * (0.55f);

	float largeSundiff = sundiff;
	largeSundiff = -GetCoverage(coverage, 0.0f, largeSundiff * 1.3f);

	sundiff += (3.0f - abs(Get3DNoise(p3 + worldLightVector.xyz * lightOffset / 5.0f) * 3.0f - 0.0f)) * (0.055f);
	sundiff += (3.0f - abs(Get3DNoise(p4 + worldLightVector.xyz * lightOffset / 8.0f) * 3.0f - 0.0f)) * (0.025f);
	sundiff /= 1.5f;
	sundiff = -GetCoverage(coverage * 1.0f, 0.0f, sundiff);

	float secondOrder 	= pow(clamp(sundiff * 1.1f + 1.35f, 0.0f, 1.0f), 7.0f);
	float firstOrder 	= pow(clamp(largeSundiff * 1.1f + 1.56f, 0.0f, 1.0f), 3.0f);

	float directLightFalloff = firstOrder * secondOrder;
	float anisoBackFactor = mix(clamp(pow(noise, 1.6f) * 2.5f, 0.0f, 1.0f), 1.0f, pow(sunglow, 1.0f));

	directLightFalloff *= anisoBackFactor;
	directLightFalloff *= mix(1.5f, 1.0f, pow(sunglow, 0.5f));



	vec3 colorDirect = colorSunlight * 100.915f;
	colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.5f, 1.0f), timeMidnight);
	colorDirect *= 1.0f + pow(sunglow, 5.0f) * 600.0f * pow(directLightFalloff, 1.1f) * (1.0f - rainStrength);


	vec3 colorAmbient = mix(colorSkylight, colorSunlight * 2.0f, vec3(0.15f)) * 0.07f;
	colorAmbient *= mix(1.0f, 0.3f, timeMidnight);
	colorAmbient = mix(colorAmbient, colorAmbient * 3.0f + colorSunlight * 0.05f, vec3(clamp(pow(1.0f - noise, 12.0f) * 1.0f, 0.0f, 1.0f)));


	directLightFalloff *= 2.0f;
	directLightFalloff *= mix(1.0, 0.125, rainStrength);

	vec3 color = mix(colorAmbient, colorDirect, vec3(min(1.0f, directLightFalloff)));

	vec4 result = vec4(color.rgb, noise);

	return result;
}

void ReflectedCloudPlane(inout vec3 color, inout SurfaceStruct surface) {
	//Initialize view ray
	vec3 viewVector = normalize(surface.viewSpacePosition.xyz);
	viewVector = reflect(viewVector, surface.normal.xyz);
	vec4 worldVector = gbufferModelViewInverse * (vec4(-viewVector.xyz, 0.0f));

	surface.viewRay.dir = normalize(worldVector.xyz);
	surface.viewRay.origin = vec3(0.0f);

	float sunglow = CalculateReflectedSunglow(surface);

	float cloudsAltitude = 540.0f;
	float cloudsThickness = 150.0f;

	float cloudsUpperLimit = cloudsAltitude + cloudsThickness * 0.5f;
	float cloudsLowerLimit = cloudsAltitude - cloudsThickness * 0.5f;

	float density = 1.0f;

	float planeHeight = cloudsUpperLimit;
	float stepSize = 25.5f;
	planeHeight -= cloudsThickness * 0.85f;

	Plane pl;
	pl.origin = vec3(0.0f, cameraPosition.y - planeHeight, 0.0f);
	pl.normal = vec3(0.0f, 1.0f, 0.0f);

	Intersection i = RayPlaneIntersectionWorld(surface.viewRay, pl);

	if (i.angle < 0.0f) {
		vec4 cloudSample = CloudColor2(vec4(i.pos.xyz * 0.5f + vec3(30.0f), 1.0f), sunglow, surface.worldLightVector, cloudsAltitude, cloudsThickness, false);
		cloudSample.a = min(1.0f, cloudSample.a * density);

		color.rgb = mix(color.rgb, cloudSample.rgb * 0.18f, cloudSample.a);

		cloudSample = CloudColor2(vec4(i.pos.xyz * 0.65f + vec3(10.0f) + vec3(i.pos.z * 0.5f, 0.0f, 0.0f), 1.0f), sunglow, surface.worldLightVector, cloudsAltitude, cloudsThickness, false);
		cloudSample.a = min(1.0f, cloudSample.a * density);

		color.rgb = mix(color.rgb, cloudSample.rgb * 0.18f, cloudSample.a);
	}
}

void CloudPlane(inout SurfaceStruct surface) {
	//Initialize view ray
	vec4 worldVector = gbufferModelViewInverse * (-GetViewSpacePosition(texcoord.st));

	surface.viewRay.dir = normalize(worldVector.xyz);
	surface.viewRay.origin = vec3(0.0f);

	float sunglow = CalculateSunglow(surface);

	float cloudsAltitude = 540.0f;
	float cloudsThickness = 150.0f;

	float cloudsUpperLimit = cloudsAltitude + cloudsThickness * 0.5f;
	float cloudsLowerLimit = cloudsAltitude - cloudsThickness * 0.5f;

	float density = 1.0f;

	float planeHeight = cloudsUpperLimit;
	float stepSize = 25.5f;
	planeHeight -= cloudsThickness * 0.85f;

	Plane pl;
	pl.origin = vec3(0.0f, cameraPosition.y - planeHeight, 0.0f);
	pl.normal = vec3(0.0f, 1.0f, 0.0f);

	Intersection i = RayPlaneIntersectionWorld(surface.viewRay, pl);

	vec3 original = surface.color.rgb;

	if (i.angle < 0.0f) {
		if (i.distance < surface.linearDepth || surface.mask.sky) {
			vec4 cloudSample = CloudColor2(vec4(i.pos.xyz * 0.5f + vec3(30.0f), 1.0f), sunglow, surface.worldLightVector, cloudsAltitude, cloudsThickness, false);
			cloudSample.a = min(1.0f, cloudSample.a * density);

			surface.color.rgb = mix(surface.color.rgb, cloudSample.rgb * 0.001f, cloudSample.a);

			cloudSample = CloudColor2(vec4(i.pos.xyz * 0.65f + vec3(210.0f) + vec3(i.pos.z * 0.5f, 0.0f, 0.0f), 1.0f), sunglow, surface.worldLightVector, cloudsAltitude, cloudsThickness, false);
			cloudSample.a = min(1.0f, cloudSample.a * density);

			surface.color.rgb = mix(surface.color.rgb, cloudSample.rgb * 0.001f, cloudSample.a);
		}
	}

	surface.color.rgb = mix(surface.color.rgb, original, surface.cloudAlpha);
}


vec4 ComputeFakeSkyReflection(in SurfaceStruct surface) {
	float fresnelPower = 4.0f;

	vec3 cameraSpacePosition = convertScreenSpaceToWorldSpace(texcoord.st);
	vec3 cameraSpaceNormal = surface.normal;
	vec3 cameraSpaceViewDir = normalize(cameraSpacePosition);
	vec4 color = vec4(0.0f);

	color.rgb = ComputeReflectedSkyGradient(surface);
	ReflectedCloudPlane(color.rgb, surface);
	color.rgb *= 0.006f;
	color.rgb *= mix(1.0f, 20000.0f, timeSkyDark);

	float viewVector = dot(cameraSpaceViewDir, cameraSpaceNormal);

	color.a = pow(clamp(1.0f + viewVector, 0.0f, 1.0f), fresnelPower) * 1.0f + 0.02f;

	if (viewVector > 0.0f) {
		color.a = 1.0f - pow(clamp(viewVector, 0.0f, 1.0f), 1.0f / fresnelPower) * 1.0f + 0.02f;
		color.rgb = vec3(0.0f);
	}

	return color;
}

void CalculateSmoothnessReflections(inout SurfaceStruct surface) {
	surface.metallicColor = mix(vec3(0.14f), surface.color * 5000000, surface.metallic);

	bool defaultItself = false;

	surface.rDepth = 0.0f;

	if(surface.mask.sky) {
		return;
	}

	if(surface.mask.water) {
		surface.smoothness = 0.99f;
	}

	vec4 reflection = ComputeRaytraceReflection(surface);

	float surfaceLightmap = GetLightmapSky(texcoord.st);

	vec4 fakeSkyReflection = ComputeFakeSkyReflection(surface);

	vec3 noSkyToReflect = vec3(0.0f);

	if (defaultItself) {
		noSkyToReflect = surface.color.rgb;
	}

	fakeSkyReflection.rgb = mix(noSkyToReflect, fakeSkyReflection.rgb, clamp(surfaceLightmap * 16 - 5, 0.0f, 1.0f));
	reflection.rgb = mix(reflection.rgb, fakeSkyReflection.rgb, pow(vec3(1.0f - reflection.a), vec3(10.1f)));
	reflection.a = fakeSkyReflection.a;
	reflection.a *= surface.smoothness;

	reflection.rgb *= surface.metallicColor;

	surface.color.rgb = mix(surface.color.rgb, reflection.rgb, vec3(reflection.a));
	surface.reflection = reflection;
}

void CalculateSmoothnessHighlight(inout SurfaceStruct surface) {
	if (!surface.mask.sky && !surface.mask.water) {

		vec3 halfVector = normalize(lightVector - normalize(surface.viewSpacePosition.xyz));
		float HdotN = max(0.0f, dot(halfVector, surface.normal.xyz));

		float gloss = surface.smoothness;

		HdotN = clamp(HdotN * (1.0f + gloss * 0.01f), 0.0f, 1.0f);

		float spec = pow(HdotN, gloss * 8000.0f + 10.0f);

		float fresnel = pow(clamp(1.0f + dot(normalize(surface.viewSpacePosition.xyz), surface.normal.xyz), 0.0f, 1.0f), surface.fresnelPower);

		spec *= fresnel;
		spec *= surface.sunlightVisibility;

		spec *= gloss * 9000.0f + 10.0f;
		spec *= 1.0f - rainStrength;

		vec3 specularHighlight = spec * mix(colorSunlight, vec3(0.2f, 0.5f, 1.0f) * 0.0005f, vec3(timeMidnight)) * ((surface.color * 50000) + surface.metallicColor) * surface.smoothness;

		surface.color += specularHighlight / 500.0;
	}
}

vec4 TextureSmooth(in sampler2D tex, in vec2 coord, in int level) {
	vec2 res = vec2(viewWidth, viewHeight);
	coord = coord * res + 0.5f;

	vec2 i = floor(coord);
	vec2 f = fract(coord);

	f = f * f * (3.0f - 2.0f * f);

	coord = i + f;
	coord = (coord - 0.5f) / res;

	return texture2D(tex, coord, level);
}

void SmoothSky(inout SurfaceStruct surface) {
	const float cloudHeight = 170.0f;
	const float cloudDepth = 60.0f;
	const float cloudMaxHeight = cloudHeight + cloudDepth * 0.5f;
	const float cloudMinHeight = cloudHeight - cloudDepth * 0.5f;

	float cameraHeight = cameraPosition.y;
	float surfaceHeight = surface.worldSpacePosition.y;

	vec3 combined = pow(TextureSmooth(gcolor, texcoord.st, 2).rgb, vec3(2.2f));
	vec3 original = surface.color;

	if (surface.cloudAlpha > 0.0001f) {
		surface.color = combined;
	}

	if (cameraHeight < cloudMinHeight && surfaceHeight < cloudMinHeight - 10.0f && surface.mask.land) {
		surface.color = original;
	}

	if (cameraHeight > cloudMaxHeight && surfaceHeight > cloudMaxHeight && surface.mask.land) {
		surface.color = original;
	}
}

void FixNormals(inout vec3 normal, in vec3 viewPosition) {
	vec3 V = normalize(viewPosition.xyz);
	vec3 N = normal;

	float NdotV = dot(N, V);

	N = normalize(mix(normal, -V, clamp(pow((NdotV * 1.0), 1.0), 0.0, 1.0)));
	N = normalize(N + -V * 0.1 * clamp(NdotV + 0.4, 0.0, 1.0));

	normal = N;
}

float getnoise(vec2 pos) {
	return abs(fract(sin(dot(pos , vec2(18.9898f,28.633f))) * 4378.5453f));
}

vec4 textureSmooth(in sampler2D tex, in vec2 coord) {
	vec2 res = vec2(64.0f, 64.0f);

	coord *= res;
	coord += 0.5f;

	vec2 whole = floor(coord);
	vec2 part  = fract(coord);

	part.x = part.x * part.x * (3.0f - 2.0f * part.x);
	part.y = part.y * part.y * (3.0f - 2.0f * part.y);

	coord = whole + part;

	coord -= 0.5f;
	coord /= res;

	return texture2D(tex, coord);
}

float AlmostIdentity(in float x, in float m, in float n) {
	if (x > m) return x;

	float a = 2.0f * n - m;
	float b = 2.0f * m - 3.0f * n;
	float t = x / m;

	return (a * t + b) * t * t + n;
}

float GetWaves(vec3 position) {
	float speed = 0.7f;

  vec2 p = position.xz / 20.0f;
  p.xy -= position.y / 20.0f;
  p.x = -p.x;

  p.x += (FRAME_TIME / 40.0f) * speed;
  p.y -= (FRAME_TIME / 40.0f) * speed;

  float weight = 1.0f;
  float weights = weight;

  float allwaves = 0.0f;

  float wave = textureSmooth(noisetex, (p * vec2(2.0f, 1.2f))  + vec2(0.0f,  p.x * 2.1f) ).x; 			p /= 2.1f; 	/*p *= pow(2.0f, 1.0f);*/ 	p.y -= (FRAME_TIME / 20.0f) * 0.6; p.x -= (FRAME_TIME / 30.0f) * speed;
  allwaves += wave;

  weight = 4.1f;
  weights += weight;
  wave = textureSmooth(noisetex, (p * vec2(2.0f, 1.4f))  + vec2(0.0f,  -p.x * 2.1f) ).x;	p /= 1.5f;/*p *= pow(2.0f, 2.0f);*/ 	p.x += (FRAME_TIME / 20.0f) * speed;
  wave *= weight;
  allwaves += wave;

  weight = 17.25f;
  weights += weight;
  wave = (textureSmooth(noisetex, (p * vec2(1.0f, 0.75f))  + vec2(0.0f,  p.x * 1.1f) ).x);		p /= 1.5f; 	p.x -= (FRAME_TIME / 55.0f) * speed;
  wave *= weight;
  allwaves += wave;

  weight = 15.25f;
  weights += weight;
  wave = (textureSmooth(noisetex, (p * vec2(1.0f, 0.75f))  + vec2(0.0f,  -p.x * 1.7f) ).x);		p /= 1.9f; 	p.x += (FRAME_TIME / 155.0f) * 0.8;
  wave *= weight;
  allwaves += wave;

  weight = 29.25f;
  weights += weight;
  wave = abs(textureSmooth(noisetex, (p * vec2(1.0f, 0.8f))  + vec2(0.0f,  -p.x * 1.7f) ).x * 2.0f - 1.0f);		p /= 2.0f; 	p.x += (FRAME_TIME / 155.0f) * speed;
  wave = 1.0f - AlmostIdentity(wave, 0.2f, 0.1f);
  wave *= weight;
  allwaves += wave;

  allwaves /= weights;

  return allwaves;
}

vec3 GetWavesNormal(vec3 position) {

	float WAVE_HEIGHT = 1.0;

	const float sampleDistance = 11.0f;

	position -= vec3(0.005f, 0.0f, 0.005f) * sampleDistance;

	float wavesCenter = GetWaves(position);
	float wavesLeft = GetWaves(position + vec3(0.01f * sampleDistance, 0.0f, 0.0f));
	float wavesUp   = GetWaves(position + vec3(0.0f, 0.0f, 0.01f * sampleDistance));

	vec3 wavesNormal;
	wavesNormal.r = wavesCenter - wavesLeft;
	wavesNormal.g = wavesCenter - wavesUp;

	wavesNormal.r *= 10.0f * WAVE_HEIGHT / sampleDistance;
	wavesNormal.g *= 10.0f * WAVE_HEIGHT / sampleDistance;

	wavesNormal.b = sqrt(1.0f - wavesNormal.r * wavesNormal.r - wavesNormal.g * wavesNormal.g);
	wavesNormal.rgb = normalize(wavesNormal.rgb);

	return wavesNormal.rgb;
}

void WaterRefraction(inout SurfaceStruct surface) {
	if (surface.mask.water) {
		vec3 wavesNormal = GetWavesNormal(surface.worldSpacePosition.xyz + cameraPosition.xyz).xzy;
		float waterDepth = ExpToLinearDepth(texture2D(depthtex1, texcoord.st).x);
		float waterDepthDiff = waterDepth - surface.linearDepth;
		float refractAmount = saturate(waterDepthDiff / 1.0);

		vec4 wnv = gbufferModelView * vec4(wavesNormal.xyz, 0.0);
		vec3 wavesNormalView = normalize(wnv.xyz);
		vec4 nv = gbufferModelView * vec4(0.0, 1.0, 0.0, 0.0);
		nv.xyz = normalize(nv.xyz);

		wavesNormalView.xy -= nv.xy;

		float aberration = 0.15;
		float refractionAmount = 1.0;

		vec2 refractCoord0 = texcoord.st - wavesNormalView.xy * refractAmount * (refractionAmount) / (surface.linearDepth + 0.0001);
		vec2 refractCoord1 = texcoord.st - wavesNormalView.xy * refractAmount * (refractionAmount + aberration) / (surface.linearDepth + 0.0001);
		vec2 refractCoord2 = texcoord.st - wavesNormalView.xy * refractAmount * (refractionAmount + aberration * 2.0) / (surface.linearDepth + 0.0001);

		float mask0 = 1 - GetWaterMaskFloat(refractCoord0);
		float mask1 = 1 - GetWaterMaskFloat(refractCoord1);
		float mask2 = 1 - GetWaterMaskFloat(refractCoord2);

		vec3 spillSample = pow(texture2D(gcolor, texcoord.xy).rgb, vec3(2.2));

		surface.color.r = pow(texture2DLod(gcolor, refractCoord0.xy, 0).r, (2.2)) * mask0 + spillSample.r * (1 - mask0);
		surface.color.g = pow(texture2DLod(gcolor, refractCoord1.xy, 0).g, (2.2)) * mask1 + spillSample.g * (1 - mask1);
		surface.color.b = pow(texture2DLod(gcolor, refractCoord2.xy, 0).b, (2.2)) * mask2 + spillSample.b * (1 - mask2);
	}
}

vec3 GetCrepuscularRays (in SurfaceStruct surface) {
	if (isEyeInWater > 0.9) {
		return vec3(0.0);
  }

	if (rainStrength > 0.9) {
		return vec3(0.0);
  }

	float vlSample = texture2DLod(gcolor, texcoord.st, 3.2).a;

	float sunglow = 1.0 - CalculateSunglow(surface);
  sunglow = 1.0 / (pow(sunglow, 1.0) * 9.0 + 0.001);
	sunglow += CalculateAntiSunglow(surface) * 0.2;

	vec3 raysSun = vec3(vlSample);
  vec3 raysSuns = vec3(vlSample);
  vec3 raysNight = vec3(vlSample);
	vec3 raysSunIn = vec3(vlSample);
	vec3 raysAtmosphere = vec3(vlSample);

	raysSunIn.rgb *= sunglow;
  raysSunIn.rgb *= colorSunlight;

  raysSun.rgb *= sunglow * timeNoon;
  raysSun.rgb *= colorSunlight * timeNoon;

  raysSuns.rgb *= sunglow * timeSunriseSunset;
  raysSuns.rgb *= colorSunlight * timeSunriseSunset;

  raysNight.rgb *= colorSunlight * timeMidnight;

  raysAtmosphere *= pow(colorSkylight, vec3(1.3));

	vec3 rays = raysSuns.rgb * SUNRISEnSET + raysAtmosphere.rgb * 0.5 * 0.0;
  rays += raysSun.rgb * NOON + raysAtmosphere.rgb * 0.5 * 0.0;
	rays += raysNight.rgb * NIGHT + raysAtmosphere.rgb * 0.5 * 0.0;


	vec3 Inrays = raysSunIn.rgb * IN_SIDE_RAYS + raysAtmosphere.rgb * 0.5 * 0.0;
	Inrays += raysNight.rgb * IN_SIDE_RAYS_NIGHT + raysAtmosphere.rgb * 0.5 * 0.0;
	Inrays *= mix(1.0f, 0.0f, pow(eyeBrightnessSmooth.y / 240.0f, 3.0f));


  DoNightEye(rays);

	return ((rays * 0.0058)*0.0049 + Inrays * 0.00001)*pow(1-rainStrength, 2.0f);
}


vec3 Get2DGodraysRays(in SurfaceStruct surface) {
	vec4 tpos = vec4(sunPosition, 1.0) * gbufferProjection;
	tpos = vec4(tpos.xyz / tpos.w, 1.0);

	vec2 pos1 = tpos.xy / tpos.z;
	vec2 lightPos = pos1 * 0.5 + 0.5;
	float gr = 0.0;

	#ifdef NO_UNDERWATER_RAYS
		if (isEyeInWater > 0.9) {
			return vec3(0.0);
		}
	#endif

	if (rainStrength > 0.9) {
		return vec3(0.0);
	}

	float truepos = sign(sunPosition.z); //temporary fix that check if the sun/moon position is correct

	if (truepos < 0.05) {
		vec2 deltaTextCoord = vec2(texcoord.st - lightPos.xy);
		vec2 textCoord = texcoord.st;
		deltaTextCoord *= 1.0 / float(NUM_SAMPLES) * grdensity;
		float illuminationDecay = 1.0;
		gr = 0.0;
		float avgdecay = 0.0;
		float distx = abs(texcoord.x * aspectRatio - lightPos.x * aspectRatio);
		float disty = abs(texcoord.y - lightPos.y);
		illuminationDecay = pow(max(1.0 - sqrt(distx * distx + disty * disty), 0.0), 7.8);

		#ifdef VOLUMETRIC_LIGHT
			illuminationDecay *= mix(0.0f, 1.0f, pow(eyeBrightnessSmooth.y / 240.0f, 3.0f));
		#endif

		float fallof = 1.0;
		const int nSteps = 9;
		const float blurScale = 0.002;
		deltaTextCoord = normalize(deltaTextCoord);
		int center = (nSteps - 1) / 2;
		vec3 blur = vec3(0.0);
		float tw = 0.0;
		float sigma = 0.25;
		float A = 1.0/sqrt(2.0 * 3.14159265359 * sigma);
		textCoord -= deltaTextCoord * center * blurScale;

		for(int i=0; i < nSteps ; i++) {
			textCoord += deltaTextCoord * blurScale;
			float dist = (i - float(center)) / center;
			float weight = A * exp(-(dist * dist) / (4.0 * sigma));
			float sample = texture2D(gcolor, textCoord).a * weight;

			tw += weight;
			gr += sample;
		}

		return colorSunlight * exposure * (gr / tw) * pow(1 - rainStrength, 2.0f) * illuminationDecay * timeNoon * 2 * pow(1 - rainStrength, 2.0f);
	}
}

vec3 Get2DMoonGodraysRays(in SurfaceStruct surface) {
	vec4 tpos = vec4(sunPosition, 1.0) * gbufferProjection;
	tpos = vec4(tpos.xyz / tpos.w, 1.0);

	vec2 pos1 = tpos.xy / tpos.z;
	vec2 lightPos = pos1 * 0.5 + 0.5;
	float gr = 0.0;

	#ifdef NO_UNDERWATER_RAYS
		if (isEyeInWater > 0.9) {
			return vec3(0.0);
		}
	#endif

	if (rainStrength > 0.9) {
		return vec3(0.0);
	}

	float truepos = sign(sunPosition.z); //temporary fix that check if the sun/moon position is correct

	tpos = vec4(-sunPosition, 1.0) * gbufferProjection;
	tpos = vec4(tpos.xyz / tpos.w, 1.0);
	pos1 = tpos.xy / tpos.z;
	lightPos = pos1 * 0.5 + 0.5;

	if (truepos > 0.05) {
		vec2 deltaTextCoord = vec2(texcoord.st - lightPos.xy);
		vec2 textCoord = texcoord.st;
		deltaTextCoord *= 1.0 / float(NUM_SAMPLES) * grdensity;
		float illuminationDecay = 1.0;

		gr = 0.0;
		float avgdecay = 0.0;
		float distx = abs(texcoord.x * aspectRatio - lightPos.x * aspectRatio);
		float disty = abs(texcoord.y - lightPos.y);
		illuminationDecay = pow(max(1.0 - sqrt(distx * distx + disty * disty), 0.0), 5.0);

		#ifdef VOLUMETRIC_LIGHT
			illuminationDecay *= mix(0.0f, 1.0f, pow(eyeBrightnessSmooth.y / 240.0f, 3.0f));
		#endif

		float fallof = 1.0;
		const int nSteps = 9;
		const float blurScale = 0.002;
		deltaTextCoord = normalize(deltaTextCoord);
		int center = (nSteps - 1) / 2;
		vec3 blur = vec3(0.0);
		float tw = 0.0;
		float sigma = 0.25;
		float A = 1.0 / sqrt(2.0 * 3.14159265359 * sigma);
		textCoord -= deltaTextCoord * center * blurScale;

		for(int i=0; i < nSteps ; i++) {
			textCoord += deltaTextCoord * blurScale;
			float dist = (i - float(center)) / center;
			float weight = A * exp(-(dist * dist) / (2.0 * sigma));
			float sample = texture2D(gcolor, textCoord).a * weight;

			tw += weight;
			gr += sample;
		}
		return 5.0f * colorSunlight * Moon_exposure * (gr / tw) * pow(1 - rainStrength, 2.0f) * illuminationDecay / 2.5 * truepos * timeMidnight * pow(1 - rainStrength, 2.0f);
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main() {

	surface.color = pow(texture2DLod(gcolor, texcoord.st, 0).rgb, vec3(2.2f));
	surface.normal = GetNormals(texcoord.st);
	surface.depth = GetDepth(texcoord.st);
	surface.linearDepth = ExpToLinearDepth(surface.depth); 				//Get linear scene depth
	surface.viewSpacePosition = GetViewSpacePosition(texcoord.st);
	surface.worldSpacePosition = gbufferModelViewInverse * surface.viewSpacePosition;
	FixNormals(surface.normal, surface.viewSpacePosition.xyz);
	surface.lightVector = lightVector;
	surface.sunlightVisibility = GetSunlightVisibility(texcoord.st);
	surface.upVector 	= upVector;
	vec4 wlv = shadowModelViewInverse * vec4(0.0f, 0.0f, 0.0f, 1.0f);
	surface.worldLightVector 	= normalize(wlv.xyz);

	surface.metallic = GetMetallic(texcoord.st);
	surface.smoothness = GetSmoothness(texcoord.st);
	surface.fresnelPower = 6.0f;

	surface.mask.matIDs = GetMaterialIDs(texcoord.st);
	CalculateMasks(surface.mask);

	surface.cloudAlpha = 0.0f;
	#ifdef SMOOTH_SKY
		surface.cloudAlpha = texture2D(composite, texcoord.st, 2).g;
		SmoothSky(surface);
	#endif

	#ifdef CLOUD_PLANE_Cloud
		CloudPlane(surface);
	#endif

	#ifdef Water_Refraction
		WaterRefraction(surface);
	#endif

	CalculateSmoothnessReflections(surface);
	CalculateSmoothnessHighlight(surface);

	#ifdef VOLUMETRIC_LIGHT
		surface.color.rgb += GetCrepuscularRays(surface);
	#endif

	#ifdef GODRAYS
		surface.color.rgb += Get2DGodraysRays(surface);
	#endif

	#ifdef MOONRAYS
		surface.color.rgb += Get2DMoonGodraysRays(surface);
	#endif

	surface.color = pow(surface.color, vec3(1.0f / 2.2f));
	gl_FragData[0] = vec4(surface.color, 1.0f);
}
