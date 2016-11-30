#version 120
#extension GL_ARB_shader_texture_lod : enable

//Adjustable variables. Tune these for performance
#define MAX_RAY_STEPS           30
#define RAY_STEP_LENGTH         0.1
#define RAY_DEPTH_BIAS          0.05
#define RAY_GROWTH              1.05
#define NUM_RAYS                8  // [1 2 4 8 16 32]
#define NUM_BOUNCES             2

//#define DITHER_REFLECTION_RAYS

#define SCHLICK 0
#define COOK_TORRANCE 1

#define FRESNEL_EQUATION COOK_TOORANCE

#define BECKMANN 1
#define GGX 2

#define SKEWING_FUNCTION GGX

#define PI 3.14159

// TODO: Change back to 1
/* DRAWBUFFERS:1 */

uniform sampler2D gcolor;
uniform sampler2D gdepthtex;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;

uniform sampler2D noisetex;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform vec3 upPosition;
uniform vec3 sunVector;

varying vec3 lightVector;

varying vec2 coord;

struct Pixel1 {
    vec3 position;
    vec3 color;
    vec3 normal;
    vec3 specular_color;
    bool skipLighting;
    bool is_sky;
    float metalness;
    float smoothness;
};

struct HitInfo {
    vec3 position;
    vec2 coord;
};

///////////////////////////////////////////////////////////////////////////////
//                              Helper Functions                             //
///////////////////////////////////////////////////////////////////////////////

vec3 get_viewspace_position(in vec2 uv) {
    float depth = texture2D(gdepthtex, uv).x;
    vec4 position = gbufferProjectionInverse * vec4(uv.s * 2.0 - 1.0, uv.t * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    return position.xyz / position.w;
}

vec2 get_coord_from_viewspace(in vec4 position) {
    vec4 ndc_position = gbufferProjection * position;
    ndc_position /= ndc_position.w;
    return ndc_position.xy * 0.5 + 0.5;
}

vec4 viewspace_to_worldspace(in vec4 position_viewspace) {
	vec4 pos = gbufferModelViewInverse * position_viewspace;
	return pos;
}

vec3 get_specular_color() {
    return texture2D(gcolor, coord).rgb;
}

vec3 get_color(in vec2 coord) {
    return texture2D(gcolor, coord).rgb;
}

vec3 getColor() {
    return texture2D(gcolor, coord).rgb;
}

bool shouldSkipLighting() {
    return texture2D(gaux2, coord).r > 0.5;
}

bool is_sky() {
    return texture2D(gaux3, coord).g > 0.5;
}

float getSmoothness() {
    return pow(texture2D(gaux2, coord).a, 2.2);
}

vec3 get_normal(in vec2 coord) {
    return texture2D(gaux4, coord).xyz * 2.0 - 1.0;
}

vec3 getNormal() {
    vec3 normal = texture2D(gaux4, coord).xyz * 2.0 - 1.0;
    return normal;
}

float getMetalness() {
    return texture2D(gaux2, coord).b;
}

float getSkyLighting() {
    return texture2D(gaux3, coord).r;
}

float get_emission(in vec2 coord) {
    return texture2D(gaux2, coord).r;
}

float luma(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec3 get_sky_color(in vec3 direction) {
    //return 10;

    direction = normalize(viewspace_to_worldspace(vec4(direction, 1)).xyz);

    float lon = atan(direction.z, direction.x);
    if(direction.z < 0) {
        lon = 2 * PI - atan(-direction.z, direction.x);
    }

    float lat = acos(direction.y);

    const vec2 rads = vec2(1.0 / (PI * 2.0), 1.0 / PI);
    vec2 sphereCoords = vec2(lon, lat) * rads;
    sphereCoords.y = 1.0 - sphereCoords.y;

    return texture2DLod(gdepth, sphereCoords, 0).rgb;// * getSkyLighting();
}

///////////////////////////////////////////////////////////////////////////////
//                              Main Functions                               //
///////////////////////////////////////////////////////////////////////////////

void fillPixelStruct(inout Pixel1 pixel) {
    pixel.position          = get_viewspace_position(coord);
    pixel.normal            = getNormal();
    pixel.color             = getColor();
    pixel.metalness         = getMetalness();
    pixel.smoothness        = getSmoothness();
    pixel.skipLighting      = shouldSkipLighting();
    pixel.specular_color    = mix(vec3(0.14), get_specular_color(), vec3(pixel.metalness));
    pixel.is_sky            = is_sky();
}

float calculateDitherPattern() {
    const int[64] ditherPattern = int[64] ( 1, 49, 13, 61,  4, 52, 16, 64,
                                           33, 17, 45, 29, 36, 20, 48, 32,
                                            9, 57,  5, 53, 12, 60,  8, 56,
                                           41, 25, 37, 21, 44, 28, 40, 24,
                                            3, 51, 15, 63,  2, 50, 14, 62,
                                           35, 19, 47, 31, 34, 18, 46, 30,
                                           11, 59,  7, 55, 10, 58,  6, 54,
                                           43, 27, 39, 23, 42, 26, 38, 22);

    vec2 count = vec2(0.0f);
         count.x = floor(mod(coord.s * viewWidth, 8.0f));
         count.y = floor(mod(coord.t * viewHeight, 8.0f));

    int dither = ditherPattern[int(count.x) + int(count.y) * 8];

    return float(dither) / 64.0f;
}

//Determines the UV coordinate where the ray hits
//If the returned value is not in the range [0, 1] then nothing was hit.
//NOTHING!
//Note that origin and direction are assumed to be in screen-space coordinates, such that
//  -origin.st is the texture coordinate of the ray's origin
//  -direction.st is of such a length that it moves the equivalent of one texel
//  -both origin.z and direction.z correspond to values raw from the depth buffer
bool cast_screenspace_ray(in vec3 origin, in vec3 direction, inout HitInfo hit_info) {
    vec3 curPos = origin;
    vec2 curCoord = get_coord_from_viewspace(vec4(curPos, 1));
    direction = normalize(direction) * RAY_STEP_LENGTH;
    #ifdef DITHER_REFLECTION_RAYS
        direction *= mix(0.75, 1.0, calculateDitherPattern());
    #endif
    bool forward = true;
    bool can_collect = true;

    //The basic idea here is the the ray goes forward until it's behind something,
    //then slowly moves forward until it's in front of something.
    for(int i = 0; i < MAX_RAY_STEPS; i++) {
        curPos += direction;
        curCoord = get_coord_from_viewspace(vec4(curPos, 1));
        if(curCoord.x < 0 || curCoord.x > 1 || curCoord.y < 0 || curCoord.y > 1) {
            //If we're here, the ray has gone off-screen so we can't reflect anything
            return false;
        }

        vec3 worldDepth = get_viewspace_position(curCoord);
        float depthDiff = (worldDepth.z - curPos.z);
        float maxDepthDiff = sqrt(dot(direction, direction)) + RAY_DEPTH_BIAS;

        if(depthDiff > 0 && depthDiff < maxDepthDiff) {
            vec3 travelled = origin - curPos;
            hit_info.position = curPos;
            hit_info.coord = curCoord;

            // If we hit an emissive surface, we should stop tracing rays
            return get_emission(curCoord) < 0.5;
        }
        direction *= RAY_GROWTH;
    }
    //If we're here, we couldn't find anything to reflect within the alloted number of steps
    return false;
}

float noise(in vec2 coord) {
    return fract(sin(dot(coord, vec2(12.8989, 78.233))) * 43758.5453);
}

vec3 doLightBounce(in Pixel1 pixel) {
    //Find where the ray hits
    //get the blur at that point
    //mix with the color
    vec3 retColor = vec3(0);
    vec3 hitColor = vec3(0);

    float roughness = 1.0 - pixel.smoothness;
    roughness = pow(roughness * 0.8, 2);

    //trace the number of rays defined previously
    for(int i = 0; i < NUM_RAYS; i++) {
        vec3 ray_color = pixel.color;
        vec3 rayDir = normalize(pixel.position);
        HitInfo hit_info;
        hit_info.position = pixel.position;
        hit_info.coord = coord;

        for(int b = 0; b < NUM_BOUNCES; b++) {
            vec3 sample_normal = get_normal(hit_info.coord);

            vec2 noise_seed = coord * (i + 1) + (b + 1);
            vec3 noiseSample = vec3(noise(noise_seed * 4), noise(noise_seed * 3), noise(noise_seed * 23)) * 2.0 - 1.0;
            vec3 reflectDir = normalize(noiseSample + sample_normal);
            reflectDir *= sign(dot(sample_normal, reflectDir));
            rayDir = reflectDir;

            if(dot(rayDir, sample_normal) < 0.1) {
                rayDir += sample_normal;
                rayDir = normalize(rayDir);
            }

            if(!cast_screenspace_ray(hit_info.position, rayDir, hit_info)) {
                if(get_emission(hit_info.coord) > 0.5) {
                    ray_color *= get_color(hit_info.coord) * 3000;
                } else {
                    ray_color *= luma(get_sky_color(rayDir));
                }
                break;
            }

            vec3 sample_color = get_color(hit_info.coord);
            if(get_emission(hit_info.coord) > 0.5) {
                sample_color *= 250;
            }
            ray_color *= sample_color;
        }

        retColor += ray_color;
    }

    return retColor / NUM_RAYS;
}

void main() {
    Pixel1 pixel;
    fillPixelStruct(pixel);
    vec3 reflectedColor = pixel.color;

    if(!pixel.skipLighting) {
        reflectedColor = doLightBounce(pixel).rgb;
    } else if(pixel.is_sky) {
        reflectedColor = get_sky_color(pixel.position) * 0.5;
    } else {
        reflectedColor *= 1250; // For emissive blocks
    }

    gl_FragData[0] = vec4(reflectedColor, 1);
}
