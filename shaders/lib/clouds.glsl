#ifndef CLOUDS_GLSL
#define CLOUDS_GLSL

/*
 * Includes all the code to make 3D SEUS clouds work
 *
 *
 * Needs:
    - GetNoise3D
    - frameTimeCounter
    - rainStrength
    - colorSunlight
    - SurfaceStruct
 */

 //----------3D clouds----------//
 //#define VOLUMETRIC_CLOUDS			//Original 3D Clouds from 1.0 and 1.1, bad dither pattern ripple, ONLY ENABLE ONE VOLUMETRIC CLOUDS
 #define VOLUMETRIC_CLOUDS2				//latest 3D clouds, Reduced dither pattern ripple, ONLY ENABLE ONE VOLUMETRIC CLOUDS
 //#define VOLUMETRIC_CLOUDS3
 #define SOFT_FLUFFY_CLOUDS				// dissable to fully remove dither Pattern ripple, adds a little pixel noise on cloud edge
 #define CLOUD_DISPERSE 10.0f           // increase this for thicker clouds and so that they don't fizzle away when you fly close to them, 10 is default Dont Go Over 30 will lag and maybe crash
 #define Vol_Cloud_Coverage 0.45f		// Vol_Cloud_Coverage. 0.20 = Lowest Cover. 0.60 = Highest Cover [0.20 0.30 0.45 0.50 0.60 0.70]
 #define Vol_Cloud_Coverage3 0.48		// Vol_Cloud_Coverage. 0.20 = Lowest Cover. 0.60 = Highest Cover [0.20 0.30 0.48 0.50 0.60 0.70]

 //----------New 2D clouds----------//
 //#define CLOUD_PLANE					// OLD 2D clouds, do not enable
 #define CLOUD_COVERAGE 0.41f + rainy * 0.55f;			//to increase the 2Dclouds:" 0.59f + rainy * 0.35f " is Default when not using 3DClouds," 0.5f + rainy * 0.35f " is best for when using 2D and 3D clouds
 #define CLOUD_SPEED 1.0f				//1 is default, use 2 if using new clouds in composite2
 #define CLOUD_BRIGHTNESS 2 			//2 is default, use 2.5 if using new clouds

 //----------End CONFIGURABLE 2D Clouds----------//

 //#define CLOUD_SHADOW

#ifdef VOLUMETRIC_CLOUDS
    #include "clouds/clouds1.glsl"
#elif VOLUMETRIC_CLOUDS2
    #include "clouds/clouds2.glsl"
#elif VOLUMETRIC_CLOUDS3
    #include "clouds/clouds3.glsl"
#endif

void CloudPlane(inout SurfaceStruct surface)
{
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

    if (cameraPosition.y < cloudsLowerLimit)
    {
        float planeHeight = cloudsUpperLimit;

        float stepSize = 25.5f;
        planeHeight -= cloudsThickness * 0.85f;

        Plane pl;
        pl.origin = vec3(0.0f, cameraPosition.y - planeHeight, 0.0f);
        pl.normal = vec3(0.0f, 1.0f, 0.0f);

        Intersection i = RayPlaneIntersectionWorld(surface.viewRay, pl);

        if (i.angle < 0.0f)
        {
            if (i.distance < surface.linearDepth || surface.mask.sky > 0.0f)
            {
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

float CloudShadow(in SurfaceStruct surface)
{
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

#endif
