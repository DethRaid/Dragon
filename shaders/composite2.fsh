#version 120
#extension GL_ARB_shader_texture_lod : enable


//Adjustable variables. Tune these for performance
#define REFLECTION_QUALITY      16 // [10 16 32 64]
#define NUM_RAYS                4  // [4 8 16 64 256 1024]

//#define DITHER_REFLECTION_RAYS

#define SCHLICK 0
#define COOK_TORRANCE 1

#define FRESNEL_EQUATION COOK_TOORANCE

#define BECKMANN 1
#define GGX 2

#define SKEWING_FUNCTION BECKMANN

#define PI 3.14159

const bool gdepthMipmapEnabled      = true;
const bool compositeMipmapEnabled   = true;

// TODO: Change back to 1
/* DRAWBUFFERS:1 */

uniform sampler2D gcolor;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex0;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;

uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor;
uniform sampler2D shadowcolor1;

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

varying vec3 lightVector;

varying vec2 coord;

#include "/lib/raytracer.glsl"

#line 71

struct Pixel1 {
    vec3 position;
    vec3 color;
    vec3 normal;
    vec3 specular_color;
    bool skipLighting;
    float metalness;
    float smoothness;
};

float rayLen;

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
    vec3 normal = texture2D(gaux4, coord).xyz * 2.0 - 1.0;
    return normal;
}

float getMetalness() {
    return texture2D(gaux2, coord).b;
}

float getSkyLighting() {
    return texture2D(gaux3, coord).r;
}

vec3 get_sky_color(in vec3 direction, in float smoothness) {
    float lon = atan(direction.z, direction.x);
    if(direction.z < 0) {
        lon = 2 * PI - atan(-direction.z, direction.x);
    }

    float lat = acos(direction.y); // Remove divide if a_coords is normalized

    const vec2 rads = vec2(1.0 / (PI * 2.0), 1.0 / PI);
    vec2 sphereCoords = vec2(lon, lat) * rads;
    sphereCoords.y = 1.0 - sphereCoords.y;

    float lod = (1.0 - smoothness) * 6;

    return texture2DLod(gdepth, sphereCoords, lod).rgb * getSkyLighting();
}

vec3 get_shadow(in vec2 coord) {
    return texture2D(gnormal, coord).rgb;
}

///////////////////////////////////////////////////////////////////////////////
//                              Main Functions                               //
///////////////////////////////////////////////////////////////////////////////

void fillPixelStruct(inout Pixel1 pixel) {
    pixel.position =        get_viewspace_position(coord);
    pixel.normal =          getNormal();
    pixel.color =           getColor();
    pixel.metalness =       getMetalness();
    pixel.smoothness =      getSmoothness();
    pixel.skipLighting =    shouldSkipLighting();
    pixel.specular_color    = mix(vec3(0.14), get_specular_color(), vec3(pixel.metalness));
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

vec3 get_reflected_sky(in Pixel1 pixel) {
    vec3 reflect_dir = reflect(normalize(pixel.position), pixel.normal);
    reflect_dir = viewspace_to_worldspace(vec4(reflect_dir, 0)).xyz;
    vec3 sky_sample = get_sky_color(reflect_dir, pixel.smoothness);

    vec3 light_vector_worldspace = viewspace_to_worldspace(vec4(lightVector, 0)).xyz;
    float facing_sun_fact = max(dot(reflect_dir, light_vector_worldspace), 0);

    vec3 shadow = get_shadow(coord);

    sky_sample *= mix(vec3(1), shadow, facing_sun_fact);

    return sky_sample;
}

vec3 calculate_noise_direction(in vec2 epsilon, in float roughness) {
    // Uses the GGX sample skewing Functions
    #if SKEWING_FUNCTION == GGX
    float theta = atan(sqrt(roughness * roughness * epsilon.x / (1.0 - epsilon.x)));

    #elif SKEWING_FUNCTION == PHONG


    #elif SKEWING_FUNCTION == BECKMANN
    float theta = atan(sqrt(-1 * roughness * log(1.0 - epsilon.x)));

    #endif
    float phi = 2 * PI * epsilon.y;

    float sin_theta = sin(theta);

    float x = cos(phi) * sin_theta;
    float y = sin(phi) * sin_theta;
    float z = cos(theta);

    return vec3(x, y, z);
}

float noise(in vec2 coord) {
    return fract(sin(dot(coord, vec2(12.8989, 78.233))) * 43758.5453);
}

float ggx_smith_geom(in vec3 i, in vec3 normal, in float alpha) {
    float idotn = max(0, dot(normal, i));
    float idotn2 = pow(idotn, 2);

    return 2 * idotn / (idotn + sqrt(idotn2 + pow(alpha, 2) * (1 - idotn2)));
}

float ggx_distribution(in vec3 halfVector, in vec3 normal, in float alpha) {
    float hdotn = max(0, dot(halfVector, normal));

    return alpha / (3.1415927 * pow(1 + pow(hdotn, 2) * (alpha - 1), 2));
}

/*!
 * \brief Calculates the geometry distribution given the given parameters
 *
 * \param lightVector The normalized, view-space vector from the light to the current fragment
 * \param viewVector The normalized, view-space vector from the camera to the current fragment
 * \param halfVector The vector halfway between the normal and view vector
 *
 * \return The geometry distribution of the given fragment
 */
float calculate_geometry_distribution(in vec3 lightVector, in vec3 viewVector, in vec3 halfVector, in float alpha) {
    return ggx_smith_geom(lightVector, halfVector, alpha) * ggx_smith_geom(viewVector, halfVector, alpha);
}

/*!
 * \brief Calculates the nicrofacet distribution for the current fragment
 *
 * \param halfVector The half vector for the current fragment
 * \param normal The viewspace normal of the current fragment
 *
 * \return The microfacet distribution for the current fragment
 */
float calculate_microfacet_distribution(in vec3 halfVector, in vec3 normal, in float alpha) {
    return ggx_distribution(halfVector, normal, alpha);
}

/*!
 * \brief Calculates a specular highlight for a given light
 *
 * \param lightVector The normalized view space vector from the fragment being shaded to the light
 * \param normal The normalized view space normal of the fragment being shaded
 * \param fresnel The fresnel foctor for this fragment
 * \param viewVector The normalized vector from the fragment to the camera being shaded, expressed in view space
 * \param roughness The roughness of the fragment
 *
 * \return The color of the specular highlight at the current fragment
 */
vec3 calculate_specular_highlight(vec3 lightVector, vec3 normal, vec3 fresnel, vec3 viewVector, float roughness) {
    float alpha = roughness * roughness;
    vec3 halfVector = normalize(lightVector + viewVector);

    float geometryFactor = calculate_geometry_distribution(lightVector, viewVector, halfVector, alpha);
    float microfacetDistribution = calculate_microfacet_distribution(halfVector, normal, alpha);

    float ldotn = max(0.01, dot(lightVector, normal));
    float vdotn = max(0.01, dot(viewVector, normal));

    return fresnel * geometryFactor * microfacetDistribution / (4 * ldotn * vdotn);
}

vec3 calculate_fresnel(in vec3 F0, in vec3 normal, in vec3 viewVector) {
    float vdoth = max(0, dot(-viewVector, normal));

    #if FRESNEL_EQUATION == SCHLICK
        return F0 + (vec3(1.0) - F0) * pow(1.0 - vdoth, 5);
    #elif FRESNEL_EQUATION == COOK_TOORANCE
        vec3 cookTorrance; //Phisically Accurate, handles metals better
        vec3 nFactor = (1.0 + sqrt(F0)) / (1.0 - sqrt(F0));
        vec3 gFactor = sqrt(pow(nFactor, vec3(2.0)) + pow(vdoth, 2.0) - 1.0);
        cookTorrance = 0.5 * pow((gFactor - vdoth) / (gFactor + vdoth), vec3(2.0)) * (1 + pow(((gFactor + vdoth) * vdoth - 1.0) / ((gFactor - vdoth) * vdoth + 1.0), vec3(2.0)));

        return cookTorrance;
    #endif

    return F0;
}

vec3 doLightBounce(in Pixel1 pixel) {
    //Find where the ray hits
    //get the blur at that point
    //mix with the color
    vec3 retColor = vec3(0);
    vec3 hitColor = vec3(0);

    float roughness = 1.0 - pixel.smoothness;
    vec3 clipPosition = toClipSpace(pixel.position.xyz);

    //trace the number of rays defined previously
    for(int i = 0; i < NUM_RAYS; i++) {
        vec2 epsilon = vec2(noise(coord * (i + 1)), noise(coord * (i + 1) * 3));
        vec3 noiseSample = calculate_noise_direction(epsilon, roughness);
        vec3 reflectDir = normalize(noiseSample * roughness / 8.0 + pixel.normal);
        reflectDir *= sign(dot(pixel.normal, reflectDir));
        vec3 rayDir = reflect(normalize(pixel.position), reflectDir);

        if(dot(rayDir, pixel.normal) < 0.1) {
            rayDir += pixel.normal;
            rayDir = normalize(rayDir);
        }

        vec3 hitUV = rayTrace(rayDir, pixel.position, clipPosition, REFLECTION_QUALITY);

        if(hitUV.s > -0.1 && hitUV.s < 1.1 && hitUV.t > -0.1 && hitUV.t < 1.1) {
            hitColor = texture2DLod(composite, hitUV.st, 0).rgb;
        } else {
            Pixel1 sky_pixel = pixel;
            sky_pixel.normal = reflectDir;
            hitColor = get_reflected_sky(sky_pixel);
        }

        hitColor = max(hitColor, vec3(0));

        vec3 viewVector = normalize(pixel.position);

        vec3 fresnel = calculate_fresnel(pixel.specular_color, reflectDir, viewVector);
        fresnel = vec3(1);

        vec3 specularStrength = calculate_specular_highlight(rayDir, pixel.normal, fresnel, viewVector, roughness);
        //specularStrength = fresnel;

        retColor += mix(pixel.color, hitColor * specularStrength, fresnel * pixel.smoothness * pixel.smoothness);
    }

    return retColor / NUM_RAYS;
}

void main() {
    Pixel1 pixel;
    fillPixelStruct(pixel);
    vec3 hitColor = pixel.color;
    vec3 reflectedColor = vec3(0);

    float smoothness = pixel.smoothness;
    float metalness = pixel.metalness;

    if(!pixel.skipLighting) {
#if NUM_RAYS > 0
        reflectedColor = doLightBounce(pixel).rgb;
#else
        // Only reflect the sky
        reflectedColor = get_reflected_sky(pixel);
#endif

        hitColor = reflectedColor;
    }

    gl_FragData[0] = vec4(hitColor, 1);
}
