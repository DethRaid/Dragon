/*
 * Needed things:
    - Get3DNoise
    - GetCoverage
    - CalculateDitherPattern[1,2]
    - CalculateSunglow
    - GetCloudSpacePosition
 */


vec4 CloudColor(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector, in float altitude, in float thickness) {
     float cloudHeight = altitude;
     float cloudDepth  = thickness;
     float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
     float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

     worldPosition.xz /= 1.0f + max(0.0f, length(worldPosition.xz - cameraPosition.xz) / 3000.0f);

     vec3 p = worldPosition.xyz / 300.0f;

     float t = frameTimeCounter * 1.0f;
           //t *= 0.001;
     p.x -= t * 0.01f;
     p += (Get3DNoise(p * 1.0f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.3f;

     vec3 p1 = p * vec3(1.0f, 0.5f, 1.0f)  + vec3(0.0f, t * 0.01f, 0.0f);
     float noise  =  Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));   p *= 2.0f;  p.x -= t * 0.057f;  vec3 p2 = p;
           noise += (1.0f - abs(Get3DNoise(p) * 1.0f - 0.5f)) * 0.15f;                       p *= 3.0f;  p.xz -= t * 0.035f; vec3 p3 = p;
           noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * 0.045f;                      p *= 3.0f;  p.xz -= t * 0.035f; vec3 p4 = p;
           noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * 0.015f;                      p *= 3.0f;  p.xz -= t * 0.035f;
           noise += ((Get3DNoise(p))) * 0.015f;                                              p *= 3.0f;
           noise += ((Get3DNoise(p))) * 0.006f;
           noise /= 1.175f;

     const float lightOffset = 0.2f;

     float heightGradient = clamp(( - (cloudLowerHeight - worldPosition.y) / (cloudDepth * 1.0f)), 0.0f, 1.0f);
     float heightGradient2 = clamp(( - (cloudLowerHeight - (worldPosition.y + worldLightVector.y * lightOffset * 50.0f)) / (cloudDepth * 1.0f)), 0.0f, 1.0f);

     float cloudAltitudeWeight = 1.0f;

     float cloudAltitudeWeight2 = 1.0f;

     noise *= cloudAltitudeWeight;

     //cloud edge
     float coverage = 0.39f;
           coverage = mix(coverage, 0.77f, rainStrength);

           float dist = length(worldPosition.xz - cameraPosition.xz);
           coverage *= max(0.0f, 1.0f - dist / 40000.0f);
     float density = 0.8f;
     noise = GetCoverage(coverage, density, noise);

     float sundiff = Get3DNoise(p1 + worldLightVector.xyz * lightOffset);
           sundiff += Get3DNoise(p2 + worldLightVector.xyz * lightOffset / 2.0f) * 0.15f;
                         float largeSundiff = sundiff;
                               largeSundiff = -GetCoverage(coverage, 0.0f, largeSundiff * 1.3f);
           sundiff += Get3DNoise(p3 + worldLightVector.xyz * lightOffset / 5.0f) * 0.045f;
           sundiff += Get3DNoise(p4 + worldLightVector.xyz * lightOffset / 8.0f) * 0.015f;
           sundiff *= 1.3f;
           sundiff *= cloudAltitudeWeight2;
           sundiff = -GetCoverage(coverage * 1.0f, 0.0f, sundiff);
     float firstOrder    = pow(clamp(sundiff * 1.0f + 1.1f, 0.0f, 1.0f), 12.0f);
     float secondOrder   = pow(clamp(largeSundiff * 1.0f + 0.9f, 0.0f, 1.0f), 3.0f);

     float directLightFalloff = mix(firstOrder, secondOrder, 0.1f);
     float anisoBackFactor = mix(clamp(pow(noise, 1.6f) * 2.5f, 0.0f, 1.0f), 1.0f, pow(sunglow, 1.0f));

           directLightFalloff *= anisoBackFactor;
           directLightFalloff *= mix(11.5f, 1.0f, pow(sunglow, 0.5f));

     vec3 colorDirect = colorSunlight * 0.815f;
          colorDirect = mix(colorDirect, colorDirect * vec3(0.2f, 0.5f, 1.0f), timeMidnight);
          colorDirect *= 1.0f + pow(sunglow, 2.0f) * 300.0f * pow(directLightFalloff, 1.1f) * (1.0f - rainStrength);


     vec3 colorAmbient = mix(colorSkylight, colorSunlight * 2.0f, vec3(heightGradient * 0.0f + 0.15f)) * 0.36f;
          colorAmbient *= mix(1.0f, 0.3f, timeMidnight);
          colorAmbient = mix(colorAmbient, colorAmbient * 3.0f + colorSunlight * 0.05f, vec3(clamp(pow(1.0f - noise, 12.0f) * 1.0f, 0.0f, 1.0f)));
          colorAmbient *= heightGradient * heightGradient + 0.1f;

      vec3 colorBounced = colorBouncedSunlight * 0.1f;
          colorBounced *= pow((1.0f - heightGradient), 8.0f);

     directLightFalloff *= 1.0f;
     //directLightFalloff += pow(Get3DNoise(p3), 2.0f) * 0.05f + pow(Get3DNoise(p4), 2.0f) * 0.015f;

     vec3 color = mix(colorAmbient, colorDirect, vec3(min(1.0f, directLightFalloff)));

     color *= 1.0f;

     vec4 result = vec4(color.rgb, noise);

     return result;
}

void    CalculateClouds (inout vec3 color, inout SurfaceStruct surface) {
        surface.cloudAlpha = 0.0f;

        vec2 coord = texcoord.st * 2.0f;

        vec4 worldPosition = gbufferModelViewInverse * surface.screenSpacePosition;
             worldPosition.xyz += cameraPosition.xyz;

        float cloudHeight = 150.0f;
        float cloudDepth  = 60.0f;
        float cloudDensity = 2.25f;

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

        vec3 cloudColor = colorSunlight;
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

            //proximity.a *=  clamp(surfaceDistance - rayDistance, 0.0f, 1.0f);
            if (surfaceDistance < rayDistance * cloudDistanceMult  && surface.mask.sky == 0.0)
                proximity.a = 0.0f;

            color.rgb = mix(color.rgb, proximity.rgb, vec3(min(1.0f, proximity.a * cloudDensity)));

            surface.cloudAlpha += proximity.a;

            //Increment ray
            rayDepth -= rayIncrement;
            i++;
        }
}
