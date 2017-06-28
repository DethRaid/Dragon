#line 1000

// This file comes from Jodie's in-dev shaderpack

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)

#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)


vec3 toClipSpace(vec3 viewSpacePosition) {
    return projMAD(gbufferProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

#define faceVisible() abs(pos.z-depth) < abs(stepLength*direction.z)
#define onScreen() (floor(pos.xy) == vec2(0))

float hash12(vec2 p){
    p  = fract(p * .1031);
    p += dot(p, p.yx + 19.19);
    return fract((p.x + p.y) * p.x);
}
//float dither=bayer16x16( ivec2(coord*vec2(viewWidth,viewHeight)) );
float dither = hash12(coord * vec2(viewWidth, viewHeight));

/*!
 * \brief Casts a ray in clip space to hit something
 */
vec3 rayTrace(vec3 dir, vec3 position, vec3 clipPosition, const float num_steps) {
    vec3 direction = normalize(toClipSpace(position + dir) - clipPosition);

    direction.xy = normalize(direction.xy);
    //get at which length the ray intersects with the edge of the screen
    vec3 maxLengths = (step(0., direction) - clipPosition) / direction;
    float mult = min(min(maxLengths.x, maxLengths.y), maxLengths.z);
    float maxStepLength = mult / num_steps;
    float minStepLength = maxStepLength * .1;

    float stepLength = maxStepLength * (0.1 + dither * 0.9);
    vec3 pos = clipPosition + direction * stepLength;
    float depth = texture2D(depthtex0, pos.xy).x;

    bool rayHit;
    

    for(int i = 0; i < int(num_steps) + 4; i++) {
        rayHit = depth < pos.z;
        if(rayHit || !onScreen()) break;
        stepLength = (depth - pos.z) / abs(direction.z);
        stepLength = clamp(stepLength, minStepLength, maxStepLength);
        pos += direction * stepLength;
        depth = texture2D(depthtex0, pos.xy).x;
    }

    if(faceVisible()) {
        stepLength = (depth-pos.z) / abs(direction.z);
        pos += direction * stepLength;
        depth = texture2D(depthtex0, pos.xy).x;
    }

    if(
        faceVisible() + .0001 //not backface
        && depth < 1. //not sky
        && 0.97 < pos.z //fixes bug when too close to camera
        && onScreen()
        && rayHit
    ) {
        return pos;
    }

    return vec3(-1);
}