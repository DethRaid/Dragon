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
#endif

float GetCoverage(in float coverage, in float density, in float clouds) {
    clouds = clamp(clouds - (1.0f - coverage), 0.0f, 1.0f -density) / (1.0f - density);
        clouds = max(0.0f, clouds * 1.1f - 0.1f);
     // clouds = clouds = clouds * clouds * (3.0f - 2.0f * clouds);
     // clouds = pow(clouds, 1.0f);
    return clouds;
}

vec4 CloudColor(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector) {
    float cloudHeight = 230.0f;
    float cloudDepth  = 150.0f;
    float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
    float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

    if (worldPosition.y < cloudLowerHeight || worldPosition.y > cloudUpperHeight) {
        return vec4(0.0f);

    } else {
        vec3 p = worldPosition.xyz / 150.0f;

        float t = frameTimeCounter / 2.0;
              //t *= 0.001;
        p.x -= t * 0.02f;

        p += (Get3DNoise(p * 1.0f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.3f;

        vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
        float noise  =  Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));   p *= 4.0f;  p.x -= t * 0.02f;   vec3 p2 = p;
              noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.20f;               p *= 3.0f;  p.xz -= t * 0.05f;  vec3 p3 = p;
              noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.075f;              p *= 2.0f;  p.xz -= t * 0.05f;
              noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.05f;               p *= 2.0f;
              noise /= 1.2f;

        const float lightOffset = 0.35f;

        float cloudAltitudeWeight = 1.0f - clamp(distance(worldPosition.y, cloudHeight) / (cloudDepth / 2.0f), 0.0f, 1.0f);
              cloudAltitudeWeight = pow(cloudAltitudeWeight, 0.5f);

        noise *= cloudAltitudeWeight;

        //cloud edge
        float coverage = 0.45f;
              coverage = mix(coverage, 0.77f, rainStrength);
        float density = 0.66f;
        noise = clamp(noise - (1.0f - coverage), 0.0f, 1.0f - density) / (1.0f - density);

        float directLightFalloff = clamp(pow(-(cloudLowerHeight - worldPosition.y) / cloudDepth, 3.5f), 0.0f, 1.0f);

              directLightFalloff *= mix(    clamp(pow(noise, 0.9f), 0.0f, 1.0f),    clamp(pow(1.0f - noise, 10.3f), 0.0f, 0.5f),    pow(sunglow, 0.2f));

        vec3 colorDirect = colorSunlight * 38.0f;
        colorDirect = mix(colorDirect, colorDirect * vec3(0.1f, 0.2f, 0.3f), timeMidnight);
        colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.2f, 0.2f), rainStrength);
        colorDirect *= 1.0f + pow(sunglow, 4.0f) * 100.0f;

        vec3 colorAmbient = mix(colorSkylight, colorSunlight, 0.15f) * 0.065f;
             colorAmbient *= mix(1.0f, 0.3f, timeMidnight);

        vec3 color = mix(colorAmbient, colorDirect, vec3(directLightFalloff));

        vec4 result = vec4(color.rgb, noise);

        return result;
    }
}

vec4 CloudColors(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector)
{

    float cloudHeight = 230.0f;
    float cloudDepth  = 150.0f;
    float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
    float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

    if (worldPosition.y < cloudLowerHeight || worldPosition.y > cloudUpperHeight)
        return vec4(0.0f);
    else
    {

        vec3 p = worldPosition.xyz / 150.0f;



        float t = frameTimeCounter / 2.0f;
        p.x -= t * 0.02f;

         p += (Get3DNoise(p * 1.0f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.3f;

        vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
        float noise  =  Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));   p *= 2.0f;  p.x -= t * 0.097f;  vec3 p2 = p;
              noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.20f;               p *= 3.0f;  p.xz -= t * 0.05f;  vec3 p3 = p;
              noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.075f;              p *= 2.0f;  p.xz -= t * 0.05f;
              noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.05f;               p *= 2.0f;
              noise /= 1.2f;



        const float lightOffset = 0.33f;


        float cloudAltitudeWeight = 1.0f - clamp(distance(worldPosition.y, cloudHeight) / (cloudDepth / 2.0f), 0.0f, 1.0f);
              cloudAltitudeWeight = pow(cloudAltitudeWeight, 0.5f);

        noise *= cloudAltitudeWeight;

        //cloud edge
        float rainy = mix(wetness, 1.0f, rainStrength);
        float coverage = Vol_Cloud_Coverage + rainy * 0.335f;
              coverage = mix(coverage, 0.77f, rainStrength);
        float density = 0.66f;
        noise = clamp(noise - (1.0f - coverage), 0.0f, 1.0f - density) / (1.0f - density);



        float directLightFalloff = clamp(pow(-(cloudLowerHeight - worldPosition.y) / cloudDepth, 3.5f), 0.0f, 1.0f);

              directLightFalloff *= mix(    clamp(pow(noise, 0.9f), 0.0f, 1.0f),    clamp(pow(1.0f - noise, 10.3f), 0.0f, 0.5f),    pow(sunglow, 0.2f));

        vec3 colorDirect = colorSunlight * 25.0f;
        colorDirect = mix(colorDirect, colorDirect * vec3(0.1f, 0.2f, 0.3f), timeMidnight);
        colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.2f, 0.2f), rainStrength);
        colorDirect *= 1.0f + pow(sunglow, 4.0f) * 100.0f;


        vec3 colorAmbient = mix(colorSkylight, colorSunlight, 0.15f) * 0.065f;
             colorAmbient *= mix(1.0f, 0.3f, timeMidnight);


        vec3 color = mix(colorAmbient, colorDirect, vec3(directLightFalloff));

        vec4 result = vec4(color.rgb, noise);

        return result;
    }
}

void    CalculateClouds2 (inout vec3 color, inout SurfaceStruct surface)
{

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
              rayDepth += CalculateDitherPattern1() * rayIncrement;
              #else
              rayDepth += CalculateDitherPattern2() * rayIncrement;
        #endif

        int i = 0;

        vec3 cloudColors = colorSunlight;
        vec4 cloudSum = vec4(0.0f);
             cloudSum.rgb = colorSkylight * 0.2f;
             cloudSum.rgb = color.rgb;

        float sunglow = CalculateSunglow(surface);

        float cloudDistanceMult = 400.0f / far;


        float surfaceDistance = length(worldPosition.xyz - cameraPosition.xyz);

        while (rayDepth > 0.0f)
        {
            //determine worldspace ray position
            vec4 rayPosition = GetCloudSpacePosition(texcoord.st, rayDepth, cloudDistanceMult);

            float rayDistance = length((rayPosition.xyz - cameraPosition.xyz) / cloudDistanceMult);

            vec4 proximity =  CloudColors(rayPosition, sunglow, surface.worldLightVector);
                 proximity.a *= cloudDensity;

                 if (surfaceDistance < rayDistance * cloudDistanceMult  && surface.mask.sky == 0.0)
                    proximity.a = 0.0f;


            color.rgb = mix(color.rgb, proximity.rgb, vec3(min(1.0f, proximity.a * cloudDensity)));

            surface.cloudAlpha += proximity.a;

            //Increment ray
            rayDepth -= rayIncrement;
            i++;


        }


}

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

vec4 CloudColor3(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector)
{

    float cloudHeight = 190.0f;
    float cloudDepth  = 120.0f;
    float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
    float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

    if (worldPosition.y < cloudLowerHeight || worldPosition.y > cloudUpperHeight)
        return vec4(0.0f);
    else
    {

        vec3 p = worldPosition.xyz / 150.0f;



        float t = frameTimeCounter * 0.25f;
              //t *= 0.001;
        p.x -= t * 0.02f;

        // p += (Get3DNoise3(p * 1.0f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.15f;

        vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
        float noise  =  Get3DNoise3(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));  p *= 2.0f;  p.x -= t * 0.097f;  vec3 p2 = p;
              noise += (1.0 - abs(Get3DNoise3(p) * 1.0f - 0.5f) - 0.1) * 0.55f;                 p *= 2.5f;  p.xz -= t * 0.065f; vec3 p3 = p;
              noise += (1.0 - abs(Get3DNoise3(p) * 3.0f - 1.5f) - 0.2) * 0.065f;                    p *= 2.5f;  p.xz -= t * 0.165f; vec3 p4 = p;
              noise += (1.0 - abs(Get3DNoise3(p) * 3.0f - 1.5f)) * 0.032f;                      p *= 2.5f;  p.xz -= t * 0.165f;
              noise += (1.0 - abs(Get3DNoise3(p) * 2.0 - 1.0)) * 0.015f;                                                p *= 2.5f;
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
        float rainy = mix(wetness, 1.0f, rainStrength);
        float coverage = Vol_Cloud_Coverage3 + rainy * 0.335f;
              coverage = mix(coverage, 0.77f, rainStrength);

              float dist = length(worldPosition.xz - cameraPosition.xz);
              coverage *= max(0.0f, 1.0f - dist / 40000.0f);
        float density = 0.90f;
        noise = GetCoverage(coverage, density, noise);
        noise = pow(noise, 1.5);


        if (noise <= 0.001f)
        {
            return vec4(0.0f, 0.0f, 0.0f, 0.0f);
        }


    float sundiff = Get3DNoise3(p1 + worldLightVector.xyz * lightOffset);
          sundiff += (1.0 - abs(Get3DNoise3(p2 + worldLightVector.xyz * lightOffset / 2.0f) * 1.0f - 0.5f) - 0.1) * 0.55f;
          sundiff *= 0.955f;
          sundiff *= cloudAltitudeWeight2;
    float preCoverage = sundiff;
          sundiff = -GetCoverage(coverage * 1.0f, density * 0.5, sundiff);
    float sundiff2 = -GetCoverage(coverage * 1.0f, 0.0, preCoverage);
    float firstOrder    = pow(clamp(sundiff * 1.2f + 1.7f, 0.0f, 1.0f), 8.0f);
    float secondOrder   = pow(clamp(sundiff2 * 1.2f + 1.1f, 0.0f, 1.0f), 4.0f);



    float anisoBackFactor = mix(clamp(pow(noise, 1.6f) * 2.5f, 0.0f, 1.0f), 1.0f, pow(sunglow, 1.0f));
          firstOrder *= anisoBackFactor * 0.099 + 0.1;
          secondOrder *= anisoBackFactor * 0.09 + 0.9;
    float directLightFalloff = mix(firstOrder, secondOrder, 0.2f);

    vec3 colorDirect = colorSunlight * 2.0f;
    //colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.5f, 1.0f), timeMidnight)/4;
         DoNightEye(colorDirect);
         colorDirect += colorSunlight * 1.0f * timeMidnight;
        colorDirect -= colorDirect * 0.88 * timeMidnight;
         colorDirect *= 1.0f + pow(sunglow, 8.0f) * 100.0f;


    vec3 colorAmbient = mix(colorSkylight, colorSunlight, 0.15f) * 0.065f;
                     colorAmbient *= mix(0.85f, 0.3f, timeMidnight);

     vec3 colorBounced = colorBouncedSunlight * 5.35f;
         colorBounced *= pow((1.0f - heightGradient), 8.0f);
         colorBounced *= anisoBackFactor + 0.5;
         colorBounced *= 1.0 - rainStrength;


        directLightFalloff *= 1.0f - rainStrength * 0.99f;


        vec3 color = mix(colorAmbient, colorDirect, vec3(min(1.0f, directLightFalloff)));
             color += colorBounced;

        color *= 1.0f;


        vec4 result = vec4(color.rgb, noise);

        return result;
    }
}

void    CalculateClouds3 (inout vec3 color, inout SurfaceStruct surface)
{

        surface.cloudAlpha = 0.0f;

        vec2 coord = texcoord.st * 2.0f;

        vec4 worldPosition = gbufferModelViewInverse * surface.screenSpacePosition;
             worldPosition.xyz += cameraPosition.xyz;

        float cloudHeight = 150.0f;
        float cloudDepth  = 60.0f;
        float cloudDensity = 2.5f;

        float startingRayDepth = far - 5.0f;

        float rayDepth = startingRayDepth;
              //rayDepth += CalculateDitherPattern1() * 0.09f;
              //rayDepth += texture2D(noisetex, texcoord.st * (viewWidth / noiseTextureResolution, viewHeight / noiseTextureResolution)).x * 0.1f;
              //rayDepth += CalculateDitherPattern2() * 0.1f;
        float rayIncrement = far / CLOUD_DISPERSE;

        #ifdef SOFT_FLUFFY_CLOUDS
              rayDepth += CalculateDitherPattern1() * rayIncrement;
              #else
              rayDepth += CalculateDitherPattern2() * rayIncrement;
        #endif

        int i = 0;

        vec3 cloudColor3 = colorSunlight;
        vec4 cloudSum = vec4(0.0f);
             //cloudSum.rgb = colorSkylight * 0.2f;
             cloudSum.rgb = color.rgb;

        float sunglow = CalculateSunglow(surface);

        float cloudDistanceMult = 400.0f / far;


        float surfaceDistance = length(worldPosition.xyz - cameraPosition.xyz);

        while (rayDepth > 0.0f)
        {
            //determine worldspace ray position
            vec4 rayPosition = GetCloudSpacePosition(texcoord.st, rayDepth, cloudDistanceMult);

            float rayDistance = length((rayPosition.xyz - cameraPosition.xyz) / cloudDistanceMult);

            vec4 proximity =  CloudColor3(rayPosition, sunglow, surface.worldLightVector);
                 proximity.a *= cloudDensity;

                 //proximity.a *=  clamp(surfaceDistance - rayDistance, 0.0f, 1.0f);
                 if (surfaceDistance < rayDistance * cloudDistanceMult  && surface.mask.sky == 0.0)
                    proximity.a = 0.0f;

            cloudSum.rgb = mix( cloudSum.rgb, proximity.rgb, vec3(min(1.0f, proximity.a * cloudDensity)) );
            cloudSum.a += proximity.a * cloudDensity;
            //color.rgb = mix(color.rgb, proximity.rgb, vec3(min(1.0f, proximity.a * cloudDensity)));

            surface.cloudAlpha += proximity.a;

            //Increment ray
            rayDepth -= rayIncrement;
            i++;

             // if (rayDepth * cloudDistanceMult  < ((cloudHeight - (cloudDepth * 0.5)) - cameraPosition.y))
             // {
             //     break;
             // }
        }

        color.rgb = mix(color.rgb, cloudSum.rgb, vec3(min(1.0f, cloudSum.a * 50.0f)));

    if (cloudSum.a > 0.00f)
    {
        surface.mask.volumeCloud = 1.0;
    }

    //color.rgb = vec3(noise) * 0.2f;
        //color.rgb = cloudSum.rgb;
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
