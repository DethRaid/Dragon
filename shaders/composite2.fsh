#version 120

/////////////////////////CONFIGURABLE VARIABLES/////////////////////////////////
/////////////////////////CONFIGURABLE VARIABLES/////////////////////////////////
#define BANDING_FIX_FACTOR 1.0f

#define SMOOTH_SKY

//#define CLOUD_PLANE			//Original 2D clouds, not the best anymore (IMO)

// One or the other has to be enabled but not both
//#define STANDARD_CLOUDS			// Enable this if only using 2D clouds
#define ULTRA_CLOUDS				// Enable this if using 2D and 3D clouds for best effect (IMO)

#define NEW_WATER_REFLECT			//Best version to use 95% of bugs gone/ small bug with the sunrise/set when looking down into water
									// If you have issues, disable it to use the old reflection method

//----------Refletion--------//
#define MAX_RAY_LENGTH          75.0
#define MAX_DEPTH_DIFFERENCE    0.25 	//How much of a step between the hit pixel and anything else is allowed?
#define RAY_STEP_LENGTH         0.35
#define MAX_REFLECTIVITY        1.0 	//As this value approaches 1, so do all reflections
#define RAY_DEPTH_BIAS          1.0   	//Serves the same purpose as a shadow bias
#define RAY_GROWTH              1.0    	//Make this number smaller to get more accurate reflections at the cost of performance
                                        //numbers less than 1 are not recommended as they will cause ray steps to grow
                                        //shorter and shorter until you're barely making any progress
#define NUM_RAYS                1   	//The best setting in the whole shader pack. If you increase this value,
                                    	//more and more rays will be sent per pixel, resulting in better and better
                                    	//reflections. If you computer can handle 4 (or even 16!) I highly recommend it.


//----End Reflections--------//

//----------GodRays----------//
#define GODRAYS
	const float exposure = 0.0009;			//godrays intensity 0.0009 is default
	const float grdensity = 1.0;
	const int NUM_SAMPLES = 10;			//increase this for better quality at the cost of performance /8 is default
	const float grnoise = 0.0;		//amount of noise /0.0 is default
	const float Moon_exposure = 0.001;			//Moonrays intensity 0.0009 is default, increase to make brighter

#define MOONRAYS					//Make sure if you enable/disable this to do the same in Composite, PLEASE NOTE Moonrays have a bug at sunset/sunrise

#define NO_UNDERWATER_RAYS

//#define NO_GODRAYS				//NOTE!! if you disable GODRAYS then you MUST enable this so the shader wont crash

//----------End CONFIGURABLE GodRays----------//

/////////////////////////END OF CONFIGURABLE VARIABLES//////////////////////////
/////////////////////////END OF CONFIGURABLE VARIABLES//////////////////////////

/* DRAWBUFFERS:2 */
const bool gcolorMipmapEnabled = true;
const bool compositeMipmapEnabled = true;

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gdepthtex;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D noisetex;

varying float SdotU;
varying float MdotU;
varying float sunVisibility;
varying float moonVisibility;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform int   worldTime;
uniform int   isEyeInWater;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 fogColor;

varying vec4 texcoord;

varying vec3 lightVector;
varying vec3 upVector;
uniform vec3 sunPosition;
uniform vec3 moonPosition;

varying float timeSunrise;
varying float timeNoon;
varying float timeSunset;
varying float timeMidnight;
varying float timeSkyDark;

varying vec3 colorSunlight;
varying vec3 colorMoonlight;
varying vec3 sunlight;
varying vec3 moonlight;
varying vec3 colorSkylight;
varying vec3 colorBouncedSunlight;

#define ANIMATION_SPEED 1.0f

//#define ANIMATE_USING_WORLDTIME

#ifdef ANIMATE_USING_WORLDTIME
#define FRAME_TIME worldTime * ANIMATION_SPEED / 20.0f
#else
#define FRAME_TIME frameTimeCounter * ANIMATION_SPEED
#endif

/////////////////////////FUNCTIONS//////////////////////////////////////////////
/////////////////////////FUNCTIONS//////////////////////////////////////////////
vec3 	GetNormals(in vec2 coord) {
	vec3 normal = vec3(0.0f);
		 normal = texture2DLod(gnormal, coord.st, 0).rgb;
	normal = normal * 2.0f - 1.0f;
	normal = normalize(normal);

	return normal;
}

float 	GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord).x;
}

float 	ExpToLinearDepth(in float depth) {
	return 2.0f * near * far / (far + near - (2.0f * depth - 1.0f) * (far - near));
}

float 	GetDepthLinear(vec2 coord) {
    return 2.0 * near * far / (far + near - (2.0 * GetDepth( coord ) - 1.0) * (far - near));
}

vec4  	GetViewSpacePosition(in vec2 coord) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
	float depth = GetDepth(coord);
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;

	return fragposition;
}

float 	GetMaterialIDs(in vec2 coord) {			//Function that retrieves the texture that has all material IDs stored in it
	return texture2D(gdepth, coord).r;
}

float 	GetSunlightVisibility(in vec2 coord) {
	return texture2D(gdepth, coord).g;
}

float 	cubicPulse(float c, float w, float x) {
	x = abs(x - c);
	if (x > w) return 0.0f;
	x /= w;
	return 1.0f - x * x * (3.0f - 2.0f * x);
}

bool 	GetMaterialMask(in int ID, in float matID) {
	matID = floor(matID * 255.0f);

	return matID == ID;
}

bool 	GetSkyMask(in float matID) {
	return GetMaterialMask( 0, matID ) || GetMaterialMask( 254, matID );
}

bool 	GetSkyMask(in vec2 coord) {
	float matID = GetMaterialIDs(coord);
	return GetSkyMask( matID );
}

float 	GetSpecularity(in vec2 coord) {
	return texture2D(composite, coord).r;
}

float 	GetSmoothness(in vec2 coord) {
	return texture2D(composite, coord).b;
}

//Water
float 	GetWaterTex(in vec2 coord) {				//Function that returns the texture used for water. 0 means "this pixel is not water". 0.5 and greater means "this pixel is water".
	return texture2D(gnormal, coord).b;		//values from 0.5 to 1.0 represent the amount of sky light hitting the surface of the water. It is used to simulate fake sky reflections in composite1.fsh
}

bool  	GetWaterMask(in float matID) {					//Function that returns "true" if a pixel is water, and "false" if a pixel is not water.
	matID = floor(matID * 255.0f);

	if (matID >= 35.0f && matID <= 51) {
		return true;
	} else {
		return false;
	}
}

bool  	GetWaterMask(in vec2 coord) {					//Function that returns "true" if a pixel is water, and "false" if a pixel is not water.
	float matID = floor(GetMaterialIDs(coord) * 255.0f);

	if (matID >= 35.0f && matID <= 51) {
		return true;
	} else {
		return false;
	}
}

float 	GetLightmapSky(in vec2 coord) {
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

vec2 getCoordFromCameraSpace( in vec3 position ) {
    vec4 viewSpacePosition = gbufferProjection * vec4( position, 1 );
    vec2 ndcSpacePosition = viewSpacePosition.xy / viewSpacePosition.w;
    return ndcSpacePosition * 0.5 + 0.5;
}

float  	CalculateDitherPattern1() {
	int[16] ditherPattern = int[16] (0 , 9 , 3 , 11,
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
	int[16] ditherPattern = int[16] (4 , 12, 2,  10,
								 	 16, 8 , 14, 6 ,
								 	 0 , 9 , 3 , 11,
								 	 13, 5 , 15, 7 );

	vec2 count = vec2(0.0f);
	     count.x = floor(mod(texcoord.s * viewWidth, 4.0f));
		 count.y = floor(mod(texcoord.t * viewHeight, 4.0f));

	int dither = ditherPattern[int(count.x) + int(count.y) * 4];

	return float(dither) / 17.0f;
}

vec3 	CalculateNoisePattern1(vec2 offset, float size) {
	vec2 coord = texcoord.st;

	coord *= vec2(viewWidth, viewHeight);
	coord = mod(coord + offset, vec2(size));
	coord /= 64.0f;

	return texture2D(noisetex, coord).xyz;
}

float noise (in float offset) {
	vec2 coord = texcoord.st + vec2(offset);
	float noise = clamp(fract(sin(dot(coord ,vec2(12.9898f,78.233f))) * 43758.5453f),0.0f,1.0f)*2.0f-1.0f;
	return noise;
}

float noise (in vec2 coord, in float offset) {
	coord += vec2(offset);
	float noise = clamp(fract(sin(dot(coord ,vec2(12.9898f,78.233f))) * 43758.5453f),0.0f,1.0f)*2.0f-1.0f;
	return noise;
}

void 	DoNightEye(inout vec3 color) {			//Desaturates any color input at night, simulating the rods in the human eye

	float amount = 0.8f; 						//How much will the new desaturated and tinted image be mixed with the original image
	vec3 rodColor = vec3(0.2f, 0.5f, 1.0f); 	//Cyan color that humans percieve when viewing extremely low light levels via rod cells in the eye
	float colorDesat = dot(color, vec3(1.0f)); 	//Desaturated color

	color = mix(color, vec3(colorDesat) * rodColor, timeSkyDark * amount);
	//color.rgb = color.rgb;
}

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

	// uv -= 0.5f;
	// uv2 -= 0.5f;

	vec2 coord =  (uv  + 0.5f) / 64.0f;
	vec2 coord2 = (uv2 + 0.5f) / 64.0f;
	float xy1 = texture2D(noisetex, coord).x;
	float xy2 = texture2D(noisetex, coord2).x;
	return mix(xy1, xy2, f.z);
}

/////////////////////////STRUCTS////////////////////////////////////////////////
/////////////////////////STRUCTS////////////////////////////////////////////////

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
	float  	specularity;
	vec3 	specularColor;			// F0
	float 	smoothness;
	vec3    fresnel;
	float 	baseSpecularity;
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



/////////////////////////STRUCT FUNCTIONS///////////////////////////////////////
/////////////////////////STRUCT FUNCTIONS///////////////////////////////////////

void 	CalculateMasks(inout MaskStruct mask) {
	mask.sky 			= GetSkyMask( mask.matIDs );
	mask.land	 		= !mask.sky;
	mask.tallGrass 		= GetMaterialMask(2, mask.matIDs);
	mask.leaves	 		= GetMaterialMask(3, mask.matIDs);
	mask.ice		 	= GetMaterialMask(4, mask.matIDs);
	mask.hand	 		= GetMaterialMask(5, mask.matIDs);
	mask.translucent	= GetMaterialMask(6, mask.matIDs);

	mask.glow	 		= GetMaterialMask(10, mask.matIDs);

	mask.goldBlock 		= GetMaterialMask(20, mask.matIDs);
	mask.ironBlock 		= GetMaterialMask(21, mask.matIDs);
	mask.diamondBlock	= GetMaterialMask(22, mask.matIDs);
	mask.emeraldBlock	= GetMaterialMask(23, mask.matIDs);
	mask.sand	 		= GetMaterialMask(24, mask.matIDs);
	mask.sandstone 		= GetMaterialMask(25, mask.matIDs);
	mask.stone	 		= GetMaterialMask(26, mask.matIDs);
	mask.cobblestone	= GetMaterialMask(27, mask.matIDs);
	mask.wool			= GetMaterialMask(28, mask.matIDs);

	mask.torch 			= GetMaterialMask(30, mask.matIDs);
	mask.lava 			= GetMaterialMask(31, mask.matIDs);
	mask.glowstone 		= GetMaterialMask(32, mask.matIDs);
	mask.fire 			= GetMaterialMask(33, mask.matIDs);

	mask.water 			= GetWaterMask(mask.matIDs);
}

vec3 calculateFresnelSchlick( in vec3 n, in float ndotv ) {
    vec3 F0 = (vec3( 1.0 ) - n) / (vec3( 1.0 ) + n);
    F0 = F0 * F0;
    return F0 + ((vec3( 1.0 ) - F0) * pow(1.0 - ndotv, 5.0));
}

// Calculate the LOD of the desired light buffer sample using an isosceles triangle to represent the ray
float calcualteRaytraceLOD( in SurfaceStruct surface, in float rayLength ) {
	float maxMipLevel = 10;	// TODO: Calculate this somehow

	float specularPower = pow( 2, 10 * surface.smoothness + 1 );
	const float xi = 0.244f;
 	float exponent = 1.0f / (specularPower + 1.0f);
	float coneTheta = acos( pow( xi, exponent ) );

	float oppositeLength = 2.0f * tan(coneTheta) * rayLength;

	float a2 = oppositeLength * oppositeLength;
 	float fh2 = 4.0f * rayLength * rayLength;
	float incircleSize = (oppositeLength * (sqrt(a2 + fh2) - oppositeLength)) / (4.0f * rayLength);

	return clamp( log2( incircleSize * max( viewWidth, viewHeight ) ), 0.0f, maxMipLevel );
}

vec4 	ComputeWaterReflection(inout SurfaceStruct surface) {
	float reflectionRange = 3.0f;
    float initialStepAmount = 1.0 - clamp(1.0f / 100.0, 0.0, 0.99);
		  initialStepAmount *= 4.0f;
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

	color = pow(texture2DLod(gcolor, finalSamplePos, 0), vec4(2.2f));

	if (finalSamplePos.x == 0.0f || finalSamplePos.y == 0.0f) {
		color.a = 0.0f;
	}

	color.a *= clamp(1 - pow(distance(vec2(0.5), finalSamplePos)*2.0, 2.0), 0.0, 1.0);
	// color.a *= 1.0f - float(GetMaterialMask(finalSamplePos, 0, surface.mask.matIDs));

    return color;
}

float 	CalculateLuminance(in vec3 color) {
	return (color.r * 0.2126f + color.g * 0.7152f + color.b * 0.0722f);
}

float   CalculateSunglow(in SurfaceStruct surface) {

	float curve = 4.0f;

	vec3 npos = normalize(surface.viewSpacePosition.xyz);
	vec3 halfVector2 = normalize(-surface.lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

float   CalculateReflectedSunglow(in SurfaceStruct surface) {

	float curve = 4.0f;

	vec3 npos = normalize(surface.viewSpacePosition.xyz);
	surface.lightVector = reflect(surface.lightVector, surface.normal);
	vec3 halfVector2 = normalize(-surface.lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

float   CalculateAntiSunglow(in SurfaceStruct surface) {

	float curve = 4.0f;

	vec3 npos = normalize(surface.viewSpacePosition.xyz);
	vec3 halfVector2 = normalize(surface.lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

float   CalculateSunspot(in SurfaceStruct surface) {
	float roughness = surface.smoothness;

	float curve = 1.0f;

	vec3 viewVector = normalize(surface.viewSpacePosition.xyz);
	vec3 halfVector2 = normalize(-surface.lightVector + viewVector);

	float sunProximity = abs(1.0f - dot(halfVector2, viewVector));

	float sizeFactor = 0.959f - roughness * 0.7f;

	float sunSpot = (clamp(sunProximity, sizeFactor, 0.96f) - sizeFactor) / (0.96f - sizeFactor);
		  sunSpot = pow(cubicPulse(1.0f, 1.0f, sunSpot), 2.0f);

	float result = sunSpot / (roughness * 20.0f + 0.1f);

		  result *= surface.sunlightVisibility;

	return result;
}

vec3 	ComputeReflectedSkyGradient(in SurfaceStruct surface) {
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
	vec3 color2 = vec3(1.7f, 1.0f, 0.8f) / 2.0f;
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


	if (surface.mask.water)
	{
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

vec3 	ComputeReflectedSkybox(in SurfaceStruct surface) {
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


	//if (skyGradientRaw > 0.75f)
		//skyColor *= 1000.0f;

	skyColor *= pow(1.0f - clamp(skyGradientRaw - 0.75f, 0.0f, 0.25f) / 0.25f, 3.0f);


	return skyColor;
}

Intersection 	RayPlaneIntersectionWorld(in Ray ray, in Plane plane) {
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

float GetCoverage(in float coverage, in float density, in float clouds) {
	clouds = clamp(clouds - (1.0f - coverage), 0.0f, 1.0f - density) / (1.0f - density);
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



	float t = FRAME_TIME * 1.0f;
		  t *= 0.4;


	 p += (Get3DNoise(p * 2.0f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.10f;

	  p.x -= (Get3DNoise(p * 0.125f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 1.2f;
	// p.xz -= (Get3DNoise(p * 0.0525f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 1.7f;


	p.x *= 0.25f;
	p.x -= t * 0.003f;

	vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
	float noise  = 	Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));	p *= 2.0f;	p.x -= t * 0.017f;	p.z += noise * 1.35f;	p.x += noise * 0.5f; 									vec3 p2 = p;
		  noise += (2.0f - abs(Get3DNoise(p) * 2.0f - 0.0f)) * (0.25f);						p *= 3.0f;	p.xz -= t * 0.005f;	p.z += noise * 1.35f;	p.x += noise * 0.5f; 	p.x *= 3.0f;	p.z *= 0.55f;	vec3 p3 = p;
		 	 p.z -= (Get3DNoise(p * 0.25f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.4f;
		  noise += (3.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * (0.035f);					p *= 3.0f;	p.xz -= t * 0.005f;																					vec3 p4 = p;
		  noise += (3.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * (0.025f);					p *= 3.0f;	p.xz -= t * 0.005f;
		  if (!isShadowPass)
		  {
		 		noise += ((Get3DNoise(p))) * (0.022f);												p *= 3.0f;
		  		 noise += ((Get3DNoise(p))) * (0.024f);
		  }
		  noise /= 1.575f;

	//cloud edge
	float rainy = mix(wetness, 1.0f, rainStrength);
		  //rainy = 0.0f;
#ifdef STANDARD_CLOUDS
	float coverage = 0.55f + rainy * 0.35f;
#endif

#ifdef ULTRA_CLOUDS
	float coverage = 0.478f + rainy * 0.35f;
#endif

	float dist = length(worldPosition.xz - cameraPosition.xz);
	coverage *= max(0.0f, 1.0f - dist / mix(10000.0f, 3000.0f, rainStrength));
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
		 	  directLightFalloff *= mix(1.5f, 1.0f, pow(sunglow, 0.5f))*timeNoon*2;



		vec3 colorDirect = colorSunlight * 10.0f;
		colorDirect *= 1.0f + pow(sunglow, 8.0f) * 100.0f;


		vec3 colorAmbient = mix(colorSkylight, colorSunlight, 0.15f) * 0.065f;

		directLightFalloff *= 1.0f - rainStrength * 0.99f;


		//directLightFalloff += (pow(Get3DNoise(p3), 2.0f) * 0.5f + pow(Get3DNoise(p3 * 1.5f), 2.0f) * 0.25f) * 0.02f;
		//directLightFalloff *= Get3DNoise(p2);

		vec3 color = mix(colorAmbient, colorDirect, vec3(min(1.0f, directLightFalloff)));

		color *= 1.0f;

		// noise *= mix(1.0f, 5.0f, sunglow);

		vec4 result = vec4(color, noise);

		return result;
	}

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

	if (i.angle < 0.0f)
	{
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

	if (i.angle < 0.0f) {
		if (i.distance < surface.linearDepth || surface.mask.sky) {
			vec4 cloudSample = CloudColor2(vec4(i.pos.xyz * 0.5f + vec3(30.0f), 1.0f), sunglow/2, surface.worldLightVector, cloudsAltitude, cloudsThickness, false);
			 	 cloudSample.a = min(1.0f, cloudSample.a * density);

			surface.color.rgb = mix(surface.color.rgb, cloudSample.rgb * 0.001f, cloudSample.a);

			cloudSample = CloudColor2(vec4(i.pos.xyz * 0.65f + vec3(10.0f) + vec3(i.pos.z * 0.5f, 0.0f, 0.0f), 1.0f), sunglow/2, surface.worldLightVector, cloudsAltitude, cloudsThickness, false);
			cloudSample.a = min(1.0f, cloudSample.a * density);

			surface.color.rgb = mix(surface.color.rgb, cloudSample.rgb * 0.001f, cloudSample.a);

		}
	}
}

#ifdef NEW_WATER_REFLECT
vec4 	ComputeFakeSkyReflection(in SurfaceStruct surface) {
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
#else
vec4 	ComputeSkyReflection(in SurfaceStruct surface) {
	float fresnelPower = 4.0f;

	vec3 cameraSpacePosition = convertScreenSpaceToWorldSpace(texcoord.st);
	vec3 cameraSpaceNormal = surface.normal;
	vec3 cameraSpaceViewDir = normalize(cameraSpacePosition);
	vec4 color = vec4(0.0f);

	color.rgb = ComputeReflectedSkybox(surface) * 0.030f;
	ReflectedCloudPlane(color.rgb, surface);
	color.rgb *= 0.0003f;
	color.rgb *= mix(1.0f, 20000.0f, timeSkyDark);
	color.rgb *= mix(1.0f, 25.0f, rainStrength/1.5);

	float viewVector = dot(cameraSpaceViewDir, cameraSpaceNormal);

	color.a = pow(clamp(1.0f + viewVector, 0.0f, 1.0f), fresnelPower) * 1.0f + 0.02f;

	if (viewVector > 0.0f) {
		color.a = 1.0f - pow(clamp(viewVector, 0.0f, 1.0f), 1.0f / fresnelPower) * 1.0f + 0.02f;
		color.rgb = vec3(0.0f);
	}

	return color;
}
#endif

//Determines the UV coordinate where the ray hits
//If the returned value is not in the range [0, 1] then nothing was hit.
//NOTHING!
//Note that origin and direction are assumed to be in screen-space coordinates, such that 
//  -origin.st is the texture coordinate of the ray's origin
//  -direction.st is of such a length that it moves the equivalent of one texel
//  -both origin.z and direction.z correspond to values raw from the depth buffer
vec2 castRay( in vec3 origin, in vec3 direction, in float maxDist ) {
    vec3 curPos = origin;
    vec2 curCoord = getCoordFromCameraSpace( curPos );
    direction = normalize( direction ) * RAY_STEP_LENGTH;
    bool forward = true;

    //The basic idea here is the the ray goes forward until it's behind something,
    //then slowly moves forward until it's in front of something.
    for( int i = 0; i < MAX_RAY_LENGTH * (1 / RAY_STEP_LENGTH); i++ ) {
        curPos += direction;
        curCoord = getCoordFromCameraSpace( curPos );
        if( curCoord.x < 0 || curCoord.x > 1 || curCoord.y < 0 || curCoord.y > 1 ) {
            //If we're here, the ray has gone off-screen so we can't reflect anything
            return vec2( -1 );
        }
        if( length( curPos - origin ) > MAX_RAY_LENGTH ) {
            return vec2( -1 );
        }
        float worldDepth = GetViewSpacePosition( curCoord ).z;
        float rayDepth = curPos.z;
        float depthDiff = (worldDepth - rayDepth);
        float maxDepthDiff = length( direction ) + RAY_DEPTH_BIAS;
        if( forward ) {
            if( depthDiff > 0 && depthDiff < maxDepthDiff ) {
                //return curCoord;
                direction = -1 * normalize( direction ) * 0.15;
                forward = false;
            } 
        } else {
            depthDiff *= -1;
            if( depthDiff > 0 && depthDiff < maxDepthDiff ) {
                return curCoord;
            }
        }
        direction *= RAY_GROWTH;
    }
    //If we're here, we couldn't find anything to reflect within the alloted number of steps
    return vec2( -1 ); 
}

vec4 doLightBounce( in SurfaceStruct pixel ) {
    //Find where the ray hits
    //get the blur at that point
    //mix with the color 
    vec3 rayStart = pixel.viewSpacePosition.xyz;
    vec2 noiseCoord = vec2( texcoord.s * viewWidth / 64.0, texcoord.t * viewHeight / 64.0 );
    vec3 retColor = vec3( 0 );
    vec3 noiseSample = vec3( 0 );
    vec3 reflectDir = vec3( 0 );
    vec3 rayDir = vec3( 0 );
    vec2 hitUV = vec2( 0 );

    #ifdef NEW_WATER_REFLECT
	vec4 skyColor = ComputeFakeSkyReflection(surface);
	#else
	vec4 skyColor = ComputeSkyReflection(surface);
	#endif
    
    //trace the number of rays defined previously
    for( int i = 0; i < NUM_RAYS; i++ ) {
        noiseSample = texture2D( noisetex, noiseCoord * (i + 1) ).rgb * 2.0 - 1.0;
        reflectDir = normalize( noiseSample * (1.0 - pixel.smoothness) * 0.25 + pixel.normal );
        reflectDir *= sign( dot( pixel.normal, reflectDir ) );
        rayDir = reflect( normalize( rayStart ), reflectDir );
    
        hitUV = castRay( rayStart, rayDir, MAX_RAY_LENGTH );
        if( hitUV.s > -0.1 && hitUV.s < 1.1 && hitUV.t > -0.1 && hitUV.t < 1.1 ) {
            retColor += vec3( texture2D( gcolor, hitUV.st ).rgb * MAX_REFLECTIVITY );
        } else {
            retColor += skyColor.rgb;
        }
    }
    
    vec4 color;
    color.rgb = pow( retColor / NUM_RAYS, vec3( 2.0 ) );

    #ifdef GODRAYS
	color.a = 1.0;
	#endif

	color.a *= clamp( 1 - pow( distance( vec2( 0.5 ), hitUV ) * 2.0, 2.0 ), 0.0, 1.0 );

    return color;
}

void 	CalculateSpecularReflections(inout SurfaceStruct surface) {
	surface.rDepth = 0.0f;

	if (surface.mask.sky) {
		surface.fresnel = vec3( 0.0f );
	}

	vec4 reflection = vec4( 0.0f );

	#ifdef NEW_WATER_REFLECT
	reflection = doLightBounce( surface );
	#else
	reflection = ComputeWaterReflection(surface);
	#endif

	float surfaceLightmap = GetLightmapSky(texcoord.st);

	#ifdef NEW_WATER_REFLECT
	vec4 fakeSkyReflection = ComputeFakeSkyReflection(surface);
	#else
	vec4 fakeSkyReflection = ComputeSkyReflection(surface);
	#endif

	vec3 noSkyToReflect = vec3(0.0f);

	fakeSkyReflection.rgb = mix(noSkyToReflect, fakeSkyReflection.rgb, clamp(surfaceLightmap * 16 - 5, 0.0f, 1.0f));
	reflection.rgb = mix(reflection.rgb, fakeSkyReflection.rgb, pow(vec3(1.0f - reflection.a), vec3(10.1f)));
	reflection.a = fakeSkyReflection.a;

	reflection.rgb *= surface.fresnel;

	surface.color = mix(surface.color, reflection.rgb, vec3( reflection.a ) );
	surface.color = mix( surface.color, reflection.rgb, vec3( surface.specularity ) );
	surface.reflection = reflection;
}

void CalculateSpecularHighlight(inout SurfaceStruct surface) {
	if (!surface.mask.sky && !surface.mask.water) {
		vec3 halfVector = normalize(lightVector - normalize(surface.viewSpacePosition.xyz));

		float HdotN = max(0.0f, dot(halfVector, surface.normal.xyz));

		float gloss = pow(surface.smoothness + 0.01f, 4.5f);

		HdotN = clamp(HdotN * (1.0f + gloss * 0.01f), 0.0f, 1.0f);

		float spec = pow(HdotN, gloss * 8000.0f + 10.0f);

		spec *= surface.sunlightVisibility;

		spec *= gloss * 9000.0f + 10.0f;
		spec *= surface.specularity * surface.specularity * surface.specularity;
		spec *= 1.0f - rainStrength;

		vec3 specularHighlight = spec * mix(colorSunlight, vec3(0.2f, 0.5f, 1.0f) * 0.0005f, vec3(timeMidnight)) * surface.fresnel;

		surface.color += specularHighlight / 500.0f;
	}
}

void CalculateGlossySpecularReflections(inout SurfaceStruct surface) {
	float specularity = surface.specularity;
	float smoothness = 0.7f;
	float spread = 0.02f;

	specularity *= 1.0f - float(surface.mask.sky);

	vec4 reflectionSum = vec4(0.0f);

	surface.baseSpecularity = 0.0f;

	if (surface.mask.ironBlock) {
		smoothness = 0.9f;
	}

	if (surface.mask.goldBlock) {
		specularity = 0.0f;
	}

	if (specularity > 0.01f) {
		for (int i = 1; i <= 10; i++) {
			vec2 translation = vec2(surface.normal.x, surface.normal.y) * i * spread;
				 translation *= vec2(1.0f, viewWidth / viewHeight);

			float faceFactor = surface.normal.z;
				  faceFactor *= spread * 13.0f;

			vec2 scaling = vec2(1.0f + faceFactor * (i / 10.0f) * 2.0f);

			float r = float(i) + 4.0f;
				  r *= smoothness * 0.8f;
			int 	ri = int(floor(r));
			float 	rf = fract(r);

			vec2 finalCoord = (((texcoord.st * 2.0f - 1.0f) * scaling) * 0.5f + 0.5f) + translation;

			float weight = (11 - i + 1) / 10.0f;
			reflectionSum.rgb += pow(texture2DLod(gcolor, finalCoord, r).rgb, vec3(2.2f));
		}

		reflectionSum.rgb /= 10.0f;

		surface.color = mix(surface.color, reflectionSum.rgb * 1.0f, vec3(specularity) * surface.fresnel);
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
	const float cloudMaxHeight = cloudHeight + cloudDepth / 2.0f;
	const float cloudMinHeight = cloudHeight - cloudDepth / 2.0f;

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
	return abs(fract(sin(dot(pos, vec2(18.9898f,28.633f))) * 4378.5453f));
}

void calculateMoonRays( inout SurfaceStruct surface, in float truepos ) {
	vec4 tpos = vec4(-sunPosition,1.0)*gbufferProjection;
	tpos = vec4(tpos.xyz/tpos.w,1.0);
	vec2 pos1 = tpos.xy/tpos.z;
	vec2 lightPos = pos1*0.5+0.5;
	float gr = 0.0;

	if (truepos > 0.05) {
		vec2 deltaTextCoord = vec2( texcoord.st - lightPos.xy );
		vec2 textCoord = texcoord.st;
		deltaTextCoord *= 1.0 / float(NUM_SAMPLES) * grdensity;
		float illuminationDecay = 1.0;
		gr = 0.0;
		float avgdecay = 0.0;
		float distx = abs(texcoord.x*aspectRatio-lightPos.x*aspectRatio);
		float disty = abs(texcoord.y-lightPos.y);
		illuminationDecay = pow(max(1.0-sqrt(distx*distx+disty*disty),0.0),5.0);
		float fallof = 1.0;
		const int nSteps = 9;
		const float blurScale = 0.002;
		deltaTextCoord = normalize(deltaTextCoord);
		int center = (nSteps-1)/2;
		vec3 blur = vec3(0.0);
		float tw = 0.0;
		float sigma = 0.25;
		float A = 1.0/sqrt(2.0*3.14159265359*sigma);
		textCoord -= deltaTextCoord*center*blurScale;

		for(int i=0; i < nSteps ; i++) {
			textCoord += deltaTextCoord*blurScale;
			float dist = (i-float(center))/center;
			float weight = A*exp(-(dist*dist)/(2.0*sigma));
			float sample = texture2D(gcolor, textCoord).a*weight;

			tw += weight;
			gr += sample;
		}
		surface.color.rgb += 5.0f*colorSunlight*Moon_exposure*(gr/tw)*(1.0 - rainStrength*0.8)*illuminationDecay/2.5*truepos*timeMidnight;
	}
}

void calculateGodRays( inout SurfaceStruct surface ) {
	vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
	tpos = vec4(tpos.xyz/tpos.w,1.0);
	vec2 pos1 = tpos.xy/tpos.z;
	vec2 lightPos = pos1*0.5+0.5;
	float gr = 0.0;
	vec2 deltaTextCoord = vec2( texcoord.st - lightPos.xy );
	vec2 textCoord = texcoord.st;
	deltaTextCoord *= 1.0 / float(NUM_SAMPLES) * grdensity;
	float illuminationDecay = 1.0;
	float avgdecay = 0.0;
	float distx = abs(texcoord.x*aspectRatio-lightPos.x*aspectRatio);
	float disty = abs(texcoord.y-lightPos.y);
	illuminationDecay = pow(max(1.0-sqrt(distx*distx+disty*disty),0.0),7.8);
	float fallof = 1.0;
	const int nSteps = 9;
	const float blurScale = 0.002;
	deltaTextCoord = normalize(deltaTextCoord);
	int center = (nSteps-1)/2;
	vec3 blur = vec3(0.0);
	float tw = 0.0;
	float sigma = 0.25;
	float A = 1.0/sqrt(2.0*3.14159265359*sigma);
	textCoord -= deltaTextCoord*center*blurScale;

	for(int i=0; i < nSteps ; i++) {
		textCoord += deltaTextCoord*blurScale;
		float dist = (i-float(center))/center;
		float weight = A*exp(-(dist*dist)/(2.0*sigma));
		float sample = texture2D(gcolor, textCoord).a*weight;

		tw += weight;
		gr += sample;
	}

	surface.color.rgb += colorSunlight*exposure*(gr/tw)*(1.0 - rainStrength*0.8)*illuminationDecay*timeNoon*2;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////MAIN////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
void main() {

	surface.color = pow(texture2DLod(gcolor, texcoord.st, 0).rgb, vec3(2.2f));
	surface.normal = GetNormals(texcoord.st);
	surface.depth = GetDepth(texcoord.st);
	surface.linearDepth 		= ExpToLinearDepth(surface.depth); 				//Get linear scene depth
	surface.viewSpacePosition 	= GetViewSpacePosition(texcoord.st);
	surface.worldSpacePosition 	= gbufferModelViewInverse * surface.viewSpacePosition;
	FixNormals(surface.normal, surface.viewSpacePosition.xyz);
	surface.lightVector 		= lightVector;
	surface.sunlightVisibility 	= GetSunlightVisibility(texcoord.st);
	surface.upVector 			= upVector;
	vec4 wlv 					= shadowModelViewInverse * vec4(0.0f, 0.0f, 0.0f, 1.0f);
	surface.worldLightVector 	= normalize(wlv.xyz);

	surface.smoothness = GetSmoothness(texcoord.st);

	surface.specularity = GetSpecularity(texcoord.st);

	surface.specularColor = mix( vec3( 0.97 ), vec3( 1.0 ) - (surface.color * 500), surface.specularity );

	float ndotv = max( dot( surface.normal, -normalize( surface.viewSpacePosition.xyz ) ), 0.0f );

    // Multiply the fresnel by the smoothness, so that rougher things hafe less strong reflections
	surface.fresnel = calculateFresnelSchlick( surface.specularColor, ndotv ) * max( 0.01, surface.smoothness );

    // Multiply the fresnel by the specular color when the fragment is a metal
    // This is a fix because the normal equations give metals a specular color of pure white, which is not desireable
    surface.fresnel *= mix( vec3( 1.0 ), vec3( 1.0 ) - surface.specularColor, surface.specularity );

	surface.baseSpecularity = 0.02f;

	surface.mask.matIDs = GetMaterialIDs(texcoord.st);
	CalculateMasks(surface.mask);

	surface.cloudAlpha = 0.0f;
	#ifdef SMOOTH_SKY
		surface.cloudAlpha = texture2D(composite, texcoord.st, 2).g;
		SmoothSky(surface);
	#endif

	#ifdef CLOUD_PLANE
		CloudPlane(surface);
	#endif

	#ifdef GODRAYS

	#ifdef NO_UNDERWATER_RAYS
	if (isEyeInWater < 0.9) {
	#endif

	float truepos = sign(sunPosition.z); //temporary fix that check if the sun/moon position is correct
	if (truepos < 0.05) {
		calculateGodRays( surface );
	}
	#ifdef MOONRAYS
	else {
		calculateMoonRays( surface, truepos );
	}

	#endif
	#ifdef NO_UNDERWATER_RAYS
	}
	#endif
	#endif

	CalculateSpecularReflections(surface);
	CalculateSpecularHighlight(surface);

	//surface.color = surface.fresnel / 5000.0;
	surface.color = pow(surface.color, vec3(1.0f / 2.2f));
	gl_FragData[0] = vec4(surface.color, 1.0f);
	gl_FragData[1] = vec4( surface.specularity, 0.0, 0.0, 1.0 );
}
