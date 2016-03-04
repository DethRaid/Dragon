#version 450 compatibility

#define SHADOW_MAP_BIAS 0.80
#define FRAGMENT_SCALE 1.0
#define VERTEX_SCALE 0.5

#define EXTENDED_SHADOW_DISTANCE

#define GI_QUALITY 2.0 //[1.0 2.0 3.0 4.0] //sets the Quality of the GI Calculation
#define GI_Boost true

#define NEW_GI
#define NEW_GI_QUALITY 256 //[128 256 512]

//#define AO

//////////////////////////////INTERNAL VARIABLES////////////////////////////////////////////////////////////
//////////////////////////////INTERNAL VARIABLES////////////////////////////////////////////////////////////
//Do not change the name of these variables or their type. The Shaders Mod reads these lines and determines values to send to the inner-workings
//of the shaders mod. The shaders mod only reads these lines and doesn't actually know the real value assigned to these variables in GLSL.
//Some of these variables are critical for proper operation. Change at your own risk.

const int 		shadowMapResolution 	= 2048;
const float 	shadowDistance 			= 140;	// shadowDistance. 60 = Lowest Quality. 200 = Highest Quality [60 100 120 160 180 200]
const float 	shadowIntervalSize 		= 4.0;
const bool 		shadowHardwareFiltering0 = true;

const bool 		shadowtex1Mipmap = true;
const bool 		shadowtex1Nearest = true;
const bool 		shadowcolor0Mipmap = true;
const bool 		shadowcolor0Nearest = false;
const bool 		shadowcolor1Mipmap = true;
const bool 		shadowcolor1Nearest = false;

const int 		R8 						= 0;
const int 		RG8 					= 0;
const int 		RGB8 					= 1;
const int 		RGBA8 					= 1;
const int 		RGB16 					= 2;
const int 		RGBA16 					= 2;
const int 		colortex0Format 		= RGB16;
const int 		colortex1Format 		= RGB8;
const int 		colortex2Format 		= RGB16;
const int 		colortex3Format 		= RGB8;
const int 		colortex4Format 		= RGBA8;
const int 		colortex5Format 		= RGB8;

const float 	wetnessHalflife 		= 100.0;
const float 	drynessHalflife 		= 40.0;
const float 	centerDepthHalflife 	= 2.0;
const float 	eyeBrightnessHalflife 	= 10.0;

const float		sunPathRotation 		= -40.0;
const float 	ambientOcclusionLevel 	= 0.65;

const int 		noiseTextureResolution  = 64;

uniform sampler2D colortex2;
uniform sampler2D colortex1;
uniform sampler2D gdepthtex;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor;
uniform sampler2D shadowcolor1;
uniform sampler2D noisetex;
uniform sampler2D gdepth;
uniform sampler2DShadow shadow;

uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;

uniform vec3 previousCameraPosition;

uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform float rainStrength;
uniform float sunAngle;
uniform float frameTimeCounter;

uniform int isEyeInWater;

in vec3 lightVector;

in vec2 texcoord;

/* DRAWBUFFERS:46 */

struct MaskStruct {
	float materialIDs;
	float matIDs;

	float fullbright;
	float bit1;
	float bit2;
	float bit3;

	float sky;

	float grass;
	float leaves;
	float water;
} mask;

//////////////////////////////FUNCTIONS////////////////////////////////////////////////////////////
//////////////////////////////FUNCTIONS////////////////////////////////////////////////////////////

vec3 GetNormals(in vec2 coord) {
	return texture2DLod(colortex2, coord.st, 0).xyz * 2.0 - 1.0;
}

float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord.st).x;
}

vec4 GetViewSpacePosition(in vec2 coord) {		//Function that calculates the view-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
	float depth = GetDepth(coord);
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0 - 1.0, coord.t * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
		 fragposition /= fragposition.w;

	return fragposition;
}

vec4 GetViewSpacePosition(in vec2 coord, in float depth) {		//Function that calculates the view-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
	vec4 fragposition = gbufferProjectionInverse * vec4(vec3(coord.st, depth) * 2.0 - 1.0, 1.0);
		 fragposition /= fragposition.w;

	return fragposition;
}

vec4 ViewSpaceToWorldSpace(in vec4 viewSpacePosition) {
	vec4 pos = gbufferModelViewInverse * viewSpacePosition;
	return pos / pos.w;
}

vec4 WorldSpaceToShadowSpace(in vec4 worldSpacePosition) {
	vec4 pos = shadowProjection * shadowModelView * worldSpacePosition;
	return pos /= pos.w;
}

vec4 BiasShadowProjection(in vec4 projectedShadowSpacePosition) {
	#ifndef EXTENDED_SHADOW_DISTANCE
		float dist = length(projectedShadowSpacePosition.xy);
	#else
		vec2 pos = abs(projectedShadowSpacePosition.xy * 1.165);
		float dist = pow(pow(pos.x, 8) + pow(pos.y, 8), 1.0 / 8.0);
	#endif

	float distortFactor = (1.0 - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;

	projectedShadowSpacePosition.xy /= distortFactor;

	#ifdef EXTENDED_SHADOW_DISTANCE
		projectedShadowSpacePosition.z /= 4.0;
	#endif

	return projectedShadowSpacePosition;
}

vec2 BiasShadowMap(in vec2 ShadowMapPosition) {
	ShadowMapPosition = ShadowMapPosition * 2.0 - 1.0;

	#ifndef EXTENDED_SHADOW_DISTANCE
		float dist = length(ShadowMapPosition.xy);
	#else
		vec2 pos = abs(ShadowMapPosition.xy * 1.165);
		float dist = pow(pow(pos.x, 8) + pow(pos.y, 8), 1.0 / 8.0);
	#endif

	float distortFactor = (1.0 - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;

	ShadowMapPosition /= distortFactor;

	ShadowMapPosition = ShadowMapPosition * 0.5 + 0.5;

	return ShadowMapPosition;
}

vec3 CalculateNoisePattern1(const float size) {
	vec2 coord = texcoord * VERTEX_SCALE;

	coord *= vec2(viewWidth, viewHeight);
	coord = mod(coord, vec2(size));
	coord /= noiseTextureResolution;

	return texture2D(noisetex, coord).xyz;
}


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


void CalculateMasks(inout MaskStruct mask, in vec2 coord) {
	mask.materialIDs	= GetMaterialIDs(coord);
	mask.matIDs			= mask.materialIDs;

	mask.sky 			= GetMaterialMask(texcoord.st, 0, mask.matIDs);

	mask.grass 			= GetMaterialMask(texcoord.st, 2, mask.matIDs);
	mask.leaves	 		= GetMaterialMask(texcoord.st, 3, mask.matIDs);
	mask.water		 	= GetWaterMask(texcoord.st, mask.matIDs);
}


float CalculateAO(in vec4 viewSpacePosition, in vec3 normal, in vec2 coord, const in int sampleCount, in vec3 dither) {
	//Determine origin position
	vec3 origin = viewSpacePosition.xyz;

	vec3 randomRotation = normalize(dither.xyz * vec3(2.0, 2.0, 1.0) - vec3(1.0, 1.0, 0.0));

	vec3 tangent = normalize(randomRotation - normal * dot(randomRotation, normal));
	vec3 bitangent = cross(normal, tangent);
	mat3 tbn = mat3(tangent, bitangent, normal);

	float aoRadius   = 1.0;
	float zThickness = 0.25 * -viewSpacePosition.z;

	vec3 	samplePosition 		= vec3(0.0);
	vec4 	sampleViewSpace 	= vec4(0.0);
	float 	sampleDepth 		= 0.0;

	float ao = 0.0;

	for (int i = 0; i < sampleCount; i++) {
		vec3 kernel = vec3(texture2D(noisetex, vec2(0.1 + i / 64.0)).x * 2.0 - 1.0,
						   texture2D(noisetex, vec2(0.1 + i / 64.0)).y * 2.0 - 1.0,
						   texture2D(noisetex, vec2(0.1 + i / 64.0)).z);

		kernel = normalize(kernel);
		kernel *= dither.x + 0.01;

		samplePosition = tbn * kernel;
		samplePosition = origin + samplePosition * aoRadius;

		sampleViewSpace = gbufferProjection * vec4(samplePosition, 0.0);
		sampleViewSpace.xyz /= sampleViewSpace.w;
		sampleViewSpace.xyz = sampleViewSpace.xyz * 0.5 + 0.5;

		//Check depth at sample point
		sampleDepth = GetViewSpacePosition(sampleViewSpace.xy).z;

		//If point is behind geometry, buildup AO
		if (sampleDepth >= samplePosition.z && sampleDepth - samplePosition.z < zThickness) {
			ao += 1.0;
		}
	}

	ao /= sampleCount;
	ao = 1.0 - ao;

	return ao;
}

vec3 CalculateGI(in vec2 coord, in vec4 viewSpacePosition, in vec3 normal, const in float radius, const in float quality, in vec3 noisePattern, in MaskStruct mask) {
	float NdotL = dot(normal, lightVector);

	vec3 shadowSpaceNormal = (shadowModelView * gbufferModelViewInverse * vec4(normal, 0.0)).xyz;

	vec4 position = ViewSpaceToWorldSpace(viewSpacePosition);
		 position = WorldSpaceToShadowSpace(position);
		 position = position * 0.5 + 0.5;

	#ifndef EXTENDED_SHADOW_DISTANCE
		if (position.x <= 0.0 || position.x >= 1.0 ||
			position.y <= 0.0 || position.y >= 1.0 ||
			position.z <= 0.0 || position.z >= 1.0
			) return vec3(0.0);
	#endif

	float fademult 	= 0.15;
	//float lightMult	= clamp(1.0 - (length(viewSpacePosition.xyz) - shadowDistance) / shadowDistance, 0.0, 1.0);
	float lightMult	= 1.0;

	if (GI_Boost) {
		vec4 biasPos = BiasShadowProjection(position * 2.0 - 1.0) * 0.5 + 0.5;
		float sunlight = shadow2DLod(shadow, vec3(biasPos.xyz), 0).x;
		lightMult *= clamp(1.0 - NdotL * 4.0 * pow(sunlight, 8.0), 0.0 , 1.0);
		if (lightMult < 0.01) return vec3(0.0);

		float skylight = texture2D(colortex1, coord).b;
		if (skylight <= 0.01) return vec3(0.0);
	}

	const float range		= 2.0;
	const float A			= range * radius / 2048.0;
	const float interval	= 1.0 / quality;
	float depthLOD			= 2.0 * clamp(1.0 - length(viewSpacePosition.xyz) / shadowDistance, 0.0, 1.0);
	float sampleLOD			= 5.0 * clamp(1.0 - length(viewSpacePosition.xyz) / shadowDistance, 0.0, 1.0);
	vec2 V					= noisePattern.xy - 0.5;
	vec3 light				= vec3(0.0);
	int samples				= 0;

	for (float I = -range; I <= range; I += interval) {
		for (float O = -range; O <= range; O += interval) {
			vec2 randomPos		= (vec2(I, O) + V * interval) * A;
			vec3 samplePos		= vec3(position.xy + randomPos, 0.0);
			vec2 biasedSample	= BiasShadowMap(samplePos.xy);
			samplePos.z			= texture2DLod(shadowtex1, biasedSample, depthLOD).x;
			#ifdef EXTENDED_SHADOW_DISTANCE
				samplePos.z		= ((samplePos.z * 2.0 - 1.0) * 4.0) * 0.5 + 0.5;
			#endif
			vec3 sampleDir		= normalize(samplePos.xyz - position.xyz);
			vec3 shadowNormal	= texture2DLod(shadowcolor1, biasedSample, sampleLOD).xyz * 2.0 - 1.0;
			shadowNormal.xy		*= -1.0;
			float NdotS			= max(0.0, dot(shadowSpaceNormal, sampleDir * vec3(1.0, 1.0, -1.0)));
			float SdotN			= max(0.0, dot(shadowNormal, sampleDir));

			if (mask.leaves + mask.grass > 0.5) NdotS = 1.0;

			float falloff = length(samplePos.xyz - position.xyz);
			falloff = max(falloff, 0.005);
			falloff = 1.0 / (pow(falloff * (13600.0 / radius), 2.0) + 0.0001 * interval);
			falloff = max(0.0, falloff - 9e-05);

			vec3 sampleColor = pow(texture2DLod(shadowcolor, biasedSample, sampleLOD).rgb, vec3(2.2));

			light += sampleColor * falloff * SdotN * NdotS;
		}
	}

	light /= pow(4.0 / interval + 1.0, 2.0);

	light *= mix(0.0, 1.0, lightMult);

	return light * 1200.0;// / radius * 16.0;
}

vec3 CalculateGINew(in vec2 coord, in vec4 viewSpacePosition, in vec3 normal, const in float radius, const in float quality, in vec3 noisePattern, in MaskStruct mask) {
	float NdotL = dot(normal, lightVector);

	vec3 shadowSpaceNormal = (shadowModelView * gbufferModelViewInverse * vec4(normal, 0.0)).xyz;

	vec4 position = ViewSpaceToWorldSpace(viewSpacePosition);
		 position = WorldSpaceToShadowSpace(position);
		 position = position * 0.5 + 0.5;

	#ifndef EXTENDED_SHADOW_DISTANCE
		if (position.x <= 0.0 || position.x >= 1.0 ||
			position.y <= 0.0 || position.y >= 1.0 ||
			position.z <= 0.0 || position.z >= 1.0
			) return vec3(0.0);
	#endif

	float fademult 	= 0.15;
	float lightMult	= 1.0;

	if (GI_Boost) {
		vec4 biasPos = BiasShadowProjection(position * 2.0 - 1.0) * 0.5 + 0.5;
		float sunlight = shadow2DLod(shadow, vec3(biasPos.xyz), 0).x;
		lightMult *= clamp(1.0 - NdotL * 4.0 * pow(sunlight, 8.0), 0.0 , 1.0);
		if (lightMult < 0.01) return vec3(0.0);

		float skylight = texture2D(colortex1, coord).b;
		if (skylight <= 0.01) return vec3(0.0);
	}

	const float interval = 1.0 / quality;

	float sampleLOD	= 3.0 * clamp(1.0 - length(viewSpacePosition.xyz) / shadowDistance, 0.0, 1.0);

	vec2 noiseOffset = noisePattern.xy - 0.5;
	noiseOffset *= 3;
	vec3 light = vec3(0.0);
	int samples	= 0;

	#define GI_SAMPLE_RADIUS 7
	#define PI 3.14

	for(int i = 0; i < NEW_GI_QUALITY; i++) {
		float percentage_done = float(i) / float(NEW_GI_QUALITY);
		float dist_from_center = GI_SAMPLE_RADIUS * percentage_done;

		float theta = percentage_done * (NEW_GI_QUALITY / 16) * PI;
		vec2 offset = vec2(cos(theta), sin(theta)) * (dist_from_center * 6);
		offset += noiseOffset;
		offset /= shadowMapResolution;

		vec3 samplePos = vec3(position.xy + offset, 0.0);
		vec2 biasedSample	= BiasShadowMap(samplePos.xy);
		samplePos.z	= texture2DLod(shadowtex1, biasedSample, 0.0).x;

		#ifdef EXTENDED_SHADOW_DISTANCE
			samplePos.z	= ((samplePos.z * 2.0 - 1.0) * 4.0) * 0.5 + 0.5;
		#endif

		vec3 sampleDir = normalize(samplePos.xyz - position.xyz);
		vec3 shadowNormal	= texture2DLod(shadowcolor1, biasedSample, 0).xyz * 2.0 - 1.0;
		shadowNormal.xy	*= -1.0;

	//return shadowNormal;

		float viewNormalCoeff	= max(0.0, dot(shadowSpaceNormal, sampleDir * vec3(1.0, 1.0, -1.0)));
		float shadowNormalCoeff	= max(0.0, dot(shadowNormal, sampleDir));

		if (mask.leaves + mask.grass > 0.5) viewNormalCoeff = 1.0;

		float falloff = length(samplePos.xyz - position.xyz);
		falloff = max(falloff, 0.005);
		falloff = 1.0 / (pow(falloff * (40000.0 / radius), 2.0) + 0.0001);
		falloff = max(0.0, falloff - 9e-05);

		vec3 sampleColor = pow(texture2DLod(shadowcolor, biasedSample, sampleLOD).rgb, vec3(2.2));
		//return sampleColor;

		light += sampleColor * falloff * shadowNormalCoeff * viewNormalCoeff;
	}

	light /= NEW_GI_QUALITY * 5 * radius;
	light *= mix(0.0, 1.0, lightMult);

	return light * 12000.0;
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
	float speed = 0.6f;

  vec2 p = position.xz / 20.0f;

  p.xy -= position.y / 20.0f;

  p.x = -p.x;

  p.x += (frameTimeCounter / 40.0f) * speed;
  p.y -= (frameTimeCounter / 40.0f) * speed;

  float weight = 1.0f;
  float weights = weight;

  float allwaves = 0.0f;

  float wave = 0.0;
	//wave = textureSmooth(noisetex, (p * vec2(2.0f, 1.2f))  + vec2(0.0f,  p.x * 2.1f) ).x;
	p /= 2.1f; 	/*p *= pow(2.0f, 1.0f);*/ 	p.y -= (frameTimeCounter / 20.0f) * speed; p.x -= (frameTimeCounter / 30.0f) * speed;
  //allwaves += wave;

  weight = 4.1f;
  weights += weight;
      wave = textureSmooth(noisetex, (p * vec2(2.0f, 1.4f))  + vec2(0.0f,  -p.x * 2.1f) ).x;
			p /= 1.5f;/*p *= pow(2.0f, 2.0f);*/ 	p.x += (frameTimeCounter / 20.0f) * speed;
      wave *= weight;
  allwaves += wave;

  weight = 17.25f;
  weights += weight;
      wave = (textureSmooth(noisetex, (p * vec2(1.0f, 0.75f))  + vec2(0.0f,  p.x * 1.1f) ).x);		p /= 1.5f; 	p.x -= (frameTimeCounter / 55.0f) * speed;
      wave *= weight;
  allwaves += wave;

  weight = 15.25f;
  weights += weight;
      wave = (textureSmooth(noisetex, (p * vec2(1.0f, 0.75f))  + vec2(0.0f,  -p.x * 1.7f) ).x);		p /= 1.9f; 	p.x += (frameTimeCounter / 155.0f) * speed;
      wave *= weight;
  allwaves += wave;

  weight = 29.25f;
  weights += weight;
      wave = abs(textureSmooth(noisetex, (p * vec2(1.0f, 0.8f))  + vec2(0.0f,  -p.x * 1.7f) ).x * 2.0f - 1.0f);		p /= 2.0f; 	p.x += (frameTimeCounter / 155.0f) * speed;
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

	float WAVE_HEIGHT = 1.5;

	const float sampleDistance = 3.0f;

	position -= vec3(0.005f, 0.0f, 0.005f) * sampleDistance;

	float wavesCenter = GetWaves(position);
	float wavesLeft = GetWaves(position + vec3(0.01f * sampleDistance, 0.0f, 0.0f));
	float wavesUp   = GetWaves(position + vec3(0.0f, 0.0f, 0.01f * sampleDistance));

	vec3 wavesNormal;
		 wavesNormal.r = wavesCenter - wavesLeft;
		 wavesNormal.g = wavesCenter - wavesUp;

		 wavesNormal.r *= 30.0f * WAVE_HEIGHT / sampleDistance;
		 wavesNormal.g *= 30.0f * WAVE_HEIGHT / sampleDistance;

		//  wavesNormal.b = sqrt(1.0f - wavesNormal.r * wavesNormal.r - wavesNormal.g * wavesNormal.g);
		 wavesNormal.b = 1.0;
		 wavesNormal.rgb = normalize(wavesNormal.rgb);



	return wavesNormal.rgb;
}

//////////////////////////////MAIN////////////////////////////////////////////////////////////
//////////////////////////////MAIN////////////////////////////////////////////////////////////

void main() {

	CalculateMasks(mask, texcoord);
	gl_FragData[1] = vec4(GetWavesNormal(vec3(texcoord.s * 50.0, 1.0, texcoord.t * 50.0)) * 0.5 + 0.5, 1.0);
	if (mask.sky + mask.water > 0.5) { gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0); return; }

	vec3	normal 				= GetNormals(texcoord);
	float	depth  				= GetDepth(texcoord);
	vec4	viewSpacePosition	= GetViewSpacePosition(texcoord, depth);
	vec3	noisePattern		= CalculateNoisePattern1(4);

	vec4 light = vec4(0.0, 0.0, 0.0, 1.0);

	#ifdef AO
		light.a		= CalculateAO(viewSpacePosition, normal, texcoord, 8, noisePattern);
	#endif

	if (isEyeInWater > 0.5 || rainStrength > 0.99) { gl_FragData[0] = light; return; }

	#ifdef NEW_GI
		light.rgb	= CalculateGINew(texcoord, viewSpacePosition, normal, 64.0, 8.0, noisePattern, mask);
	#else
		light.rgb	= CalculateGI(texcoord, viewSpacePosition, normal, 16.0, GI_QUALITY, noisePattern, mask);
	#endif

	gl_FragData[0] = vec4(pow(light.rgb, vec3(1.0 / 2.2)), light.a);
}
