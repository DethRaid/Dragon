/*
 * Needed things:
    - Get3DNoise
    - CalculateDitherPattern[1,2]
    - CalculateSunglow
    - GetCloudSpacePosition
 */

/*
 * Look, a self-contained function with no external dependencies. How amazing!
 */
float GetCoverage(in float coverage, in float density, in float clouds) {
    clouds = clamp(clouds - (1.0f - coverage), 0.0f, 1.0f -density) / (1.0f - density);
        clouds = max(0.0f, clouds * 1.1f - 0.1f);
     // clouds = clouds = clouds * clouds * (3.0f - 2.0f * clouds);
     // clouds = pow(clouds, 1.0f);
    return clouds;
}

/*
 * Calculates the color of clouds.
 *
 * Relies on two global parameters - initial_p_multiplier and initial_t_multiplier. I can't exmplain exactly how they work,
 * but their values control the clouds algorithms a good bit.
 *
 * Those parameters are defined in the clouds1.glsl and clouds2.glsl files.
 *
 * I know, I know. Making this function rely on globals defined in other files is a horrible, awful idea. If I was the one to design
 * this code, things would be different. I wasn't, though. I'm just trying my best to reduce the code size by eliminating copy-pasta
 * code. With more time I can make it better - and I will make it better! - but for now this is what we've got.
 *
 * To any future code maintainers - I'm sorry.
 */
vec4 CloudColor(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector) {
    float cloudHeight = 230.0f;
    float cloudDepth  = 150.0f;
    float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
    float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

    if (worldPosition.y < cloudLowerHeight || worldPosition.y > cloudUpperHeight) {
        return vec4(0.0f);

    } else {
        vec3 p = worldPosition.xyz / 150.0f;

        float t = frameTimeCounter / 2.0f;
        p.x -= t * 0.02f;

        p += (Get3DNoise(p * 1.0f + vec3(0.0f, t * 0.01f, 0.0f)) * 2.0f - 1.0f) * 0.3f;

        float noise = Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));   p *= initial_p_multiplier;  p.x -= t * initial_t_multiplier;
              noise += (1.0f - abs(Get3DNoise(p) * 3.0f - 1.0f)) * 0.20f;               p *= 3.0f;  p.xz -= t * 0.05f;
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
              directLightFalloff *= mix(clamp(pow(noise, 0.9f), 0.0f, 1.0f), clamp(pow(1.0f - noise, 10.3f), 0.0f, 0.5f), pow(sunglow, 0.2f));

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
