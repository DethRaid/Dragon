#ifndef SS_RAY
#define SS_RAY

/*!
 * \brief Sends a ray in screen-space until it fails behind a depth texture
 */

#define MAX_RAY_LENGTH  50
#define RAY_STEP_LENGTH 0.02
#define RAY_GROWTH      1.1

vec2 getCoordFromCameraSpace(in vec3 position) {
    vec4 viewSpacePosition = gbufferProjection * vec4(position, 1);
    vec2 ndcSpacePosition = viewSpacePosition.xy / viewSpacePosition.w;
    return ndcSpacePosition * 0.5 + 0.5;
}

//Determines the UV coordinate where the ray hits
//If the returned value is not in the range [0, 1] then nothing was hit.
//NOTHING!
//Note that origin and direction are assumed to be in screen-space coordinates, such that
//  -origin.st is the texture coordinate of the ray's origin
//  -direction.st is of such a length that it moves the equivalent of one texel
//  -both origin.z and direction.z correspond to values raw from the depth buffer
vec3 castRay(in vec3 origin, in vec3 rayStep) {
    vec3 curPos = origin;
    vec2 curCoord = getCoordFromCameraSpace(curPos);
    rayStep = normalize(rayStep) * RAY_STEP_LENGTH;
    bool forward = true;
    float distanceTravelled = 0;
    float hasResult = 0.0;
    vec3 retVal = vec3(-1);

    //The basic idea here is the the ray goes forward until it's behind something,
    //then slowly moves forward until it's in front of something.
    for(int i = 0; i < MAX_RAY_LENGTH * (1 / RAY_STEP_LENGTH); i++) {
        curPos += rayStep;
        distanceTravelled += sqrt(dot(rayStep, rayStep));
        curCoord = getCoordFromCameraSpace(curPos);

        float worldDepth = getCameraSpacePosition(curCoord).z;
        float rayDepth = curPos.z;
        float depthDiff = (worldDepth - rayDepth);
        float maxDepthDiff = length(rayStep) + RAY_DEPTH_BIAS;
        if(forward) {
            if(depthDiff > 0 && depthDiff < maxDepthDiff) {
                //return curCoord;
                rayStep = -1 * normalize(rayStep) * 0.15;
                forward = false;
            }
        } else {
            depthDiff *= -1;
            if(depthDiff > 0 && depthDiff < maxDepthDiff) {
                return vec3(curCoord, distanceTravelled);
            }
        }
        rayStep *= RAY_GROWTH;
    }

    return retVal;
}

#endif
