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
 //#define VOLUMETRIC_CLOUDS				//Original 3D Clouds from 1.0 and 1.1, bad dither pattern ripple, ONLY ENABLE ONE VOLUMETRIC CLOUDS
 #define VOLUMETRIC_CLOUDS2				//latest 3D clouds, Reduced dither pattern ripple, ONLY ENABLE ONE VOLUMETRIC CLOUDS
 //#define VOLUMETRIC_CLOUDS3
 #define SOFT_FLUFFY_CLOUDS				// dissable to fully remove dither Pattern ripple, adds a little pixel noise on cloud edge
 #define CLOUD_DISPERSE 10.0f          // increase this for thicker clouds and so that they don't fizzle away when you fly close to them, 10 is default Dont Go Over 30 will lag and maybe crash
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

float Get3DNoise3(in vec3 pos)
{
    pos.z += 0.0f;

    pos.xyz += 0.5f;

    vec3 p = floor(pos);
    vec3 f = fract(pos);

     f.x = f.x * f.x * (3.0f - 2.0f * f.x);
     f.y = f.y * f.y * (3.0f - 2.0f * f.y);
     f.z = f.z * f.z * (3.0f - 2.0f * f.z);

    vec2 uv =  (p.xy + p.z * vec2(17.0f)) + f.xy;
    vec2 uv2 = (p.xy + (p.z + 1.0f) * vec2(17.0f)) + f.xy;

     uv += 0.5f;
     uv2 += 0.5f;

    vec2 coord =  (uv  + 0.5f) / noiseTextureResolution;
    vec2 coord2 = (uv2 + 0.5f) / noiseTextureResolution;
    float xy1 = texture2D(noisetex, coord).x;
    float xy2 = texture2D(noisetex, coord2).x;
    return mix(xy1, xy2, f.z);
}


vec4 CloudColor2(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector, in float altitude, in float thickness, const bool isShadowPass)
{

    float cloudHeight = altitude;
    float cloudDepth  = thickness;
    float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
    float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

    worldPosition.xz /= 1.0f + max(0.0f, length(worldPosition.xz - cameraPosition.xz) / 9001.0f);

    vec3 p = worldPosition.xyz / 100.0f;



    float t = frameTimeCounter * CLOUD_SPEED;
          t *= 0.4;


     p += (Get3DNoise(p * 2.0f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.10f;

      p.x -= (Get3DNoise(p * 0.125f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 1.2f;
    // p.xz -= (Get3DNoise(p * 0.0525f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 1.7f;


    p.x *= 0.25f;
    p.x -= t * 0.003f;

    vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
    float noise  =  Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));   p *= 2.0f;  p.x -= t * 0.017f;  p.z += noise * 1.35f;   p.x += noise * 0.5f;                                    vec3 p2 = p;
          noise += (2.0f - abs(Get3DNoise(p) * 2.0f - 0.0f)) * (0.25f);                     p *= 3.0f;  p.xz -= t * 0.005f; p.z += noise * 1.35f;   p.x += noise * 0.5f;    p.x *= 3.0f;    p.z *= 0.55f;   vec3 p3 = p;
             p.z -= (Get3DNoise(p * 0.25f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.4f;
          noise += (3.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * (0.035f);                    p *= 3.0f;  p.xz -= t * 0.005f;                                                                                 vec3 p4 = p;
          noise += (3.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * (0.025f);                    p *= 3.0f;  p.xz -= t * 0.005f;
          if (!isShadowPass)
          {
                noise += ((Get3DNoise(p))) * (0.022f);                                              p *= 3.0f;
                 noise += ((Get3DNoise(p))) * (0.024f);
          }
          noise /= 1.575f;

    //cloud edge
    float rainy = mix(wetness, 1.0f, rainStrength);
          //rainy = 0.0f;


    float coverage = CLOUD_COVERAGE;


          float dist = length(worldPosition.xz - cameraPosition.xz);
          coverage *= max(0.0f, 1.0f - dist / mix(7000.0f, 3000.0f, rainStrength));
    float density = 0.0f;

    if (isShadowPass)
    {
        return vec4(GetCoverage(coverage + 0.2f, density + 0.2f, noise));
    }
    else
    {

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
        float secondOrder   = pow(clamp(sundiff * 1.00f + 1.35f, 0.0f, 1.0f), 7.0f);
        float firstOrder    = pow(clamp(largeSundiff * 1.1f + 1.56f, 0.0f, 1.0f), 3.0f);



        float directLightFalloff = secondOrder;
        float anisoBackFactor = mix(clamp(pow(noise, 1.6f) * 2.5f, 0.0f, 1.0f), 1.0f, pow(sunglow, 1.0f));

              directLightFalloff *= anisoBackFactor;
              directLightFalloff *= mix(1.5f, 1.0f, pow(sunglow, 1.0f))*CLOUD_BRIGHTNESS;



        vec3 colorDirect = colorSunlight * 10.0f;
                     colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.5f, 1.0f), timeMidnight);
        colorDirect *= 1.0f + pow(sunglow, 8.0f) * 100.0f;


        vec3 colorAmbient = mix(colorSkylight, colorSunlight, 0.15f) * 0.065f;
                     colorAmbient *= mix(0.85f, 0.3f, timeMidnight);


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
        //planeHeight += CalculateDitherPattern1() * stepSize;
        //planeHeight += CalculateDitherPattern() * stepSize;

        //while(planeHeight > cloudsLowerLimit)
        ///{
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
