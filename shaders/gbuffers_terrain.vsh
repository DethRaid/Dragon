#version 120

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 worldPosition;

attribute vec4 mc_Entity;

uniform int worldTime;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform float aspectRatio;

uniform sampler2D noisetex;

varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;
varying vec2 waves;
varying vec3 worldNormal;

varying float distance;
//varying float idCheck;

varying float materialIDs;

varying mat3 tbnMatrix;
varying vec4 vertexPos;
varying vec3 vertexViewVector;

varying float metalness_in;
varying float smoothness_in;

//If you're using 1.7.2, it has a texture glitch where certain sides of blocks are mirrored. Enable the following to compensate and keep lighting correct
//#define TEXTURE_FIX

#define WAVING_GRASS
#define WAVING_WHEAT
#define WAVING_LEAVES
#define WAVING_VINES
#define WAVING_LILIES

//Added
#define WAVING_CARROTS
#define WAVING_NETHER_WART
#define WAVING_POTATOES


#define ENTITY_VINES        106.0

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
	int resolution = 64;

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

vec4 TextureSmooth(in sampler2D tex, in vec2 coord) {
	int level = 0;
	vec2 res = vec2(64.0f);
	coord = coord * res;
	vec2 i = floor(coord);
	vec2 f = fract(coord);
	f = f * f * (3.0f - 2.0f * f);
	//f = 1.0f - (cos(f * 3.1415f) * 0.5f + 0.5f);

	//i -= vec2(0.5f);

	vec2 icoordCenter 		= i / res;
	vec2 icoordRight 		= (i + vec2(1.0f, 0.0f)) / res;
	vec2 icoordUp	 		= (i + vec2(0.0f, 1.0f)) / res;
	vec2 icoordUpRight	 	= (i + vec2(1.0f, 1.0f)) / res;


	vec4 texCenter 	= texture2DLod(tex, icoordCenter, 	level);
	vec4 texRight 	= texture2DLod(tex, icoordRight, 	level);
	vec4 texUp 		= texture2DLod(tex, icoordUp, 		level);
	vec4 texUpRight	= texture2DLod(tex, icoordUpRight,  level);

	texCenter = mix(texCenter, texUp, vec4(f.y));
	texRight  = mix(texRight, texUpRight, vec4(f.y));

	vec4 result = mix(texCenter, texRight, vec4(f.x));
	return result;
}

float Impulse(in float x, in float k) {
	float h = k*x;
    return pow(h*exp(1.0f-h), 5.0f);
}

float RepeatingImpulse(in float x, in float scale) {
	float time = x;
		  time = mod(time, scale);

	return Impulse(time, 3.0f / scale);
}

void main() {
	texcoord = gl_MultiTexCoord0;

	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	
	vec4 viewpos = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	vec4 position = viewpos;

	worldPosition = viewpos.xyz + cameraPosition.xyz;
	
	//Gather materials
	materialIDs = 1.0f;

	//Grass
	if  (  mc_Entity.x == 31.0

		|| mc_Entity.x == 38.0f 	//Rose
		|| mc_Entity.x == 37.0f 	//Flower
		|| mc_Entity.x == 1925.0f 	//Biomes O Plenty: Medium Grass
		|| mc_Entity.x == 1920.0f 	//Biomes O Plenty: Thorns, barley
		|| mc_Entity.x == 1921.0f 	//Biomes O Plenty: Sunflower

		)
	{
		materialIDs = max(materialIDs, 2.0f);
	}
	
	//Wheat
	if (mc_Entity.x == 59.0
		|| mc_Entity.x == 141.0f
		|| mc_Entity.x == 142.0f
		|| mc_Entity.x == 115.0f
		
		) {
		materialIDs = max(materialIDs, 2.0f);
	}	
	
	//Leaves
	if   ( mc_Entity.x == 18.0 

		|| mc_Entity.x == 1962.0f //Biomes O Plenty: Leaves
		|| mc_Entity.x == 1924.0f //Biomes O Plenty: Leaves
		|| mc_Entity.x == 1923.0f //Biomes O Plenty: Leaves
		|| mc_Entity.x == 1926.0f //Biomes O Plenty: Leaves
		|| mc_Entity.x == 1936.0f //Biomes O Plenty: Giant Flower Leaves

		 ) {
		materialIDs = max(materialIDs, 3.0f);
	}	

	
	//Gold block
	if (mc_Entity.x == 41) {
		materialIDs = max(materialIDs, 20.0f);
	}
	
	//Iron block
	if (mc_Entity.x == 42) {
		materialIDs = max(materialIDs, 21.0f);
	}
	
	//Diamond Block
	if (mc_Entity.x == 57) {
		materialIDs = max(materialIDs, 22.0f);
	}
	
	//Emerald Block
	if (mc_Entity.x == -123) {
		materialIDs = max(materialIDs, 23.0f);
	}
	
	//sand
	if (mc_Entity.x == 12) {
		materialIDs = max(materialIDs, 24.0f);
	}

	//sandstone
	if (mc_Entity.x == 24 || mc_Entity.x == -128) {
		materialIDs = max(materialIDs, 25.0f);
	}
	
	//stone
	if (mc_Entity.x == 1) {
		materialIDs = max(materialIDs, 26.0f);
	}
	
	//cobblestone
	if (mc_Entity.x == 4) {
		materialIDs = max(materialIDs, 27.0f);
	}
	
	//wool
	if (mc_Entity.x == 35) {
		materialIDs = max(materialIDs, 28.0f);
	}


	//torch	
	if (mc_Entity.x == 50) {
		materialIDs = max(materialIDs, 30.0f);
	}

	//lava
	if (mc_Entity.x == 10 || mc_Entity.x == 11) {
		materialIDs = max(materialIDs, 31.0f);
	}

	//glowstone and lamp
	if (mc_Entity.x == 89 || mc_Entity.x == 124) {
		materialIDs = max(materialIDs, 32.0f);
	}

	//fire
	if (mc_Entity.x == 51) {
		materialIDs = max(materialIDs, 33.0f);
	}

	float tick = frameTimeCounter;
	
	
	float grassWeight = mod(texcoord.t * 16.0f, 1.0f / 16.0f);
	float vineweight = mod(texcoord.t * 1.0f, 1.0f / 0.20f);

	float lightWeight = clamp((lmcoord.t * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);
	  lightWeight *= 1.1f;
	  lightWeight -= 0.1f;
	  lightWeight = max(0.0f, lightWeight);
	  lightWeight = pow(lightWeight, 5.0f);


	if (grassWeight < 0.01f) {
	  	grassWeight = 1.0f;
	} else {
	  	grassWeight = 0.0f;
	}

	const float pi = 3.14159265f;

	position.xyz += cameraPosition.xyz;
		
#ifdef WAVING_GRASS	
	//Waving grass
	if (materialIDs == 2.0f) {
		vec2 angleLight = vec2(0.0f);
		vec2 angleHeavy = vec2(0.0f);
		vec2 angle 		= vec2(0.0f);

		vec3 pn0 = position.xyz;
			 pn0.x -= frameTimeCounter / 3.0f;

		vec3 stoch = BicubicTexture(noisetex, pn0.xz / 64.0f).xyz;
		vec3 stochLarge = BicubicTexture(noisetex, position.xz / (64.0f * 6.0f)).xyz;

		vec3 pn = position.xyz;
			 pn.x *= 2.0f;
			 pn.x -= frameTimeCounter * 15.0f;
			 pn.z *= 8.0f;

		vec3 stochLargeMoving = BicubicTexture(noisetex, pn.xz / (64.0f * 10.0f)).xyz;

		vec3 p = position.xyz;
		 	 p.x += sin(p.z / 2.0f) * 1.0f;
		 	 p.xz += stochLarge.rg * 5.0f;

		float windStrength = mix(0.85f, 1.0f, rainStrength);
		float windStrengthRandom = stochLargeMoving.x;
			  windStrengthRandom = pow(windStrengthRandom, mix(2.0f, 1.0f, rainStrength));
			  windStrength *= mix(windStrengthRandom, 0.5f, rainStrength * 0.25f);

		//heavy wind
		float heavyAxialFrequency 			= 8.0f;
		float heavyAxialWaveLocalization 	= 0.9f;
		float heavyAxialRandomization 		= 13.0f;
		float heavyAxialAmplitude 			= 15.0f;
		float heavyAxialOffset 				= 15.0f;

		float heavyLateralFrequency 		= 6.732f;
		float heavyLateralWaveLocalization 	= 1.274f;
		float heavyLateralRandomization 	= 1.0f;
		float heavyLateralAmplitude 		= 6.0f;
		float heavyLateralOffset 			= 0.0f;

		//light wind
		float lightAxialFrequency 			= 5.5f;
		float lightAxialWaveLocalization 	= 1.1f;
		float lightAxialRandomization 		= 21.0f;
		float lightAxialAmplitude 			= 5.0f;
		float lightAxialOffset 				= 5.0f;

		float lightLateralFrequency 		= 5.9732f;
		float lightLateralWaveLocalization 	= 1.174f;
		float lightLateralRandomization 	= 0.0f;
		float lightLateralAmplitude 		= 1.0f;
		float lightLateralOffset 			= 0.0f;

		float windStrengthCrossfade = clamp(windStrength * 2.0f - 1.0f, 0.0f, 1.0f);
		float lightWindFade = clamp(windStrength * 2.0f, 0.2f, 1.0f);

		angleLight.x += sin(frameTimeCounter * lightAxialFrequency 		- p.x * lightAxialWaveLocalization		+ stoch.x * lightAxialRandomization) 	* lightAxialAmplitude 		+ lightAxialOffset;	
		angleLight.y += sin(frameTimeCounter * lightLateralFrequency 	- p.x * lightLateralWaveLocalization 	+ stoch.x * lightLateralRandomization) 	* lightLateralAmplitude  	+ lightLateralOffset;

		angleHeavy.x += sin(frameTimeCounter * heavyAxialFrequency 		- p.x * heavyAxialWaveLocalization		+ stoch.x * heavyAxialRandomization) 	* heavyAxialAmplitude 		+ heavyAxialOffset;	
		angleHeavy.y += sin(frameTimeCounter * heavyLateralFrequency 	- p.x * heavyLateralWaveLocalization 	+ stoch.x * heavyLateralRandomization) 	* heavyLateralAmplitude  	+ heavyLateralOffset;

		angle = mix(angleLight * lightWindFade, angleHeavy, vec2(windStrengthCrossfade));
		angle *= 2.0f;

		// //Rotate block pivoting from bottom based on angle
		position.x += (sin((angle.x / 180.0f) * 3.141579f)) * grassWeight * lightWeight						* 1.0f	;
		position.z += (sin((angle.y / 180.0f) * 3.141579f)) * grassWeight * lightWeight						* 1.0f	;
		position.y += (cos(((angle.x + angle.y) / 180.0f) * 3.141579f) - 1.0f)  * grassWeight * lightWeight	* 1.0f	;
	}
	
#endif	

#ifdef WAVING_WHEAT
	//Wheat//
	if (mc_Entity.x == 296 && texcoord.t < 0.35) {
		float speed = 0.03;
		
		float magnitude = sin((tick * pi / (28.0)) + position.x + position.z) * 0.12 + 0.02;
			  magnitude *= grassWeight * 0.2f;
			  magnitude *= lightWeight;
		float d0 = sin(tick * pi / (122.0 * speed)) * 3.0 - 1.5 + position.z;
		float d1 = sin(tick * pi / (152.0 * speed)) * 3.0 - 1.5 + position.x;
		float d2 = sin(tick * pi / (122.0 * speed)) * 3.0 - 1.5 + position.x;
		float d3 = sin(tick * pi / (152.0 * speed)) * 3.0 - 1.5 + position.z;
		position.x += sin((tick * pi / (28.0 * speed)) + (position.x + d0) * 0.1 + (position.z + d1) * 0.1) * magnitude;
		position.z += sin((tick * pi / (28.0 * speed)) + (position.z + d2) * 0.1 + (position.x + d3) * 0.1) * magnitude;
	}
	
	//small leaf movement
	if (mc_Entity.x == 59.0 && texcoord.t < 0.35) {
		float speed = 0.04;
		
		float magnitude = (sin(((position.y + position.x)/2.0 + tick * pi / ((28.0)))) * 0.025 + 0.075) * 0.2;
			  magnitude *= grassWeight;
			  magnitude *= lightWeight;
		float d0 = sin(tick * pi / (112.0 * speed)) * 3.0 - 1.5;
		float d1 = sin(tick * pi / (142.0 * speed)) * 3.0 - 1.5;
		float d2 = sin(tick * pi / (112.0 * speed)) * 3.0 - 1.5;
		float d3 = sin(tick * pi / (142.0 * speed)) * 3.0 - 1.5;
		position.x += sin((tick * pi / (18.0 * speed)) + (-position.x + d0)*1.6 + (position.z + d1)*1.6) * magnitude * (1.0f + rainStrength * 2.0f);
		position.z += sin((tick * pi / (18.0 * speed)) + (position.z + d2)*1.6 + (-position.x + d3)*1.6) * magnitude * (1.0f + rainStrength * 2.0f);
		position.y += sin((tick * pi / (11.0 * speed)) + (position.z + d2) + (position.x + d3)) * (magnitude/3.0) * (1.0f + rainStrength * 2.0f);
	}
#endif
	

#ifdef WAVING_LEAVES
	//Leaves//
	if (materialIDs == 3.0f && texcoord.t < 1.90 && texcoord.t > -1.0) {
		float speed = 0.05;
		
		float magnitude = (sin((position.y + position.x + tick * pi / ((28.0) * speed))) * 0.15 + 0.15) * 0.30 * lightWeight;
			  magnitude *= lightWeight;

		float d0 = sin(tick * pi / (112.0 * speed)) * 3.0 - 1.5;
		float d1 = sin(tick * pi / (142.0 * speed)) * 3.0 - 1.5;
		float d2 = sin(tick * pi / (132.0 * speed)) * 3.0 - 1.5;
		float d3 = sin(tick * pi / (122.0 * speed)) * 3.0 - 1.5;

		position.x += sin((tick * pi / (18.0 * speed)) + (-position.x + d0)*1.6 + (position.z + d1)*1.6) * magnitude * (1.0f + rainStrength * 1.0f);
		position.z += sin((tick * pi / (17.0 * speed)) + (position.z + d2)*1.6 + (-position.x + d3)*1.6) * magnitude * (1.0f + rainStrength * 1.0f);
		position.y += sin((tick * pi / (11.0 * speed)) + (position.z + d2) + (position.x + d3)) * (magnitude/2.0) * (1.0f + rainStrength * 1.0f);
	}
	
	//lower leaf movement
	if (materialIDs == 3.0f) {
		float speed = 0.075;
		float magnitude = (sin((tick * pi / ((28.0) * speed))) * 0.05 + 0.15) * 0.075 * lightWeight;
			  magnitude *= lightWeight;

		float d0 = sin(tick * pi / (122.0 * speed)) * 3.0 - 1.5;
		float d1 = sin(tick * pi / (142.0 * speed)) * 3.0 - 1.5;
		float d2 = sin(tick * pi / (162.0 * speed)) * 3.0 - 1.5;
		float d3 = sin(tick * pi / (112.0 * speed)) * 3.0 - 1.5;

		position.x += sin((tick * pi / (13.0 * speed)) + (position.x + d0)*0.9 + (position.z + d1)*0.9) * magnitude;
		position.z += sin((tick * pi / (16.0 * speed)) + (position.z + d2)*0.9 + (position.x + d3)*0.9) * magnitude;
		position.y += sin((tick * pi / (15.0 * speed)) + (position.z + d2) + (position.x + d3)) * (magnitude/1.0);
	}

#endif	

#ifdef WAVING_VINES
    //large scale movement
    if ( mc_Entity.x == ENTITY_VINES ) {
        float speed = 3.0;
        float magnitude = (sin(((position.y + position.x)/2.0 + worldTime * 3.14159265358979323846264 / ((88.0)))) * 0.05 + 0.15) * 0.26;
			  magnitude *= vineweight;
			  magnitude *= lightWeight;

		float d0 = sin(worldTime * 3.14159265358979323846264 / (122.0 * speed)) * 3.0 - 1.5;
        float d1 = sin(worldTime * 3.14159265358979323846264 / (152.0 * speed)) * 3.0 - 1.5;
        float d2 = sin(worldTime * 3.14159265358979323846264 / (192.0 * speed)) * 3.0 - 1.5;
        float d3 = sin(worldTime * 3.14159265358979323846264 / (142.0 * speed)) * 3.0 - 1.5;

        position.x += sin((worldTime * 3.14159265358979323846264 / (16.0 * speed)) + (position.x + d0)*0.5 + (position.z + d1)*0.5 + (position.y)) * magnitude;
        position.z += sin((worldTime * 3.14159265358979323846264 / (18.0 * speed)) + (position.z + d2)*0.5 + (position.x + d3)*0.5 + (position.y)) * magnitude;
    }
   
    //small scale movement
    if (mc_Entity.x == 106.0 && texcoord.t < 0.20) {
        float speed = 1.1;
        float magnitude = (sin(((position.y + position.x)/8.0 + worldTime * 3.14159265358979323846264 / ((88.0)))) * 0.15 + 0.05) * 0.22;

        float d0 = sin(worldTime * 3.14159265358979323846264 / (112.0 * speed)) * 3.0 + 0.5;
        float d1 = sin(worldTime * 3.14159265358979323846264 / (142.0 * speed)) * 3.0 + 0.5;
        float d2 = sin(worldTime * 3.14159265358979323846264 / (112.0 * speed)) * 3.0 + 0.5;
        float d3 = sin(worldTime * 3.14159265358979323846264 / (142.0 * speed)) * 3.0 + 0.5;

        position.x += sin((worldTime * 3.14159265358979323846264 / (18.0 * speed)) + (-position.x + d0)*1.6 + (position.z + d1)*1.6) * magnitude;
        position.z += sin((worldTime * 3.14159265358979323846264 / (18.0 * speed)) + (position.z + d2)*1.6 + (-position.x + d3)*1.6) * magnitude;
        position.y += sin((worldTime * 3.14159265358979323846264 / (11.0 * speed)) + (position.z + d2) + (position.x + d3)) * (magnitude/4.0);
    }
    #endif
	
	#ifdef WAVING_LILIES
    //flowing water
    if (mc_Entity.x == 111.0 && texcoord.t > 0.05) {
        float speed = 2.7;
        float magnitude = (sin((worldTime * 3.14159265358979323846264 / ((28.0) * speed))) * 0.05 + 0.15) * 0.17;

        float d0 = sin(worldTime * 3.14159265358979323846264 / (132.0 * speed)) * 3.0 - 1.5;
        float d1 = sin(worldTime * 3.14159265358979323846264 / (132.0 * speed)) * 3.0 - 1.5;
        float d2 = sin(worldTime * 3.14159265358979323846264 / (132.0 * speed)) * 3.0 - 1.5;
        float d3 = sin(worldTime * 3.14159265358979323846264 / (132.0 * speed)) * 3.0 - 1.5;

        position.x += sin((worldTime * 3.14159265358979323846264 / (13.0 * speed)) + (position.x + d0)*0.9 + (position.z + d1)*0.9) * magnitude;
        position.y += sin((worldTime * 3.14159265358979323846264 / (15.0 * speed)) + (position.z + d2) + (position.x + d3)) * magnitude;
        position.y -= 0.04;
    }
    //still water
    if (mc_Entity.x == 111.0 && texcoord.t > 0.05) {
        float speed = 2.7;
        float magnitude = (sin((worldTime * 3.14159265358979323846264 / ((28.0) * speed))) * 0.05 + 0.15) * 0.17;

        float d0 = sin(worldTime * 3.14159265358979323846264 / (132.0 * speed)) * 3.0 - 1.5;
        float d1 = sin(worldTime * 3.14159265358979323846264 / (132.0 * speed)) * 3.0 - 1.5;
        float d2 = sin(worldTime * 3.14159265358979323846264 / (132.0 * speed)) * 3.0 - 1.5;
        float d3 = sin(worldTime * 3.14159265358979323846264 / (132.0 * speed)) * 3.0 - 1.5;

        position.x += sin((worldTime * 3.14159265358979323846264 / (13.0 * speed)) + (position.x + d0)*0.9 + (position.z + d1)*0.9) * magnitude;
        position.y += sin((worldTime * 3.14159265358979323846264 / (15.0 * speed)) + (position.z + d2) + (position.x + d3)) * magnitude;
        position.y -= 0.04;
    }
    #endif

	vec4 locposition = gl_ModelViewMatrix * gl_Vertex;
	
	distance = sqrt(locposition.x * locposition.x + locposition.y * locposition.y + locposition.z * locposition.z);

	position.xyz -= cameraPosition.xyz;

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	
	color = gl_Color;
	
	gl_FogFragCoord = gl_Position.z;
	
	normal = normalize(gl_NormalMatrix * gl_Normal);
	worldNormal = gl_Normal;

	float texFix = -1.0f;

	#ifdef TEXTURE_FIX
	texFix = 1.0f;
	#endif

	if (gl_Normal.x > 0.5) {
		//  1.0,  0.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  texFix));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
		if (abs(materialIDs - 32.0f) < 0.1f)								//Optifine glowstone fix
			color *= 1.75f;
	} else if (gl_Normal.x < -0.5) {
		// -1.0,  0.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
		if (abs(materialIDs - 32.0f) < 0.1f)								//Optifine glowstone fix
			color *= 1.75f;
	} else if (gl_Normal.y > 0.5) {
		//  0.0,  1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	} else if (gl_Normal.y < -0.5) {
		//  0.0, -1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	} else if (gl_Normal.z > 0.5) {
		//  0.0,  0.0,  1.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.z < -0.5) {
		//  0.0,  0.0, -1.0
		tangent  = normalize(gl_NormalMatrix * vec3( texFix,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	}

	tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
                     tangent.y, binormal.y, normal.y,
                     tangent.z, binormal.z, normal.z);

	vertexPos = gl_Vertex;

	// Determine roughness from material id
	float smoothness_in = 0.001f;

	//smooth stone, brick
	if(		   mc_Entity.x ==   1.0 //stone
			|| mc_Entity.x ==  13.0 //gravel
			|| mc_Entity.x ==  23.0 //dispenser
			|| mc_Entity.x ==  29.0 //sticky piston
    	    || mc_Entity.x ==  33.0 //piston
		    || mc_Entity.x ==  43.0 //double stone slab
		    || mc_Entity.x ==  45.0 //brick block
		    || mc_Entity.x ==  61.0 //furnace
		    || mc_Entity.x ==  62.0 //lit furnace
		    || mc_Entity.x ==  44.0 //stone slab
			|| mc_Entity.x ==  70.0 //stone pressure plate
			|| mc_Entity.x ==  77.0 //stone button
			|| mc_Entity.x ==  93.0 //redstone repeater
			|| mc_Entity.x ==  94.0 //lit restone repeater
			|| mc_Entity.x ==  97.0 //monster egg
			|| mc_Entity.x ==  98.0 //stone brick
			|| mc_Entity.x == 180.0 //brick stairs
			|| mc_Entity.x == 109.0 //stone brick stairs
			|| mc_Entity.x == 149.0 //redstone comparator
			|| mc_Entity.x == 150.0 //lit comparator
			|| mc_Entity.x == 158.0 //dropper
    ) {
         smoothness_in = 0.8f;

    //dirt
    } else if( mc_Entity.x ==   2.0 //grassy dirt
            || mc_Entity.x ==   3.0 //grassless dirt
            || mc_Entity.x ==  60.0 //farmland
            || mc_Entity.x ==  88.0 //soul sand
            || mc_Entity.x ==  46.0 //tnt
            || mc_Entity.x ==  83.0 //clay
            || mc_Entity.x == 110.0 //mycelium
            || mc_Entity.x == 140.0 //flower pot
            || mc_Entity.x == 159.0 //stianed hardened clay
            || mc_Entity.x == 172.0 //hardened clay
        ) {
        smoothness_in = 0.1;

    //cobblestone
	} else if( mc_Entity.x ==   4.0 //cobblestone
			|| mc_Entity.x ==  48.0 //mossy cobblestone
            || mc_Entity.x ==  67.0 //stone stairs
            || mc_Entity.x ==  69.0 //lever
        	|| mc_Entity.x == 117.0 //brewing stand
        	|| mc_Entity.x == 139.0 //cobblestone wall
        ) {
		smoothness_in = 0.5;

    //wood
    } else if( mc_Entity.x ==   5.0 //wooden planks
            || mc_Entity.x ==   6.0 //sapling
            || mc_Entity.x ==  17.0 //log
            || mc_Entity.x ==  19.0 //sponge
            || mc_Entity.x ==  47.0 //bookshelf
            || mc_Entity.x ==  50.0 //torch
            || mc_Entity.x ==  35.0 //oak stairs
            || mc_Entity.x ==  54.0 //chest	
            || mc_Entity.x ==  58.0 //crafting table
            || mc_Entity.x ==  63.0 //sign
            || mc_Entity.x ==  64.0 //oak door
            || mc_Entity.x ==  65.0 //ladder
            || mc_Entity.x ==  68.0 //wall sign (why is this different?)
            || mc_Entity.x ==  72.0 //wood pressure plate
            || mc_Entity.x ==  75.0 //unlit restone torch
            || mc_Entity.x ==  85.0 //fence		             
            || mc_Entity.x ==  96.0 //trapdoor
            || mc_Entity.x == 107.0 //fence gate
            || mc_Entity.x == 125.0 //double wooden slab
            || mc_Entity.x == 126.0 //wooden slab
            || mc_Entity.x == 131.0 //tripwire hook
            || mc_Entity.x == 134.0 //spruce stairs
     		|| mc_Entity.x == 135.0 //birch stairs
    		|| mc_Entity.x == 136.0 //jungle wood stairs
       		|| mc_Entity.x == 143.0 //wooden button
            || mc_Entity.x == 146.0 //trapped chest
            || mc_Entity.x == 162.0 //log2 (ew)
            || mc_Entity.x == 163.0 //acacia stairs
            || mc_Entity.x == 164.0 //dark oak stairs
            || mc_Entity.x == 173.0 //block of coal (from my stocking)
            || mc_Entity.x == 183.0 //spruce fence gate
            || mc_Entity.x == 184.0 //birch fence gate
            || mc_Entity.x == 185.0 //jungle fence gate
            || mc_Entity.x == 186.0 //dark oak fence gate
            || mc_Entity.x == 187.0 //acacia fence gate
            || mc_Entity.x == 188.0 //spruce fence gate
            || mc_Entity.x == 189.0 //birch fence gate
            || mc_Entity.x == 190.0 //jungle_fence
            || mc_Entity.x == 191.0 //dark oak fence
            || mc_Entity.x == 192.0 //acacia fence
            || mc_Entity.x == 193.0 //spruce door
            || mc_Entity.x == 194.0 //birch door
            || mc_Entity.x == 195.0 //jungle door
            || mc_Entity.x == 196.0 //acacia door
            || mc_Entity.x == 197.0 //dark oak door
        ) {
        smoothness_in = 0.05;

    //shiny
    } else if( mc_Entity.x ==   7.0 //bedrock
	        || mc_Entity.x ==   8.0 //flowing water
            || mc_Entity.x ==   9.0 //water
            || mc_Entity.x ==  20.0 //glass
            || mc_Entity.x ==  22.0 //lapiz block
            || mc_Entity.x ==  25.0 //note block
            || mc_Entity.x ==  41.0 //gold block
            || mc_Entity.x ==  49.0 //obsidian
            || mc_Entity.x ==  57.0 //diamond block
            || mc_Entity.x ==  79.0 //ice
            || mc_Entity.x ==  84.0 //jukobox
            || mc_Entity.x ==  95.0 //stained glass
            || mc_Entity.x == 102.0 //glass pane
            || mc_Entity.x == 116.0 //enchanting table
            || mc_Entity.x == 122.0 //dragon egg
            || mc_Entity.x == 130.0 //ender chest
            || mc_Entity.x == 133.0 //emerald block
            || mc_Entity.x == 137.0 //command block
            || mc_Entity.x == 138.0 //beacon
            || mc_Entity.x == 147.0 //light pressure plate
            || mc_Entity.x == 152.0 //redstone block
            || mc_Entity.x == 155.0 //quartx block
            || mc_Entity.x == 156.0 //quartz stairs
            || mc_Entity.x == 160.0 //stained glass pane
            || mc_Entity.x == 165.0 //slime
            || mc_Entity.x == 169.0 //sea lantern
            || mc_Entity.x == 174.0 //packed ice
        ) {
        smoothness_in = 1.0;

    //sand, cloth
    } else if( mc_Entity.x ==  12.0 //sand
            || mc_Entity.x ==  24.0 //sandstone
            || mc_Entity.x ==  26.0 //bed
            || mc_Entity.x ==  35.0 //wool
            || mc_Entity.x ==  78.0 //snow layer
            || mc_Entity.x ==  80.0 //snow block
            || mc_Entity.x == 128.0 //sandstone stairs
            || mc_Entity.x == 179.0 //red sandstone
            || mc_Entity.x == 180.0 //red sandstone stairs
            || mc_Entity.x == 181.0 //double sandstone slab
            || mc_Entity.x == 182.0 //stone slab
        ) {
        smoothness_in = 0.2;

    //ores, iron
    } else if( mc_Entity.x ==  14.0 //gold ore
            || mc_Entity.x ==  15.0 //iron ore
            || mc_Entity.x ==  16.0 //coal ore
            || mc_Entity.x ==  21.0 //lapis ore
            || mc_Entity.x ==  27.0 //golden rail
            || mc_Entity.x ==  28.0 //detector rail
            || mc_Entity.x ==  42.0 //iron block
            || mc_Entity.x ==  52.0 //mob spawner
            || mc_Entity.x ==  56.0 //diamond ore
            || mc_Entity.x ==  66.0 //rail
            || mc_Entity.x ==  71.0 //iron door
            || mc_Entity.x ==  73.0 //redstone ore
            || mc_Entity.x ==  74.0 //lit redstone ore
            || mc_Entity.x == 101.0 //iron bars
            || mc_Entity.x == 118.0 //cauldron
            || mc_Entity.x == 129.0 //emerald ore
            || mc_Entity.x == 145.0 //anvil
            || mc_Entity.x == 148.0 //heavy pressure plate
            || mc_Entity.x == 154.0 //hopper
            || mc_Entity.x == 167.0 //iron trapdoor
        ) {
        smoothness_in = 0.9;
    
    //leaves
    } else if( mc_Entity.x ==  18.0 //leaves
            || mc_Entity.x ==  31.0 //tall grass
            || mc_Entity.x ==  32.0 //dead grass
            || mc_Entity.x ==  37.0 //dandelion
            || mc_Entity.x ==  38.0 //poppy
            || mc_Entity.x ==  39.0 //brown mushroom
            || mc_Entity.x ==  40.0 //red muchroom
            || mc_Entity.x ==  59.0 //wheat
            || mc_Entity.x ==  81.0 //cactus
            || mc_Entity.x ==  83.0 //sugar cane		
            || mc_Entity.x ==  86.0 //pumpkin
            || mc_Entity.x ==  91.0 //lit pumpkin
            || mc_Entity.x ==  92.0 //cakes are leaves, right?
            || mc_Entity.x ==  99.0 //brown mushroom block
            || mc_Entity.x == 100.0 //reg mushroom block
            || mc_Entity.x == 103.0 //melon
            || mc_Entity.x == 104.0 //pumpkin stem
            || mc_Entity.x == 105.0 //melon stem
            || mc_Entity.x == 106.0 //vine
            || mc_Entity.x == 111.0 //lily pad
            || mc_Entity.x == 115.0 //nether wort
        ) {
         smoothness_in = 0.4;
    }
     
    //process the semi-metals (they are part metal and part not). They're not very common
    if(        mc_Entity.x ==  14.0 //gold ore
            || mc_Entity.x ==  15.0 //iron ore
        	|| mc_Entity.x ==  27.0 //gold rails
        	|| mc_Entity.x ==  28.0 //detector rails
    		|| mc_Entity.x ==  66.0 //rails
            || mc_Entity.x == 157.0 //activator rails
         ) {
        metalness_in = 0.5;
    } else if( mc_Entity.x ==  41.0 //gold block 
	       	|| mc_Entity.x ==  71.0 //iron door
            || mc_Entity.x == 101.0 //iron bars
            || mc_Entity.x == 118.0 //cauldron
            || mc_Entity.x == 145.0 //anvil
            || mc_Entity.x == 148.0 //heavy pressure plate	
            ) {		
        metalness_in = 1.0f;
    }
}