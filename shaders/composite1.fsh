#version 120
#extension GL_ARB_shader_texture_lod : enable


//---------- Diffuse bouncing variables ------------//
#define MAX_RAY_LENGTH          10.0
#define MAX_DEPTH_DIFFERENCE    0.6     //How much of a step between the hit pixel and anything else is allowed?
#define RAY_STEP_LENGTH         0.8
#define RAY_DEPTH_BIAS          0.05    //Serves the same purpose as a shadow bias
#define RAY_GROWTH              1.04    //Make this number smaller to get more accurate reflections at the cost of performance
                                        //numbers less than 1 are not recommended as they will cause ray steps to grow
                                        //shorter and shorter until you're barely making any progress
#define NUM_RAYS                3       //The best setting in the whole shader pack. If you increase this value,
                                        //more and more rays will be sent per pixel, resulting in better and better
                                        //reflections. If you computer can handle 4 (or even 16!) I highly recommend it.
//---------- End diffuse bouncing variables ------------//

/* DRAWBUFFERS:7 */

uniform sampler2D gdepthtex;
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform vec3 cameraPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelView;

varying vec2 texcoord;

float 	GetMaterialIDs(in vec2 coord) {			//Function that retrieves the texture that has all material IDs stored in it
	return texture2D(colortex1, coord).r;
}

float 	GetMaterialMask(in vec2 coord ,const in int ID, in float matID) {
	matID = (matID * 255.0f);

	//Catch last part of sky
	if (matID > 254.0f) {
		matID = 0.0f;
	}

	if (matID == ID) {
		return 1.0f;
	} else {
		return 0.0f;
	}
}

vec3 GetNormals(in vec2 coord) {
	return texture2DLod(colortex2, coord.st, 0).xyz * 2.0 - 1.0;
}

float getDepth(vec2 coord) {
    return texture2D(gdepthtex, coord).r;
}

float getDepthLinear(vec2 coord) {
    return 2.0 * near * far / (far + near - (2.0 * texture2D(gdepthtex, coord).r - 1.0) * (far - near));
}

vec3 getCameraSpacePosition(vec2 uv) {
    float depth = getDepth(uv);
    vec4 fragposition = gbufferProjectionInverse * vec4(uv.s * 2.0 - 1.0, uv.t * 2.0 - 1.0, 2.0 * depth - 1.0, 1.0);
         fragposition /= fragposition.w;
    return fragposition.xyz;
}

vec3 getWorldSpacePosition(vec2 uv) {
    vec4 pos = vec4(getCameraSpacePosition(uv), 1);
    pos = gbufferModelViewInverse * pos;
    pos.xyz += cameraPosition.xyz;
    return pos.xyz;
}

vec3 cameraToWorldSpace(vec3 cameraPos) {
    vec4 pos = vec4(cameraPos, 1);
    pos = gbufferModelViewInverse * pos;
    pos.xyz /= pos.w;
    return pos.xyz;
}

vec2 getCoordFromCameraSpace(in vec3 position) {
    vec4 viewSpacePosition = gbufferProjection * vec4(position, 1);
    vec2 ndcSpacePosition = viewSpacePosition.xy / viewSpacePosition.w;
    return ndcSpacePosition * 0.5 + 0.5;
}

vec3 getColor(in vec2 coord) {
    return texture2DLod(colortex0, coord, 0).rgb;
}

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

//Determines the UV coordinate where the ray hits
//If the returned value is not in the range [0, 1] then nothing was hit.
//NOTHING!
//Note that origin and direction are assumed to be in screen-space coordinates, such that
//  -origin.st is the texture coordinate of the ray's origin
//  -direction.st is of such a length that it moves the equivalent of one texel
//  -both origin.z and direction.z correspond to values raw from the depth buffer
vec3 castRay(in vec3 origin, in vec3 rayStep, in float maxDist) {
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

vec4 computeRaytracedLight(in vec3 viewSpacePos, in vec3 normal) {
    //Find where the ray hits
    //get the blur at that point
    //mix with the color
    vec3 rayStart = viewSpacePos.xyz;
    vec2 noiseCoord = vec2(texcoord.s * viewWidth / 64.0, texcoord.t * viewHeight / 64.0);
    vec3 retColor = vec3(0);
    vec3 noiseSample = vec3(0);
    vec3 reflectDir = vec3(0);
    vec3 hitUV = vec3(0);
    float numHitRays = 0;

    //trace the number of rays defined previously
    for(int i = 0; i < NUM_RAYS; i++) {
        noiseSample = vec3(
            rand(noiseCoord * (i + 1)),
            rand(noiseCoord * (i + 5)),
            rand(noiseCoord * (i + 32))
            ) * 2.0 - 1.0;

        reflectDir = normalize(noiseSample * 0.5 + normal);
        reflectDir *= sign(dot(normal, reflectDir));

        hitUV = castRay(rayStart, reflectDir, MAX_RAY_LENGTH);
        if(hitUV.s > 0.0 && hitUV.s < 1.0 && hitUV.t > 0.0 && hitUV.t < 1.0) {
            float matId = GetMaterialIDs(hitUV.st);
            float emissive = GetMaterialMask(hitUV.st, 10, matId) +    // glowstone
                             GetMaterialMask(hitUV.st, 31, matId) +    // lava
                             GetMaterialMask(hitUV.st, 33, matId);     // fire
            emissive = clamp(emissive, 0.0, 1.0);

            retColor += getColor(hitUV.st) / (hitUV.z * hitUV.z) * emissive;
            numHitRays++;
        }
    }

    return vec4(retColor, numHitRays) / float(NUM_RAYS);
}

void main() {
    vec3 normal = GetNormals(texcoord);
    gl_FragData[0] = computeRaytracedLight(getCameraSpacePosition(texcoord), normal);
}
