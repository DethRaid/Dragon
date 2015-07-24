#version 120

/////////ADJUSTABLE VARIABLES//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////ADJUSTABLE VARIABLES//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define SHADOW_MAP_BIAS 0.80

//#define ENABLE_SOFT_SHADOWS

#define GI_QUALITY 1.0f				// sets the quality for GI and shadows 2.0f is default, Higher means lower fps

/////////INTERNAL VARIABLES////////////////////////////////////////////////////
/////////INTERNAL VARIABLES////////////////////////////////////////////////////
//Do not change the name of these variables or their type. The Shaders Mod reads these lines and determines values to send to the inner-workings
//of the shaders mod. The shaders mod only reads these lines and doesn't actually know the real value assigned to these variables in GLSL.
//Some of these variables are critical for proper operation. Change at your own risk.

const int 		shadowMapResolution 	= 4096;
const float 	shadowDistance 			= 180.0f;
const float 	shadowIntervalSize 		= 4.0f;

const bool 		shadowtex1Mipmap = true;
const bool 		shadowtex1Nearest = true;
const bool 		shadowcolor0Mipmap = true;
const bool 		shadowcolor0Nearest = false;
const bool 		shadowcolor1Mipmap = true;
const bool 		shadowcolor1Nearest = false;

const int 		R8 						= 0;
const int 		RG8 					= 0;
const int 		RGB8 					= 1;
const int 		RGB16 					= 2;
const int 		gcolorFormat 			= RGB16;
const int 		gdepthFormat 			= RGB8;
const int 		gnormalFormat 			= RGB16;
const int 		compositeFormat 		= RGB8;

const float 	eyeBrightnessHalflife 	= 10.0f;
const float 	centerDepthHalflife 	= 2.0f;
const float 	wetnessHalflife 		= 100.0f;
const float 	drynessHalflife 		= 40.0f;

const int 		superSamplingLevel 		= 0;

const float		sunPathRotation 		= -40.0f;
const float 	ambientOcclusionLevel 	= 0.5f;

const int 		noiseTextureResolution  = 64;

//END OF INTERNAL VARIABLES//

/* DRAWBUFFERS:45 */

uniform sampler2D gnormal;
uniform sampler2D gdepthtex;
uniform sampler2D gdepth;
uniform sampler2D shadowcolor1;
uniform sampler2D shadowcolor;
uniform sampler2D shadowtex1;
uniform sampler2D noisetex;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;

varying vec4 texcoord;
varying vec3 lightVector;

varying float timeSunriseSunset;
varying float timeNoon;
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
uniform vec3 cameraPosition;

/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////FUNCTIONS/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


vec3  	GetNormals(in vec2 coord) {				//Function that retrieves the screen space surface normals. Used for lighting calculations
	return texture2DLod(gnormal, coord.st, 0).rgb * 2.0f - 1.0f;
}

float 	GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord.st).x;
}

vec4  	GetScreenSpacePosition(in vec2 coord) {	//Function that calculates the screen-space position of the objects in the scene using the depth texture and the texture coordinates of the full-screen quad
	float depth = GetDepth(coord);
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;

	return fragposition;
}

vec3 	CalculateNoisePattern1(vec2 offset, float size) {
	vec2 coord = texcoord.st;

	coord *= vec2(viewWidth, viewHeight);
	coord = mod(coord + offset, vec2(size));
	coord /= noiseTextureResolution;

	return texture2D(noisetex, coord).xyz;
}

vec2 DistortShadowSpace(in vec2 pos)
{
	vec2 signedPos = pos * 2.0f - 1.0f;

	float dist = sqrt(signedPos.x * signedPos.x + signedPos.y * signedPos.y);
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
	signedPos.xy /= distortFactor;

	pos = signedPos * 0.5f + 0.5f;

	return pos;
}

vec3 Contrast(in vec3 color, in float contrast)
{
	float colorLength = length(color);
	vec3 nColor = color / colorLength;

	colorLength = pow(colorLength, contrast);

	return nColor * colorLength;
}

float 	GetMaterialIDs(in vec2 coord) {			//Function that retrieves the texture that has all material IDs stored in it 																
	return texture2D(gdepth, coord).r;
}

bool 	GetSkyMask(in vec2 coord)
{
	float matID = GetMaterialIDs(coord);
	matID = floor(matID * 255.0f);

	if (matID < 1.0f || matID > 254.0f)
	{
		return true;
	} else {
		return false;
	}
}

float GetAO(in vec4 screenSpacePosition, in vec3 normal, in vec2 coord, in vec3 dither)
{
	//Determine origin position
	vec3 origin = screenSpacePosition.xyz;

	vec3 randomRotation = normalize(dither.xyz * vec3(2.0f, 2.0f, 1.0f) - vec3(1.0f, 1.0f, 0.0f));

	vec3 tangent = normalize(randomRotation - normal * dot(randomRotation, normal));
	vec3 bitangent = cross(normal, tangent);
	mat3 tbn = mat3(tangent, bitangent, normal);

	float aoRadius   = 0.25f * -screenSpacePosition.z;
		  
	float zThickness = 0.25f * -screenSpacePosition.z;
		  

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
	ao = pow(ao, 1.0f);

	return ao;
}

vec4 calculateGI( in int f, in vec2 d, in float v, in float /*z*/ quality, vec3  s ) { 
    float x = pow( 2.f, float( f ) ), y = .002f;
    if( texcoord.x - d.x + y < 1.f / x + y * 2.f 
            && texcoord.y - d.y + y < 1.f / x + y * 2.f
            && texcoord.x - d.x + y > 0.f 
            && texcoord.y - d.y + y > 0.f ) {
        vec2 i = (texcoord.xy - d.xy) * x; 
        vec3 /*t*/ normal = GetNormals( i.xy );

        // Perform normalmapping
        vec4 normal_CameraSpace = gbufferModelViewInverse * vec4( normal.xyz, 0.f ) ;
        normal_CameraSpace = shadowModelView * normal_CameraSpace;
        normal_CameraSpace.xyz = normalize( normal_CameraSpace.xyz ); 
        vec3 /*a*/ normal_ShadowSpace = normal_CameraSpace.xyz; 

        vec4 /*S*/pos_ScreenSpace = GetScreenSpacePosition( i.xy ); // renamed from S
        vec3 r = normalize( S.xyz ); 
        float /*e*/  = sqrt( pos_ScreenSpace.x * pos_ScreenSpace.x + pos_ScreenSpace.y * pos_ScreenSpace.y + pos_ScreenSpace.z * pos_ScreenSpace.z );
        float p = texture2D( gdepth, i ).x * 255.f;
        vec4 o = shadowModelView * vec4( 0.f, 1., 0., 0. );

        vec4 /*n*/ pos_ShadowSpace = gbufferModelViewInverse * pos_ScreenSpace;   // renamed from n
        pos_ShadowSpace = shadowModelView * pos_ShadowSpace; 
        float shadowDistance = -pos_ShadowSpace.z;  // renamed from c
        pos_ShadowSpace = shadowProjection * pos_ShadowSpace;
        pos_ShadowSpace /= pos_ShadowSpace.w; 
        
        // SE's un-distorting shadow map thing. I think he wanted to get higher resolution closer to the camera
        float /*w*/ distance = sqrt( pos_ShadowSpace.x * pos_ShadowSpace.x + pos_ShadowSpace.y * pos_ShadowSpace.y );
        float /*l*/ distortionFactor = 1.f - SHADOW_MAP_BIAS + distance * SHADOW_MAP_BIAS;
        
        vec4 shadowCoord = pos_ShadowSpace * .5f + .5f;  // transform from [-1, 1] to [0, 1] 
        
        float b = 0.f, h = 0.f; 
        vec3 g = vec3( 0.f );
        float D = 0.; 
        
        if( e < shadowDistance 
                && shadowDistance > 0.f
                && shadowCoord.x < 1.f
                && shadowCoord.x > 0.f
                && shadowCoord.y < 1.f 
                && shadowCord.y > 0.f ) { 
            float M=.15f;
            b = clamp( shadowDistance * .85f * M - e * M, 0.f, 1.f ); 
            float u = v; 
            int G = 0; 
            float A = 2.f * u / 2048;
            vec2 V = s.xy - .5f; 
            float /*P*/ blurStep = 1.f / quality;

            // These for loops look like the start of a 5x5 blur
            // It's 5x5 texels, but not 5x5 samples. The number of samples varies with the quality level
            for( float I = -2.f; I <= 2.f; I += blurStep ) {
                for( float O = -2.f; O <= 2.f; O += blurStep ) {
                    vec2 /*L*/ offset = (vec2( I, O ) + V * blurStep) * A;
                    vec2 /*W*/ shadowCoordUndistorted = shadowCoord.xy + offset;
                    vec2 /*H*/ shadowCoordDistorted = DistortShadowSpace( shadowCoordUndistorted ); 
 
                    // Setting up a shadow map sample, for some reason
                    float /*B*/ shadowDepth = texture2DLOD( shadowtex1, shadowCoordDistorted, 2 ).x; 
                    vec3 /*q*/ shadowCoordRaw = vec3( shadowCoordUndistorted.x, shadowCoordUndistorted.y, shadowDepth );
                    vec3 /*k*/ distortionVector = normalize( shadowCoordRaw.xyz - pos_ShadowSpace.xyz );

                    vec3 /*N*/ texNormal = texture2DLOD( shadowcolor1, shadowCoordDistorted, 5 ).xyz * 2.f - 1.f;
                    texNormal.x = -texNormal.x; 
                    texNormal.y = -texNormal.y; 
                    float j = max( 0.f, dot( a.xyz, k * vec3( 1., 1., -1. ) ) ); 
                    if( abs( p - 3.f ) < .1f 
                            || abs( p - 2.f ) < .1f 
                            || abs( p - 11.f ) < .1f ) {
                        j = 1.f; 
                    }
                    if( j > 0. ) {

                        float /*Y*/ normalDistortionAmount = dot( distortionVector, texNormal );
                        float X = normalDistortionAmount;
                        // If the normal's too small, set its distortion amount to also something small (I guess)
                        if( length( texNormal ) < 0.5f ) {
                            texNormal.xyz = vec3( 0.f, 0.f, 1.f );
                            normalDistortionAmount = abs( normalDistortionAmount ) * 0.25f;
                        } 
                        normalDistortionAmount = max( normalDistortionAmount, 0.f ); 
                        float U = length( q.xyz - shadowCoord.xyz - vec3( 0.f, 0.f, 0.f ) ); 
                        if( U < .005f ) {
                            U = 1e+07f; // U = infinity?
                        }
                        const float T = 2.f; 
                        float R = 1.f / (pow( U * (13600.f / u), T ) + .0001f * P);
                        R = max( 0.f, R - 9e-05f ); 
                        if( X < 0.f ) {
                            R = max( R * 30.f - .13f, 0.f ), R *=.04f;
                        }
                        // This line looks like moving from gamma space to a linear space
                        vec3 /*Q*/ shadowColorLinear = pow( texture2DLOD( shadowcolor, shadowCoordDistorted, 5 ).xyz, vec3( 2.2f ) ) ;
                        g += shadowColorLinear * normalDistortionAmount * R * j;
                    }
                    G += 1;
                }
            }
            g /= G;
        } 
        g = mix( vec3( 0.f ), g, vec3( b ) ); 
        float R = 1.f;
        if( !GetSkyMask( i.xy ) ) {
            R *= GetAO( pos_ScreenSpace, t.xyz, i.xy, s.xyz );
        }
        return vec4( g.xyz * 1150.f, R );
    } else {
        return vec4 ( 0.f );
    }
}

vec4 	GetCloudSpacePosition(in vec2 coord, in float depth, in float distanceMult)
{
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

void 	DoNightEye(inout vec3 color) {			//Desaturates any color input at night, simulating the rods in the human eye
	
	float amount = 0.8f; 						//How much will the new desaturated and tinted image be mixed with the original image
	vec3 rodColor = vec3(0.2f, 0.4f, 1.0f); 	//Cyan color that humans percieve when viewing extremely low light levels via rod cells in the eye
	float colorDesat = dot(color, vec3(1.0f)); 	//Desaturated color
	
	color = mix(color, vec3(colorDesat) * rodColor, timeMidnight * amount);
		
}


float   CalculateSunglow(vec4 screenSpacePosition, vec3 lightVector) {

	float curve = 4.0f;

	vec3 npos = normalize(screenSpacePosition.xyz);
	vec3 halfVector2 = normalize(-lightVector + npos);
	float factor = 1.0f - dot(halfVector2, npos);

	return factor * factor * factor * factor;
}

float Get3DNoise(in vec3 pos)
{
	pos.z += 0.0f;

	pos.xyz += 0.5f;

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

float GetCoverage(in float coverage, in float density, in float clouds)
{
	clouds = clamp(clouds - (1.0f - coverage), 0.0f, 1.0f -density) / (1.0f - density);
		clouds = max(0.0f, clouds * 1.1f - 0.1f);
	 clouds = clouds = clouds * clouds * (3.0f - 2.0f * clouds);
	 
	return clouds;
}

vec4 CloudColor(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector)
{

	float cloudHeight = 220.0f;
	float cloudDepth  = 190.0f;
	float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
	float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

	if (worldPosition.y < cloudLowerHeight || worldPosition.y > cloudUpperHeight)
		return vec4(0.0f);
	else
	{

		vec3 p = worldPosition.xyz / 150.0f;

		float t = frameTimeCounter * 5.0f;
			 
		p.x -= t * 0.02f;

		vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
		float noise  = 	Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));	p *= 2.0f;	p.x -= t * 0.097f;	vec3 p2 = p;
			  noise += (1.0 - abs(Get3DNoise(p) * 1.0f - 0.5f) - 0.1) * 0.55f;					p *= 2.5f;	p.xz -= t * 0.065f;	vec3 p3 = p;
			  noise += (1.0 - abs(Get3DNoise(p) * 3.0f - 1.5f) - 0.2) * 0.065f;					p *= 2.5f;	p.xz -= t * 0.165f;	vec3 p4 = p;
			  noise += (1.0 - abs(Get3DNoise(p) * 3.0f - 1.5f)) * 0.032f;						p *= 2.5f;	p.xz -= t * 0.165f;
			  noise += (1.0 - abs(Get3DNoise(p) * 2.0 - 1.0)) * 0.015f;												p *= 2.5f;
			  
			  noise /= 1.875f;


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
		float coverage = 0.45f;
			  coverage = mix(coverage, 0.77f, rainStrength);

			  float dist = length(worldPosition.xz - cameraPosition.xz);
			  coverage *= max(0.0f, 1.0f - dist / 40000.0f);
		float density = 0.87f;
		noise = GetCoverage(coverage, density, noise);
		noise = pow(noise, 1.5);


		if (noise <= 0.001f)
		{
			return vec4(0.0f, 0.0f, 0.0f, 0.0f);
		}

		
	float sundiff = Get3DNoise(p1 + worldLightVector.xyz * lightOffset);
		  sundiff += (1.0 - abs(Get3DNoise(p2 + worldLightVector.xyz * lightOffset * 0.5f) * 1.0f - 0.5f) - 0.1) * 0.55f;
		 
		  sundiff *= 0.955f;
		  sundiff *= cloudAltitudeWeight2;
	float preCoverage = sundiff;
		  sundiff = -GetCoverage(coverage * 1.0f, density * 0.5, sundiff);
	float sundiff2 = -GetCoverage(coverage * 1.0f, 0.0, preCoverage);
	float firstOrder 	= pow(clamp(sundiff * 1.2f + 1.7f, 0.0f, 1.0f), 8.0f);
	float secondOrder 	= pow(clamp(sundiff2 * 1.2f + 1.1f, 0.0f, 1.0f), 4.0f);



	float anisoBackFactor = mix(clamp(pow(noise, 2.0f) * 1.0f, 0.0f, 1.0f), 1.0f, pow(sunglow, 1.0f));
		  firstOrder *= anisoBackFactor * 0.99 + 0.01;
		  secondOrder *= anisoBackFactor * 0.8 + 0.2;
	float directLightFalloff = mix(firstOrder, secondOrder, 0.2f);
	
	vec3 colorDirect = colorSunlight * 2.515f;
		 DoNightEye(colorDirect);
		 colorDirect *= 1.0f + pow(sunglow, 4.0f) * 2400.0f * pow(firstOrder, 1.1f) * (1.0f - rainStrength);


	vec3 colorAmbient = colorSkylight * 0.065f;
		 colorAmbient *= mix(1.0f, 0.3f, timeMidnight);
		 colorAmbient = mix(colorAmbient, colorAmbient * 2.0f + colorSunlight * 0.05f, vec3(clamp(pow(1.0f - noise, 2.0f) * 1.0f, 0.0f, 1.0f)));
		 colorAmbient *= heightGradient * heightGradient + 0.05f;

	 vec3 colorBounced = colorBouncedSunlight * 0.35f;
	 	 colorBounced *= pow((1.0f - heightGradient), 8.0f);
	 	 colorBounced *= anisoBackFactor + 0.5;
	 	 colorBounced *= 1.0 - rainStrength;


		directLightFalloff *= 1.0f - rainStrength * 0.6f;

		

		vec3 color = mix(colorAmbient, colorDirect, vec3(min(1.0f, directLightFalloff)));
			 color += colorBounced;
		    

		color *= 1.0f;

		
		vec4 result = vec4(color.rgb, noise);

		return result;
	}
}

void 	CalculateClouds2 (inout vec4 color, vec4 screenSpacePosition, vec4 worldSpacePosition, vec3 worldLightVector)
{
	if (texcoord.s < 0.25f && texcoord.t < 0.25f)
	{
		
		vec2 coord = texcoord.st * 4.0f;


		vec4 screenPosition = GetScreenSpacePosition(coord);

		bool isSky = GetSkyMask(coord);

		float sunglow = CalculateSunglow(screenPosition, lightVector);

		vec4 worldPosition = gbufferModelViewInverse * GetScreenSpacePosition(coord);
			 worldPosition.xyz += cameraPosition.xyz;

		float cloudHeight = 220.0f;
		float cloudDepth  = 140.0f;
		float cloudDensity = 1.0f;

		float startingRayDepth = far - 5.0f;

		float rayDepth = startingRayDepth;
			 
		float rayIncrement = far / 10.0f;

			 
		int i = 0;

		vec3 cloudColor = colorSunlight;
		vec4 cloudSum = vec4(0.0f);
			 cloudSum.rgb = colorSkylight * 0.2f;
			 cloudSum.rgb = color.rgb;


		float cloudDistanceMult = 800.0f / far;


		float surfaceDistance = length(worldPosition.xyz - cameraPosition.xyz);

		vec4 toEye = gbufferModelView * vec4(0.0f, 0.0f, -1.0f, 0.0f);

		vec4 startPosition = GetCloudSpacePosition(coord, rayDepth, cloudDistanceMult);

		const int numSteps = 800;
		const float numStepsF = 800.0f;

		for (int i = 0; i < numSteps; i++)
		{

			float inormalized = i / numStepsF;
				 
			vec4 rayPosition = vec4(0.0);
			     rayPosition.xyz = mix(startPosition.xyz, cameraPosition.xyz, inormalized);

			float rayDistance = length((rayPosition.xyz - cameraPosition.xyz) / cloudDistanceMult);

			
			vec4 proximity =  CloudColor(rayPosition, sunglow, worldLightVector);
				 proximity.a *= cloudDensity;

				 if (!isSky)
				 proximity.a *= clamp((surfaceDistance - (rayDistance * cloudDistanceMult)) / rayIncrement, 0.0f, 1.0f);

			
			color.rgb = mix(color.rgb, proximity.rgb, vec3(min(1.0f, proximity.a * cloudDensity)));

			color.a += proximity.a;

			//Increment ray
			rayDepth -= rayIncrement;

		}

		
	}
}


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////MAIN//////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void main() {

	vec3 noisePattern = CalculateNoisePattern1(vec2(0.0f), 4);
	vec4 screenSpacePosition = GetScreenSpacePosition(texcoord.st);
	vec4 worldSpacePosition = gbufferModelViewInverse * screenSpacePosition;
	vec4 worldLightVector = shadowModelViewInverse * vec4(0.0f, 0.0f, 1.0f, 0.0f);
	vec3 normal = GetNormals(texcoord.st);

	vec4 light = vec4(0.0);
		 light = calculateGI( 1, 		vec2(0.0f			), 16.0f,  GI_QUALITY, noisePattern);

	if (light.r >= 1.0f)
	{
		light.r = 0.0f;
	}

	if (light.g >= 1.0f)
	{
		light.g = 0.0f;
	}

	if (light.b >= 1.0f)
	{
		light.b = 0.0f;
	}








	vec4 clouds = vec4(0.0);
	clouds.rgb = colorSkylight * 0.03;
	// CalculateClouds2(clouds, screenSpacePosition, worldSpacePosition, worldLightVector.xyz);
	clouds.rgb = pow(clouds.rgb, vec3(1.0 / 2.2));
	
	gl_FragData[0] = vec4(pow(light.rgb, vec3(1.0 / 2.2)), light.a);
	gl_FragData[1] = clouds;
}
