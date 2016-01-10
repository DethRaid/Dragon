/*
 * Needed things:
    - Get3DNoise
    - CalculateDitherPattern[1,2]
    - CalculateSunglow
    - GetCloudSpacePosition
 */

#ifndef CLOUDS_BASE
#define CLOUDS_BASE

#ifdef CLOUDS_BASE
float doNothing_base;
#endif

#include "/lib/surface.glsl"

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

/*
 * Relies on a function called vec4 CloudColor(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector). You have to define
 * that function before this one exists, or you'll get yelled at. There's a simple one in color.glsl (in this folder) and a more complex
 * one in clouds3.glsl (also in this folder)
 */
void    CalculateClouds(inout vec3 color, inout SurfaceStruct surface) {
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
        rayDepth += CalculateDitherPattern1(texcoord.st, viewWidth, viewHeight) * rayIncrement;
    #else
        rayDepth += CalculateDitherPattern2(texcoord.st, viewWidth, viewHeight) * rayIncrement;
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

        vec4 proximity =  CloudColor(rayPosition, sunglow, surface.worldLightVector);
             proximity.a *= cloudDensity;

         if (surfaceDistance < rayDistance * cloudDistanceMult  && surface.mask.sky == 0.0) {
            proximity.a = 0.0f;
        }

        color.rgb = mix(color.rgb, proximity.rgb, vec3(min(1.0f, proximity.a * cloudDensity)));

        surface.cloudAlpha += proximity.a;

        //Increment ray
        rayDepth -= rayIncrement;
        i++;
    }
}
#endif
