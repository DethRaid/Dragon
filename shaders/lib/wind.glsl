#ifndef WAVES_GLSL
#define WAVES_GLSL

#line 4005

/*!
 * \brief Provides a function to get the current wind strength
 *
 * Wind is a function of the world time mostly. I model it as finite brownian noise with three octaves
 */

 #define WIND_STRENGTH 1

uniform sampler2D noisetex;

uniform float frameTimeCounter;
uniform int worldTime;

float getWindAmount(in vec3 worldPosition) {
    vec2 windSamplePos = worldPosition.xz + (vec2(cos(35.0), sin(35.0)) * 0.25) + vec2(frameTimeCounter * 300);

    float windSample1 = texture2D(noisetex, worldPosition.xz / 2048).g;
    float windSample2 = texture2D(noisetex, worldPosition.xz / 1024).g;
    float windSample3 = texture2D(noisetex, worldPosition.xz / 128).g;

    return (windSample1 * 0.5 + windSample2 * 0.25 + windSample3 * 0.125) * WIND_STRENGTH;
}

#endif
