#ifndef CLOUDS_CLOUDS_3
#define CLOUDS_CLOUDS_3

#ifdef CLOUDS_CLOUDS_3
float doNothing_clouds3;
#endif

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
 * Not even going to try to merge this with the other Get3DNoise
 */
float Get3DNoise3(in vec3 pos) {
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


vec4 CloudColor(in vec4 worldPosition, in float sunglow, in vec3 worldLightVector, in float frameTimeCounter) {
    float cloudHeight = 190.0f;
    float cloudDepth  = 120.0f;
    float cloudUpperHeight = cloudHeight + (cloudDepth / 2.0f);
    float cloudLowerHeight = cloudHeight - (cloudDepth / 2.0f);

    if (worldPosition.y < cloudLowerHeight || worldPosition.y > cloudUpperHeight) {
        return vec4(0.0f);

    } else {
        vec3 p = worldPosition.xyz / 150.0f;

        float t = frameTimeCounter * 0.25f;
        p.x -= t * 0.02f;

        float noise = Get3DNoise3(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f));
              p *= 2.0f;  p.x -= t * 0.097f;
              noise += (1.0 - abs(Get3DNoise3(p) * 1.0f - 0.5f) - 0.1) * 0.55f;
              p *= 2.5f;  p.xz -= t * 0.065f;
              noise += (1.0 - abs(Get3DNoise3(p) * 3.0f - 1.5f) - 0.2) * 0.065f;
              p *= 2.5f;  p.xz -= t * 0.165f;
              noise += (1.0 - abs(Get3DNoise3(p) * 3.0f - 1.5f)) * 0.032f;
              p *= 2.5f;  p.xz -= t * 0.165f;
              noise += (1.0 - abs(Get3DNoise3(p) * 2.0 - 1.0)) * 0.015f;
              p *= 2.5f;
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

        if (noise <= 0.001f) {
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

#include "base.glsl"

#endif
