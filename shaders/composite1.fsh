#version 130
#extension GL_ARB_shader_texture_lod : enable

//Adjustable variables. Tune these for performance
#define MAX_RAY_LENGTH          50.0
#define MAX_DEPTH_DIFFERENCE    0.1 //How much of a step between the hit pixel and anything else is allowed?
#define RAY_STEP_LENGTH         0.35
#define MAX_REFLECTIVITY        1.0 //As this value approaches 1, so do all reflections
#define RAY_DEPTH_BIAS          0.05   //Serves the same purpose as a shadow bias
#define RAY_GROWTH              1.0    //Make this number smaller to get more accurate reflections at the cost of performance
                                        //numbers less than 1 are not recommended as they will cause ray steps to grow
                                        //shorter and shorter until you're barely making any progress
#define NUM_RAYS                2   //The best setting in the whole shader pack. If you increase this value,
                                    //more and more rays will be sent per pixel, resulting in better and better
                                    //reflections. If you computer can handle 4 (or even 16!) I highly recommend it.

const bool gdepthMipmapEnabled      = true;
const bool compositeMipmapEnabled   = true;

uniform sampler2D gcolor;
uniform sampler2D gdepthtex;
uniform sampler2D gdepth;
uniform sampler2D gaux2;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux3;

uniform sampler2D noisetex;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;

uniform vec3 skyColor;

in vec2 coord;

struct Pixel1 {
    vec3 position;
    vec3 color;
    vec3 normal;
    bool skipLighting;
    float metalness;
    float smoothness;
    float water;
};

float rayLen;

///////////////////////////////////////////////////////////////////////////////
//                              Helper Functions                             //
///////////////////////////////////////////////////////////////////////////////

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

vec3 getColor() {
    return texture2D(composite, coord).rgb;
}

bool shouldSkipLighting() {
    return texture2D(gaux2, coord).r > 0.5;
}

float getSmoothness() {
    return pow(texture2D(gaux2, coord).a, 2.2);
}

vec3 getNormal() {
    vec3 normal = texture2D(gnormal, coord).xyz * 2.0 - 1.0;
    return normal;
}

float getMetalness() {
    return texture2D(gaux2, coord).b;
}

float getWater() {
    return texture2D(gnormal, coord).a;
}

///////////////////////////////////////////////////////////////////////////////
//                              Main Functions                               //
///////////////////////////////////////////////////////////////////////////////

void fillPixelStruct(inout Pixel1 pixel) {
    pixel.position =        getCameraSpacePosition(coord);
    pixel.normal =          getNormal();
    pixel.color =           getColor();
    pixel.metalness =       getMetalness();
    pixel.smoothness =      getSmoothness();
    pixel.skipLighting =    shouldSkipLighting();
    pixel.water =           getWater();
}

//Determines the UV coordinate where the ray hits
//If the returned value is not in the range [0, 1] then nothing was hit.
//NOTHING!
//Note that origin and direction are assumed to be in screen-space coordinates, such that
//  -origin.st is the texture coordinate of the ray's origin
//  -direction.st is of such a length that it moves the equivalent of one texel
//  -both origin.z and direction.z correspond to values raw from the depth buffer
vec2 castRay(in vec3 origin, in vec3 direction, in float maxDist) {
    vec3 curPos = origin;
    vec2 curCoord = getCoordFromCameraSpace(curPos);
    direction = normalize(direction) * RAY_STEP_LENGTH;
    bool forward = true;

    //The basic idea here is the the ray goes forward until it's behind something,
    //then slowly moves forward until it's in front of something.
    for(int i = 0; i < MAX_RAY_LENGTH * (1 / RAY_STEP_LENGTH); i++) {
        curPos += direction;
        curCoord = getCoordFromCameraSpace(curPos);
        if(curCoord.x < 0 || curCoord.x > 1 || curCoord.y < 0 || curCoord.y > 1) {
            //If we're here, the ray has gone off-screen so we can't reflect anything
            return vec2(-1);
        }
        if(length(curPos - origin) > MAX_RAY_LENGTH) {
            return vec2(-1);
        }
        float worldDepth = getCameraSpacePosition(curCoord).z;
        float rayDepth = curPos.z;
        float depthDiff = (worldDepth - rayDepth);
        float maxDepthDiff = length(direction) + RAY_DEPTH_BIAS;
        if(forward) {
            if(depthDiff > 0 && depthDiff < maxDepthDiff) {
                //return curCoord;
                direction = -1 * normalize(direction) * 0.15;
                forward = false;
            }
        } else {
            depthDiff *= -1;
            if(depthDiff > 0 && depthDiff < maxDepthDiff) {
                return curCoord;
            }
        }
        direction *= RAY_GROWTH;
    }
    //If we're here, we couldn't find anything to reflect within the alloted number of steps
    return vec2(-1);
}

vec3 doLightBounce(in Pixel1 pixel) {
    //Find where the ray hits
    //get the blur at that point
    //mix with the color
    vec3 rayStart = pixel.position;
    vec2 noiseCoord = vec2(coord.s * viewWidth / 64.0, coord.t * viewHeight / 64.0);
    vec3 retColor = vec3(0);
    vec3 noiseSample = vec3(0);
    vec3 reflectDir = vec3(0);
    vec3 rayDir = vec3(0);
    vec2 hitUV = vec2(0);

    //trace the number of rays defined previously
    for(int i = 0; i < NUM_RAYS; i++) {
        noiseSample = texture2DLod(noisetex, noiseCoord * (i + 1), 0).rgb * 2.0 - 1.0;
        reflectDir = normalize(noiseSample * (1.0 - pixel.smoothness) * 0.5 + pixel.normal);
        reflectDir *= sign(dot(pixel.normal, reflectDir));
        rayDir = reflect(normalize(rayStart), reflectDir);

        hitUV = castRay(rayStart, rayDir, MAX_RAY_LENGTH);
        if(hitUV.s > -0.1 && hitUV.s < 1.1 && hitUV.t > -0.1 && hitUV.t < 1.1) {
            retColor += texture2DLod(composite, hitUV.st, 0).rgb;
        } else {
            retColor += skyColor * pixel.water + pixel.color * (1.0 - pixel.water);
        }
    }

    return retColor / NUM_RAYS;
}

float luma(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

void main() {
    Pixel1 pixel;
    fillPixelStruct(pixel);
    vec3 hitColor = pixel.color;
    vec3 reflectedColor = vec3(0);
#if NUM_RAYS > 0
    if(!pixel.skipLighting) {
        hitColor = doLightBounce(pixel);

        vec3 viewVector = normalize(getCameraSpacePosition(coord));

        float vdoth = clamp(dot(-viewVector, pixel.normal), 0, 1);

        float smoothness = pixel.smoothness;
        float metalness = pixel.metalness;
        float waterness = pixel.water;

        reflectedColor = doLightBounce(pixel).rgb;

        //smoothness = pow(smoothness, 4);
        vec3 sColor = (pixel.color * metalness + vec3(0.14) * (1.0 - metalness)) * (1.1 - waterness);
        vec3 fresnel = sColor + (vec3(1.0) - sColor) * pow(1.0 - vdoth, 5);

        hitColor = (vec3(1.0) - fresnel) * pixel.color * (1.0 - metalness) + reflectedColor * fresnel * smoothness;
    }
#endif

    vec4 vlColor = texture2DLod(gdepth, coord, 3);
    hitColor = mix(hitColor, vlColor.rgb, vlColor.a);// + (rainStrength * 0.5));

    hitColor = pow(hitColor, vec3(1.0 / 2.2));

    gl_FragData[0] = texture2D(gcolor, coord);
    gl_FragData[1] = texture2D(gdepth, coord);
    gl_FragData[2] = texture2D(gnormal, coord);
    gl_FragData[3] = texture2D(composite, coord);

    gl_FragData[4] = vec4(hitColor, 1);

    gl_FragData[5] = texture2D(gaux2, coord);
    gl_FragData[6] = vec4(reflectedColor, 1.0);
}
