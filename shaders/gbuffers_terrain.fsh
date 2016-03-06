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



////////////////////////////////////////////////////ADJUSTABLE VARIABLES/////////////////////////////////////////////////////////

#define NORMAL_MAP_MAX_ANGLE 1.0f   		//The higher the value, the more extreme per-pixel normal mapping (bump mapping) will be.
#define TILE_RESOLUTION 128

#define PARALLAX			//POM, need supported texture pack to get 3D look to blocks
	//#define LQ_POM						//dissable this for High Quality POM at a cost of about 7fps avg
	#define POM_Offset 64		//[16 32 64 128 512]	//Set this to the Resolution of your texture pack
	#define POM_Offset2 32		//[16 32 64 128 512]	//must always be half of what POM_Offset is

#define SPECULARITY		//Please use the Specular ON/OFF function in the shaders menu to turn Specular off to save fps
	#define SPEC_BRIGHTNESS		0.6f	//[0.1 0.4 0.6 0.85 1.0 1.2]
	// default is 1.0f - lower this number to increase the specular brightness for New specular
		//---for Resource pack Faithful recommended 1.0f, for Ovos Rustic and Chromahills recommended 0.7f---//

	#define SPEC_BRIGHTNESS_OLD	1.75f	//default is 1.0f if not using a supported texture pack - higher this number lowers the specular best for supported texture packs

// OLD_SPECULAR					// add back the #define to enable, Old specular from 1st SEUS complete, works best for our custom specular maps for ChromaHills
#define NEW_SPECULAR					// New specular from SEUS 10.1 and 10.2 preview

//#define TEMP_UNDERGROUND_LIGHT_FIX

///////////////////////////////////////////////////END OF ADJUSTABLE VARIABLES///////////////////////////////////////////////////

/* DRAWBUFFERS:01235 */

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;
uniform float wetness;
uniform float frameTimeCounter;
uniform vec3 sunPosition;
uniform vec3 upPosition;

uniform int   isEyeInWater;

uniform float rainStrength;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 worldPosition;
varying vec4 vertexPos;
varying mat3 tbnMatrix;

varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 worldNormal;

varying float materialIDs;

varying float distance;
varying float idCheck;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

const float bump_distance = 78.0f;
const float fademult = 0.1f;

vec2 OffsetCoord(in vec2 coord, in vec2 offset, in int level) {
	int tileResolution = TILE_RESOLUTION;
	ivec2 atlasTiles = ivec2(POM_Offset, POM_Offset2);
	ivec2 atlasResolution = tileResolution * atlasTiles;

	coord *= atlasResolution;

	vec2 offsetCoord = coord + mod(offset.xy * atlasResolution, vec2(tileResolution));

	vec2 minCoord = vec2(coord.x - mod(coord.x, tileResolution), coord.y - mod(coord.y, tileResolution));
	vec2 maxCoord = minCoord + tileResolution;

	if (offsetCoord.x > maxCoord.x) {
		offsetCoord.x -= tileResolution;
	} else if (offsetCoord.x < minCoord.x) {
		offsetCoord.x += tileResolution;
	}

	if (offsetCoord.y > maxCoord.y) {
		offsetCoord.y -= tileResolution;
	} else if (offsetCoord.y < minCoord.y) {
		offsetCoord.y += tileResolution;
	}

	offsetCoord /= atlasResolution;

	return offsetCoord;
}

vec3 Get3DNoise(in vec3 pos) {
	pos.z += 0.0f;
	vec3 p = floor(pos);
	vec3 f = fract(pos);
	f = f * f * (3.0f - 2.0f * f);

	vec2 uv =  (p.xy + p.z * vec2(17.0f, 37.0f)) + f.xy;
	vec2 uv2 = (p.xy + (p.z + 1.0f) * vec2(17.0f, 37.0f)) + f.xy;
	vec2 coord =  (uv  + 0.5f) / 64.0f;
	vec2 coord2 = (uv2 + 0.5f) / 64.0f;
	vec3 xy1 = texture2D(noisetex, coord).xyz;
	vec3 xy2 = texture2D(noisetex, coord2).xyz;
	return mix(xy1, xy2, vec3(f.z));
}

vec3 Get3DNoiseNormal(in vec3 pos) {
	float center = Get3DNoise(pos + vec3( 0.0f, 0.0f, 0.0f)).x * 2.0f - 1.0f;
	float left 	 = Get3DNoise(pos + vec3( 0.1f, 0.0f, 0.0f)).x * 2.0f - 1.0f;
	float up     = Get3DNoise(pos + vec3( 0.0f, 0.1f, 0.0f)).x * 2.0f - 1.0f;

	vec3 noiseNormal;
	noiseNormal.x = center - left;
	noiseNormal.y = center - up;

	noiseNormal.x *= 0.2f;
	noiseNormal.y *= 0.2f;

	noiseNormal.b = sqrt(1.0f - noiseNormal.x * noiseNormal.x - noiseNormal.g * noiseNormal.g);
	noiseNormal.b = 0.0f;

	return noiseNormal.xyz;
}


vec3 CalculateRainBump(in vec3 pos) {
	pos.y += frameTimeCounter * 3.0f;
	pos.xz *= 1.0f;
	pos.y += Get3DNoise(pos.xyz * vec3(1.0f, 0.0f, 1.0f)).y * 2.0f;

	vec3 p = pos;

	vec3 noiseNormal = Get3DNoiseNormal(p);	p.y += 0.25f;
	noiseNormal += Get3DNoiseNormal(p); p.y += 0.5f;
	noiseNormal += Get3DNoiseNormal(p); p.y += 0.75f;
	noiseNormal += Get3DNoiseNormal(p);
	noiseNormal /= 4.0f;

	return Get3DNoiseNormal(pos).xyz;
}

float GetModulatedRainSpecular(in vec3 pos) {
	pos.xz *= 1.0f;
	pos.y *= 0.2f;

	vec3 p = pos;

	float n = Get3DNoise(p).y;
	n += Get3DNoise(p / 2.0f).x * 2.0f;
	n += Get3DNoise(p / 4.0f).x * 4.0f;

	n /= 6.0f;

	return n;
}


vec4 GetTexture(in sampler2D tex, in vec2 coord) {
	#ifdef PARALLAX
		vec4 t = vec4(0.0f);
		if (distance < 10.0f) {
			t = texture2DLod(tex, coord, 0);
		} else {
			t = texture2D(tex, coord);
		}

		return t;

	#else
		return texture2D(tex, coord);
	#endif
}


vec2 CalculateParallaxCoord(in vec2 coord, in vec3 viewVector) {
	vec2 parallaxCoord = coord.st;
	const int maxSteps = 112;
	vec3 stepSize = vec3(0.002f, 0.002f, 0.2f);

	float parallaxDepth = 0.5f;

	if(materialIDs > 2.5f && materialIDs < 3.5f)
		parallaxDepth = 2.0f;

	stepSize.xy *= parallaxDepth;

	#ifdef LQ_POM
		float heightmap = GetTexture(normals, coord.st).a;
	#else
		float heightmap = texture2D(normals, coord.st).a;
	#endif

	vec3 pCoord = vec3(0.0f, 0.0f, 1.0f);

	if(heightmap < 1.0f) {
		vec3 step = viewVector * stepSize;

		#ifdef LQ_POM
			float distAngleWeight = ((distance * 0.6f) * (2.1f - viewVector.z)) * 0.070f;
		#else
			float distAngleWeight = ((distance * 0.6f) * (2.1f - viewVector.z)) / 16.0;
		#endif

		step *= distAngleWeight;

		#ifdef LQ_POM
			step *= 2.0f;
		#endif

		float sampleHeight = heightmap;

		for (int i = 0; sampleHeight < pCoord.z && i < 240; ++i) {
			pCoord.xy = mix(pCoord.xy, pCoord.xy + step.xy, clamp((pCoord.z - sampleHeight) / (stepSize.z * 1.0 * distAngleWeight / (-viewVector.z + 0.05)), 0.0, 1.0));
			pCoord.z += step.z;

			#ifdef LQ_POM
				sampleHeight = GetTexture(normals, OffsetCoord(coord.st, pCoord.st, 0)).a;
			#else
				sampleHeight = texture2D(normals, OffsetCoord(coord.st, pCoord.st, 0)).a;
			#endif
		}

		parallaxCoord.xy = OffsetCoord(coord.st, pCoord.st, 0);
	}
	return parallaxCoord;
}

void main() {
	vec4 modelView = (gl_ModelViewMatrix * vertexPos);

	vec3 viewVector = normalize(tbnMatrix * modelView.xyz);
	viewVector.x /= 2.0f;
	viewVector = normalize(viewVector);

	vec2 parallaxCoord = texcoord.st;

	#ifdef PARALLAX
		if (distance < 50.0f)
			parallaxCoord = CalculateParallaxCoord(texcoord.st, viewVector);
	#endif

	float height = GetTexture(normals, parallaxCoord).a;

	float w = wetness;

	vec4 spec = GetTexture(specular, parallaxCoord.st);
	vec4 specs = texture2D(specular, parallaxCoord.st);

	float wet = GetModulatedRainSpecular(worldPosition.xyz);

	#ifdef TEMP_UNDERGROUND_LIGHT_FIX
		//store lightmap in auxilliary texture. r = torch light. g = lightning. b = sky light.
		vec4 lightmap = vec4(0.0f, 0.0f, 0.0f, 1.0f);

		//Separate lightmap types
		lightmap.r = clamp((lmcoord.s * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);
		lightmap.b = clamp((lmcoord.t * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);

		lightmap.b = pow(lightmap.b, 1.0f);
		lightmap.r = pow(lightmap.r, 3.0f);

		float wetfactor = clamp(lightmap.b * 1.05f - 0.9f, 0.0f, 0.1f) / 0.1f;
		wetfactor *= w;
	#else

		vec4 mclightmap = vec4(0.0f, 0.0f, 0.0f, 1.0f);
		vec4 mclightmaps = vec4(0.0f, 0.0f, 0.0f, 1.0f);

		//Separate lightmap types
		mclightmap.r = clamp((lmcoord.s * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);

		if (isEyeInWater > 0.9 || rainStrength > 0.9) {
			mclightmap.b = clamp((lmcoord.t * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);
			mclightmaps.b = clamp((lmcoord.t * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);
		} else {
			mclightmap.b = texture2D(lightmap, vec2(0.0/16., lmcoord.t)).r*2.85 * pow(1-rainStrength, -0.27f);
		}

		mclightmaps.b = clamp((lmcoord.t * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);


		mclightmap.b = pow(mclightmap.b, 1.0f);
		mclightmap.r = pow(mclightmap.r, 3.0f);

		float wetfactor = clamp(mclightmaps.b * 1.05f - 0.9f, 0.0f, 0.1f) / 0.1f;
		wetfactor *= w;
	#endif

	spec.g *= wetfactor;

	vec4 frag2;

	if (distance < bump_distance) {
		vec3 bump = GetTexture(normals, parallaxCoord.st).rgb * 2.0f - 1.0f;

		float bumpmult = clamp(bump_distance * fademult - distance * fademult, 0.0f, 1.0f) * NORMAL_MAP_MAX_ANGLE;
	  	bumpmult *= 1.0f - (clamp(spec.g * 1.0f - 0.0f, 0.0f, 1.0f) * 0.75f);

		bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
		frag2 = vec4(bump * tbnMatrix * 0.5 + 0.5, 1.0);

	} else {
		frag2 = vec4((normal) * 0.5f + 0.5f, 1.0f);
	}

	//Diffuse
	vec4 albedo = GetTexture(texture, parallaxCoord.st) * color;
	vec3 upVector = normalize(upPosition);
	float darkFactor = clamp(spec.g, 0.0f, 0.2f) / 0.2f;
	albedo.rgb = pow(albedo.rgb, vec3(mix(1.0f, 1.25f, darkFactor)));

	float metallicMask = 0.0f;

	if (abs(materialIDs - 20.0f) < 0.1f
	|| abs(materialIDs - 21.0f) < 0.1f
	|| abs(materialIDs - 22.0f) < 0.1f
	|| abs(materialIDs - 23.0f) < 0.1f) {
		metallicMask = 1.0f;
	}

	float mats_1 = materialIDs;
	mats_1 += 0.1f;

	gl_FragData[0] = albedo;

	//Depth
	#ifdef TEMP_UNDERGROUND_LIGHT_FIX
		gl_FragData[1] = vec4(mats_1/255.0f, lightmap.r, lightmap.b, 1.0f);
	#else
		gl_FragData[1] = vec4(mats_1/255.0f, mclightmap.r, mclightmap.b, 1.0f);
	#endif

	//normal
	gl_FragData[2] = frag2;

	#ifdef SPECULARITY
		// red = shininess
		// green = metallic
		// blue = emissive
		// alpha = ao
		gl_FragData[3] = spec;
	#endif

	gl_FragData[4] = frag2;
}
