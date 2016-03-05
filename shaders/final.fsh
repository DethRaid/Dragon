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

#define SATURATION_BOOST 0.2f 			//How saturated the final image should be. 0 is unchanged saturation. Higher values create more saturated image

#define Color_desaturation  0.0		// Color_desaturation. 0.0 = full color. 1.0 = Black & White [0.0 0.25 0.50 0.75 1.0]

//#define MOON_GLOW		//Moon lens flare

#define RAIN_LENS

#define RainFog2						//This is a second layer of fog that more or less masks the rain on the horizon
#define FOG_DENSITY2	0.010			//Default is 0.043	[0.010 0.020 0.030 0.040]

#define New_GlowStone					//disable to return GlowStones to Continuum Default

/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////END OF CONFIGURABLE VARIABLES/////////////////////////////////////////////////////////////////////////////////////////////////////////////

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gdepthtex;
uniform sampler2D gnormal;
uniform sampler2D gaux1;

varying vec4 texcoord;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float aspectRatio;
uniform float frameTimeCounter;

uniform int   isEyeInWater;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;

varying float timeSunrise;
varying float timeNoon;
varying float timeSunset;
varying float timeMidnight;

#define BANDING_FIX_FACTOR 1.0f

float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;


/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
vec3 	GetTexture(in sampler2D tex, in vec2 coord) {				//Perform a texture lookup with BANDING_FIX_FACTOR compensation
	return pow(texture2D(tex, coord).rgb, vec3(BANDING_FIX_FACTOR + 1.2f));
}

vec3 	GetTextureLod(in sampler2D tex, in vec2 coord, in int level) {				//Perform a texture lookup with BANDING_FIX_FACTOR compensation
	return pow(texture2DLod(tex, coord, level).rgb, vec3(BANDING_FIX_FACTOR + 1.2f));
}

vec3 	GetTexture(in sampler2D tex, in vec2 coord, in int LOD) {	//Perform a texture lookup with BANDING_FIX_FACTOR compensation and lod offset
	return pow(texture2D(tex, coord, LOD).rgb, vec3(BANDING_FIX_FACTOR));
}

float 	GetDepthLinear(in vec2 coord) {					//Function that retrieves the scene depth. 0 - 1, higher values meaning farther away
	return 2.0f * near * far / (far + near - (2.0f * texture2D(gdepthtex, coord).x - 1.0f) * (far - near));
}

vec3 	GetColorTexture(in vec2 coord) {
	return GetTextureLod(gnormal, coord.st, 0).rgb;
}

float 	GetMaterialIDs(in vec2 coord) {			//Function that retrieves the texture that has all material IDs stored in it
	return texture2D(gdepth, coord).r;
}

vec4 cubic(float x) {
    float x2 = x * x;
    float x3 = x2 * x;
    vec4 w;
    w.x =   -x3 + 3*x2 - 3*x + 1;
    w.y =  3*x3 - 6*x2       + 4;
    w.z = -3*x3 + 3*x2 + 3*x + 1;
    w.w =  x3;
    return w / 6.f;
}

vec4 BicubicTexture(in sampler2D tex, in vec2 coord) {
	vec2 resolution = vec2(viewWidth, viewHeight);

	coord *= resolution;

	float fx = fract(coord.x);
    float fy = fract(coord.y);
    coord.x -= fx;
    coord.y -= fy;

    vec4 xcubic = cubic(fx);
    vec4 ycubic = cubic(fy);

    vec4 c = vec4(coord.x - 0.5, coord.x + 1.5, coord.y - 0.5, coord.y + 1.5);
    vec4 s = vec4(xcubic.x + xcubic.y, xcubic.z + xcubic.w, ycubic.x + ycubic.y, ycubic.z + ycubic.w);
    vec4 offset = c + vec4(xcubic.y, xcubic.w, ycubic.y, ycubic.w) / s;

    vec4 sample0 = texture2D(tex, vec2(offset.x, offset.z) / resolution);
    vec4 sample1 = texture2D(tex, vec2(offset.y, offset.z) / resolution);
    vec4 sample2 = texture2D(tex, vec2(offset.x, offset.w) / resolution);
    vec4 sample3 = texture2D(tex, vec2(offset.y, offset.w) / resolution);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix( mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

bool 	GetMaterialMask(in vec2 coord, in int ID) {
	float	  matID = floor(GetMaterialIDs(coord) * 255.0f);

	//Catch last part of sky
	if (matID > 254.0f) {
		matID = 0.0f;
	}

	if (matID == ID) {
		return true;
	} else {
		return false;
	}
}

bool 	GetMaterialMask(in vec2 coord, in int ID, float matID) {
	matID = floor(matID * 255.0f);

	if (matID > 254.0f) {
		matID = 0.0f;
	}

	if (matID == ID) {
		return true;
	} else {
		return false;
	}
}

void 	Vignette(inout vec3 color) {
	float dist = distance(texcoord.st, vec2(0.5f)) * 2.0f;
		  dist /= 1.5142f;

		  dist = pow(dist, 1.1f);

	color.rgb *= 1.0f - dist;

}

void CalculateExposure(inout vec3 color) {
	float exposureMax = 1.55f;
	exposureMax *= mix(1.0f, 0.25f, timeSunrise);
	exposureMax *= mix(1.0f, 0.25f, timeSunset);
	exposureMax *= mix(1.0f, 0.0f, timeMidnight);
	exposureMax *= mix(1.0f, 0.25f, rainStrength);

	float exposureMin = 0.07f;
	float exposure = pow(eyeBrightnessSmooth.y / 240.0f, 6.0f) * exposureMax + exposureMin;

	color.rgb /= vec3(exposure);
}

/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCTS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct BloomDataStruct
{
	vec3 blur0;
	vec3 blur1;
	vec3 blur2;
	vec3 blur3;
	vec3 blur4;
	vec3 blur5;
	vec3 blur6;

	vec3 bloom;
} bloomData;


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

} mask;


/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////STRUCT FUNCTIONS//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

void 	CalculateMasks(inout MaskStruct mask) {
	mask.glowstone = GetMaterialMask(texcoord.st, 32, mask.matIDs);
}

void 	CalculateBloom(inout BloomDataStruct bloomData) {		//Retrieve previously calculated bloom textures
	//constants for bloom bloomSlant
	const float    bloomSlant = 0.0f;
	const float[7] bloomWeight = float[7] (pow(7.0f, bloomSlant),
										   									 pow(6.0f, bloomSlant),
										   							 		 pow(5.0f, bloomSlant),
										   							 		 pow(4.0f, bloomSlant),
										   							 		 pow(3.0f, bloomSlant),
										   							 		 pow(2.0f, bloomSlant),
										   							 		 1.0f);

	vec2 recipres = vec2(1.0f / viewWidth, 1.0f / viewHeight);

	bloomData.blur0  =  pow(BicubicTexture(gcolor, (texcoord.st - recipres * 0.5f) * (1.0f / pow(2.0f, 	2.0f)) + 	vec2(0.0f, 0.0f) + vec2(0.000f, 0.000f)).rgb * bloomWeight[0], vec3(1.0f + 1.2f));
	bloomData.blur1  =  pow(BicubicTexture(gcolor, (texcoord.st - recipres * 0.5f) * (1.0f / pow(2.0f, 	3.0f)) + 	vec2(0.0f, 0.25f)	+ vec2(0.000f, 0.025f)).rgb * bloomWeight[1], vec3(1.0f + 1.2f));
	bloomData.blur2  =  pow(BicubicTexture(gcolor, (texcoord.st - recipres * 0.5f) * (1.0f / pow(2.0f, 	4.0f)) + 	vec2(0.125f, 0.25f)	+ vec2(0.025f, 0.025f)).rgb * bloomWeight[2], vec3(1.0f + 1.2f));
	bloomData.blur3  =  pow(BicubicTexture(gcolor, (texcoord.st - recipres * 0.5f) * (1.0f / pow(2.0f, 	5.0f)) + 	vec2(0.1875f, 0.25f) + vec2(0.050f, 0.025f)).rgb * bloomWeight[3], vec3(1.0f + 1.2f));
	bloomData.blur4  =  pow(BicubicTexture(gcolor, (texcoord.st - recipres * 0.5f) * (1.0f / pow(2.0f, 	6.0f)) + 	vec2(0.21875f, 0.25f)	+ vec2(0.075f, 0.025f)).rgb * bloomWeight[4], vec3(1.0f + 1.2f));
	bloomData.blur5  =  pow(BicubicTexture(gcolor, (texcoord.st - recipres * 0.5f) * (1.0f / pow(2.0f, 	7.0f)) + 	vec2(0.25f, 0.25f) + vec2(0.100f, 0.025f)).rgb * bloomWeight[5], vec3(1.0f + 1.2f));
	bloomData.blur6  =  pow(BicubicTexture(gcolor, (texcoord.st - recipres * 0.5f) * (1.0f / pow(2.0f, 	8.0f)) + 	vec2(0.28f, 0.25f) + vec2(0.125f, 0.025f)).rgb * bloomWeight[6], vec3(1.0f + 1.2f));

	bloomData.bloom += bloomData.blur0;
	bloomData.bloom += bloomData.blur1;
	bloomData.bloom += bloomData.blur2;
	bloomData.bloom += bloomData.blur3;
 	bloomData.bloom += bloomData.blur4;
 	bloomData.bloom += bloomData.blur5;
 	bloomData.bloom += bloomData.blur6;
}

void 	AddRainFogScatter(inout vec3 color, in BloomDataStruct bloomData) {
	const float    bloomSlant = 0.0f;
	const float[7] bloomWeight = float[7] (pow(7.0f, bloomSlant),
																				 pow(6.0f, bloomSlant),
										   							 		 pow(5.0f, bloomSlant),
										   							 		 pow(4.0f, bloomSlant),
										   							 		 pow(3.0f, bloomSlant),
										   							 		 pow(2.0f, bloomSlant),
										   							 		 1.0f);

	vec3 fogBlur = bloomData.blur0 * bloomWeight[6] +
			       		 bloomData.blur1 * bloomWeight[5] +
			       		 bloomData.blur2 * bloomWeight[4] +
			       		 bloomData.blur3 * bloomWeight[3] +
			       		 bloomData.blur4 * bloomWeight[2] +
			       		 bloomData.blur5 * bloomWeight[1] +
			       		 bloomData.blur6 * bloomWeight[0];

	float fogTotalWeight = 	bloomWeight[0] +
			       							bloomWeight[1] +
			       							bloomWeight[2] +
			       							bloomWeight[3] +
			       							bloomWeight[4] +
			       							bloomWeight[5] +
			       							bloomWeight[6];

	fogBlur /= fogTotalWeight;

	float linearDepth = GetDepthLinear(texcoord.st);

	float fogDensity = FOG_DENSITY2 * (rainStrength);
	float visibility = 1.0f / (pow(exp(linearDepth * fogDensity), 1.0f));
	float fogFactor = 1.0f - visibility;
	fogFactor = clamp(fogFactor, 0.0f, 1.0f);
	fogFactor *= mix(0.0f, 1.0f, pow(eyeBrightnessSmooth.y / 240.0f, 6.0f));

	color = mix(color, fogBlur, fogFactor * 1.0f);
}

void TonemapReinhard05(inout vec3 color, BloomDataStruct bloomData) {
	float averageLuminance = 0.000055f;
	vec3 IAverage = vec3(averageLuminance);

	vec3 value = color.rgb / (color.rgb + IAverage);

	color.rgb = value * 1.195f - 0.00f;
	color.rgb = min(color.rgb, vec3(1.0f));
	color.rgb = pow(color.rgb, vec3(1.0f / 2.2f));
}

/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main() {
	vec2 fake_refract = vec2(sin(frameTimeCounter * 1.7 + texcoord.x * 50.0 + texcoord.y * 25.0), cos(frameTimeCounter * 2.5 + texcoord.y * 100.0 + texcoord.x * 25.0)) * isEyeInWater;
	vec2 Fake_Refract_1 = vec2(sin(frameTimeCounter * 1.7 + texcoord.x * 50.0 + texcoord.y * 25.0), cos(frameTimeCounter + texcoord.y * 100.0 + texcoord.x * 25.0));

	vec3 color = GetColorTexture(texcoord.st + fake_refract * 0.005 + 0.0045 * (Fake_Refract_1 * 0.0045));	//Sample gcolor texture

	mask.matIDs = GetMaterialIDs(texcoord.st);
	CalculateMasks(mask);

	#ifdef New_GlowStone
		color /= mix(1.0f, 15.0f, float(mask.glowstone)* timeMidnight);
		color /= mix(1.0f, 2.5f, float(mask.glowstone)* timeNoon);
		color /= mix(1.0f, 7.0f,float(mask.glowstone) * mix(1.0f, 0.0f, pow(eyeBrightnessSmooth.y / 240.0f, 2.0f))* timeNoon);
	#endif

	CalculateBloom(bloomData);			//Gather bloom textures
	color = mix(color, bloomData.bloom, vec3(0.0150f));

	#ifdef RainFog2
		AddRainFogScatter(color, bloomData);
	#endif

	Vignette(color);

	CalculateExposure(color);

	TonemapReinhard05(color, bloomData);

	#ifdef MOON_GLOW
		MoonGlow(color);
	#endif

	color = mix(color, vec3(dot(color, vec3(1.0 / 3.0))), vec3(Color_desaturation));

	gl_FragColor = vec4(color.rgb, 1.0f);
	//gl_FragColor = vec4(texture2D(gaux1, texcoord.st / 2.0).rgb, 1.0f);
}
