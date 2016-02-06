#ifndef SS_RAY
#define SS_RAY

/*!
 * \brief Sends a ray in screen-space until it fails behind a depth texture
 */

#define MAX_RAY_STEPS   50
#define RAY_STEP_LENGTH 0.02
#define RAY_GROWTH      1.1

/*
 * All vec3s should have the st texture coordinates in the st of the vec3 and the raw depth value in the z
 *
 * \param startPos The start position of the ray
 * \param direction The normalized direction to cast the ray in
 * \prarm depthTex The texture to check depths against
 */
vec2 castRay(in vec3 startPos, in vec3 direction, in sampler2D depthTex) {
    bool forward = true;
    float depthSample;
    float depthDiff;
    direction *= RAY_STEP_LENGTH;

    for(int i = 0; i < MAX_RAY_STEPS; i++) {
        startPos += direction;

        if(startPos.x < 0 || startPos.x > 1 || startPos.y < 0 || startPos.y > 1) {
            // If the ray goes off the screen, return -1
            return vec2(-1);
        }

        depthDiff = startPos.z - texture2D(depthTex, startPos.st).r;

        if(forward) {
            if(depthDiff > 0 && depthDiff < length(direction)) {
                direction = -1 * normalize(direction) * 0.15;
                forward = false;
            }
        } else {
            depthDiff *= -1;
            if(depthDiff > 0 && depthDiff < length(direction)) {
                return startPos.st;
            }
        }
        direction *= RAY_GROWTH;
    }
}

#endif
