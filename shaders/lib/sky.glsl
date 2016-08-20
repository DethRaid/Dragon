#ifndef SKY_GLSL
#define SKY_GLSL

/*!
 * \brief Defines the funcitons to render the sky
 *
 * From http://codeflow.org/entries/2011/apr/13/advanced-webgl-part-2-sky-rendering/
 */

#define RAYLEIGH_BRIGHTNESS         33.0
#define RAYLEIGH_STRENGTH           139.0
#define RAYLEIGH_LIGHT_COLLECTION_POWER 8.1
#define MIE_DISTRIBUTION            63.0
#define MIE_BRIGHTNESS              100.0
#define MIE_LIGHT_COLLECTION_POWER  3.9
#define MIE_STRENGTH                264.0
#define SPOT_BRIGHTNESS             1000.0
#define SKY_STEP_LENGTH             10.0
#define NUM_SKY_STEPS               10
#define SKY_INTENSITY               10
#define SKY_SCATTER_STRENGTH        28
#define WORLD_RADIUS                3000
#define ATMOSPHERE_HEIGHT           100

#define PI                          3.14159265

float phase(in float alpha, in float g) {
     float a = 3.0 * (1.0 - g * g);
     float b = 2.0 * (2.0 + g * g);
     float c = 1.0 + alpha * alpha;
     float d = pow(1.0 + g * g - 2.0 * g * alpha, 1.5);

     return (a * c) / (b * d);
}

float rayleighPhase(in float alpha) {
     // Special case where g = 0; Greatly simplifies the math
     float a = 3.0;
     float b = 4.0;
     float c = 1.0 + alpha * alpha;

     return (a * c) / b;
}

float getAtmosphericDepth(in vec3 position, in vec3 dir) {
     // Assumes tha the eye is always level
     float distToCenter = WORLD_RADIUS + dot(position, position);

     float totesRadius = WORLD_RADIUS + ATMOSPHERE_HEIGHT;  // This is totes the radius of the whole atmosphere, I promise
     return sqrt(distToCenter * distToCenter + totesRadius * totesRadius);

     //return 5;
     float a = dot(dir, dir);
     float b = 2.0 * dot(dir, position);
     float c = dot(position, position) - 1.0;
     float det = b * b - 4.0 * a * c;
     float detSqrt = sqrt(det);
     float q = (-b - detSqrt) / 2.0;

     return b * b / 30000;
}

float calculateOutScattering(in float height) {
    return 9.0;
}

vec3 getSkyColor(in vec3 viewVector, in vec3 lightVector, in vec3 skyColor, in vec3 cameraPosition) {
    // Trace a ray through the sky, sampling the scattering equations at each ray
    float atmosphereDepth = getAtmosphericDepth(cameraPosition, viewVector);
    float rayLength = atmosphereDepth / NUM_SKY_STEPS;

    vec3 rayPosition = cameraPosition;
    vec3 rayStep = viewVector * rayLength;

    float densityAccum = 0.0;

    for(int i = 0; i < NUM_SKY_STEPS; i++) {
        densityAccum += exp(-rayPosition.y / 256.0) * rayLength;
    }

    return skyColor;
}

/*float phase(in float alpha, in float g) {
     float a = 3.0 * (1.0 - g * g);
     float b = 2.0 * (2.0 + g * g);
     float c = 1.0 + alpha * alpha;
     float d = pow(1.0 + g * g - 2.0 * g * alpha, 1.5);
     return (a / b) * (c / d);
     }
     float getAtmosphericDepth(in vec3 position, in vec3 dir) {
     // Assumes tha the eye is always level
     float distToCenter = WORLD_RADIUS + dot(position, position);
     float totesRadius = WORLD_RADIUS + ATMOSPHERE_HEIGHT;  // This is totes the radius of the whole atmosphere, I promise
     return sqrt(distToCenter * distToCenter + totesRadius * totesRadius);
     //return 5;
     float a = dot(dir, dir);
     float b = 2.0 * dot(dir, position);
     float c = dot(position, position) - 1.0;
     float det = b * b - 4.0 * a * c;
     float detSqrt = sqrt(det);
     float q = (-b - detSqrt) / 2.0;
     return b * b / 30000;
     }
     float getHorizonExtinction(in vec3 position, in vec3 dir, in float radius) {
     vec3 temp = dir;
     float u = dot(dir, position);
     return u;
     if(u < 0.0) {
         return 1.0;
     }
     vec3 nearPos = position + u * dir;
     if(length(nearPos) < radius) {
         return 0.0;
     } else {
         vec3 v2 = normalize(nearPos) * radius - position;
         float diff = acos(dot(normalize(v2), dir));
         return smoothstep(0.0, 1.0, pow(diff * 2.0, 3.0));
     }
     }
     vec3 getLightAbsorbtion(in float dist, in vec3 color, in float factor, in vec3 skyColor) {
         return color - color * pow(skyColor, vec3(factor / dist));
     }
     vec3 getSkyColor(in vec3 viewVector, in vec3 lightDirection, in vec3 skyColor, in vec3 cameraPosition) {
     float alpha = dot(viewVector, lightDirection);
     float rayleighFactor = phase(alpha, -0.01) * RAYLEIGH_BRIGHTNESS;
     float mieFactor = phase(alpha, MIE_DISTRIBUTION) * MIE_BRIGHTNESS;
     float spot = smoothstep(0.0, 15.0, phase(alpha, 0.9995)) * SPOT_BRIGHTNESS;
     vec3 eyePosition = vec3(0, cameraPosition.y, 0);
     float eyeDepth = getAtmosphericDepth(eyePosition, viewVector);
     float stepLength = eyeDepth / SKY_STEP_LENGTH;
     float eyeExtinction = getHorizonExtinction(cameraPosition, viewVector, cameraPosition.y - 2);
     return vec3(eyeExtinction);
     vec3 rayleighCollected = vec3(0.0);
     vec3 mieCollected = vec3(0.0);
     vec3 influx;
     for(int i = 0; i < NUM_SKY_STEPS; i++) {
         float sampleDistance = stepLength * float(i);
         vec3 position = eyePosition + viewVector * sampleDistance;
         float extinction = getHorizonExtinction(position, lightDirection, cameraPosition.x - 0.35);
         float sampleDepth = getAtmosphericDepth(position, lightDirection);
         influx = getLightAbsorbtion(sampleDepth, vec3(SKY_INTENSITY), SKY_SCATTER_STRENGTH, skyColor);// * extinction;
         rayleighCollected += getLightAbsorbtion(sampleDistance, skyColor * influx, RAYLEIGH_STRENGTH, skyColor);
         mieCollected += getLightAbsorbtion(sampleDistance, influx, MIE_STRENGTH, skyColor);
     }
     rayleighCollected = (rayleighCollected * eyeExtinction);// * pow(eyeDepth, RAYLEIGH_LIGHT_COLLECTION_POWER)) / float(NUM_SKY_STEPS);
     mieCollected = (mieCollected * eyeExtinction);// * pow(eyeDepth, MIE_LIGHT_COLLECTION_POWER)) / float(NUM_SKY_STEPS);
     return vec3(spot * mieCollected + mieFactor * mieCollected + rayleighFactor * rayleighCollected);
}*/

#endif
