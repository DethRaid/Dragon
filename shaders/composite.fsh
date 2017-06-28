#version 120
#extension GL_ARB_shader_texture_lod : enable

/*!
 * \brief Computes GI and the skybox
 */

#define GLOBAL_ILLUMINATION

// GI variables
#define GI_SAMPLE_RADIUS 25
#define GI_QUALITY 2    // [2 4 8 16]

// Sky options
#define RAYLEIGH_BRIGHTNESS         3.3
#define MIE_BRIGHTNESS              0.1
#define MIE_DISTRIBUTION            0.63
#define STEP_COUNT                  15.0
#define SCATTER_STRENGTH            0.028
#define RAYLEIGH_STRENGTH           0.139
#define MIE_STRENGTH                0.0264
#define RAYLEIGH_COLLECTION_POWER	0.81
#define MIE_COLLECTION_POWER        0.39

#define SUNSPOT_BRIGHTNESS          500
#define MOONSPOT_BRIGHTNESS         25

#define SKY_SATURATION              1.5

#define SURFACE_HEIGHT              0.98

#define CLOUDS_START                512

#define PI 3.14159

const int RGB32F                    = 0;
const int RGB16F                    = 1;

const int   shadowMapResolution     = 4096;    // [1024 2048 4096]
const float shadowDistance          = 120.0;
const bool  generateShadowMipmap    = false;
const float shadowIntervalSize      = 4.0;
const bool  shadowHardwareFiltering = false;
const bool  shadowtexNearest        = true;
const float    sunPathRotation         = -40.0f;

const int   noiseTextureResolution  = 256;
const int     gdepthFormat            = RGB32F;
const int    gnormalFormat            = RGB16F;

uniform sampler2D gcolor;
uniform sampler2D gdepthtex;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;

uniform sampler2D shadowtex1;
uniform sampler2D watershadow;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

uniform sampler2D noisetex;

uniform float viewWidth;
uniform float viewHeight;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjectionInverse;

uniform vec3 sunPosition;
uniform vec3 moonPosition;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

varying vec2 coord;
varying vec3 lightVector;
varying vec3 lightColor;
varying vec3 ambientColor;

varying vec3 fogColor;
varying vec3 skyColor;

// TODO: 12
/* DRAWBUFFERS:12 */

vec3 get_normal(in vec2 coord) {
    return texture2DLod(gaux4, coord, 0).xyz * 2.0 - 1.0;
}

float get_depth(in vec2 coord) {
    return texture2D(gdepthtex, coord.st).x;
}

vec4 get_viewspace_position(in vec2 coord) {
    float depth = get_depth(coord);
    vec4 pos = gbufferProjectionInverse * vec4(vec3(coord.st, depth) * 2.0 - 1.0, 1.0);
    return pos / pos.w;
}

vec4 viewspace_to_worldspace(in vec4 position_viewspace) {
    vec4 pos = gbufferModelViewInverse * position_viewspace;
    return pos;
}

vec4 worldspace_to_shadowspace(in vec4 position_worldspace) {
    vec4 pos = shadowProjection * shadowModelView * position_worldspace;
    return pos / pos.w;
}

vec3 calcShadowCoordinate(in vec4 pixelPos) {
    vec4 shadowCoord = viewspace_to_worldspace(pixelPos);
    shadowCoord = worldspace_to_shadowspace(shadowCoord);

    shadowCoord.st = shadowCoord.st * 0.5 + 0.5;    //take it from [-1, 1] to [0, 1]
    float dFrag = shadowCoord.z * 0.5 + 0.505;

    return vec3(shadowCoord.st, dFrag);
}

vec3 get_3d_noise(in vec2 coord) {
    coord *= vec2(viewWidth, viewHeight);
    coord /= noiseTextureResolution;

    return texture2D(noisetex, coord).xyz * 2.0 - 1.0;
}

float get_leaf(in vec2 coord) {
    return texture2D(gaux3, coord).b;
}

/*
 * Global Illumination
 *
 * Calculates bounced diffuse light
 */

vec3 calculate_gi(in vec2 gi_coord, in vec4 position_viewspace, in vec3 normal_viewspace) {
    vec3 blocknormal_shadowspace = mat3(shadowProjection) * (mat3(shadowModelView) * (mat3(gbufferModelViewInverse) * normal_viewspace));

    vec4 blockposition_shadowspace = worldspace_to_shadowspace(viewspace_to_worldspace(position_viewspace));
    blocknormal_shadowspace.z *= -1;

    vec3 shadowmap_coord = calcShadowCoordinate(position_viewspace);
    
    vec3 light = vec3(0.0);
    int samples    = 0;

    float transmission_accum = 0;

    for(int y = -GI_QUALITY; y <= GI_QUALITY; y++) {
        for(int x = -GI_QUALITY; x <= GI_QUALITY; x++) {
            vec2 offset                         = vec2(x, y) * GI_SAMPLE_RADIUS;
            //offset += get_3d_noise(offset).xy * 25;
            offset.x += 1.0;
            offset /= 2 * shadowMapResolution;

            vec2 shadow_sample_coord = shadowmap_coord.xy + offset;

            float shadow_depth                  = texture2DLod(shadowtex1, shadow_sample_coord, 0).x;

            vec4 sample_pos                     = vec4(vec3(shadow_sample_coord, shadow_depth) * 2.0 - 1.0, 1.0);

            vec3 sample_dir                     = normalize(blockposition_shadowspace.xyz - sample_pos.xyz);
            vec3 shadownormal_shadowspace       = texture2DLod(shadowcolor1, shadow_sample_coord, 0).xyz * 2.0 - 1.0;

            vec3 light_strength                 = vec3(clamp(dot(shadownormal_shadowspace, vec3(0, 0, 1)), 0, 1));
            float transmitted_light_strength	= clamp(dot(shadownormal_shadowspace, -sample_dir), 0.0, 1.0);
            float received_light_strength       = clamp(dot(blocknormal_shadowspace, sample_dir), 0.0, 1.0);

            float falloff                       = length(blockposition_shadowspace.xyz - sample_pos.xyz);
            falloff                             = pow(falloff, 4);
            falloff                             = max(1.0, falloff);

            vec3 sample_color                   = texture2D(shadowcolor0, shadow_sample_coord).rgb;
            vec3 flux = sample_color * light_strength;

            light += flux * transmitted_light_strength * received_light_strength / falloff;
            //light += sample_color;
        }
    }

    light /= pow(GI_QUALITY * 2 + 1, 2.0);

    return light;
}


/*
 * Begin sky rendering code
 *
 * Taken from http://codeflow.org/entries/2011/apr/13/advanced-webgl-part-2-sky-rendering/
 */

float phase(float alpha, float g) {
    float a = 3.0 * (1.0 - g * g);
    float b = 2.0 * (2.0 + g * g);
    float c = 1.0 + alpha * alpha;
    float d = pow(1.0 + g * g - 2.0 * g * alpha, 1.5);
    return (a / b) * (c / d);
}

vec3 get_eye_vector(in vec2 coord) {
    const vec2 coord_to_long_lat = vec2(2.0 * PI, PI);
    coord.y -= 0.5;
    vec2 long_lat = coord * coord_to_long_lat;
    float longitude = long_lat.x;
    float latitude = long_lat.y - (2.0 * PI);

    float cos_lat = cos(latitude);
    float cos_long = cos(longitude);
    float sin_lat = sin(latitude);
    float sin_long = sin(longitude);

    return normalize(vec3(cos_lat * cos_long, cos_lat * sin_long, sin_lat));
}

float atmospheric_depth(vec3 position, vec3 dir) {
    float a = dot(dir, dir);
    float b = 2.0 * dot(dir, position);
    float c = dot(position, position) - 1.0;
    float det = b * b - 4.0 * a * c;
    float detSqrt = sqrt(det);
    float q = (-b - detSqrt) / 2.0;
    float t1 = c / q;
    return t1;
}

float horizon_extinction(vec3 position, vec3 dir, float radius) {
    float u = dot(dir, -position);
    if(u < 0.0) {
        return 1.0;
    }

    vec3 near = position + u*dir;

    if(sqrt(dot(near, near)) < radius) {
        return 0.0;

    } else {
        vec3 v2 = normalize(near)*radius - position;
        float diff = acos(dot(normalize(v2), dir));
        return smoothstep(0.0, 1.0, pow(diff * 2.0, 3.0));
    }
}

vec3 Kr = vec3(0.18867780436772762, 0.4978442963618773, 0.6616065586417131);    // Color of nitrogen

vec3 absorb(float dist, vec3 color, float factor) {
    return color - color * pow(Kr, vec3(factor / dist));
}

float rand(vec2 c){
    return fract(sin(dot(c.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

// From https://gist.github.com/patriciogonzalezvivo/670c22f3966e662d2f83
float noise(vec2 p, float freq ){
    float unit = viewWidth/freq;
    vec2 ij = floor(p/unit);
    vec2 xy = mod(p,unit)/unit;
    //xy = 3.*xy*xy-2.*xy*xy*xy;
    xy = .5*(1.-cos(PI*xy));
    float a = rand((ij+vec2(0.,0.)));
    float b = rand((ij+vec2(1.,0.)));
    float c = rand((ij+vec2(0.,1.)));
    float d = rand((ij+vec2(1.,1.)));
    float x1 = mix(a, b, xy.x);
    float x2 = mix(c, d, xy.x);
    return mix(x1, x2, xy.y);
}

float pNoise(vec2 p, int res){
    float persistance = .5;
    float n = 0.;
    float normK = 0.;
    float f = 4.;
    float amp = 1.;
    int iCount = 0;
    for (int i = 0; i<50; i++){
        n+=amp*noise(p, f);
        f*=2.;
        normK+=amp;
        amp*=persistance;
        if (iCount == res) break;
        iCount++;
    }
    float nf = n/normK;
    return nf*nf*nf*nf;
}

/*!
 * \brief Renders the sky to a equirectangular texture, allowing for world-space sky reflections
 *
 * \param coord The UV coordinate to render to
 */
vec3 get_sky_color(in vec3 eye_vector, in vec3 light_vector, in float light_intensity) {
    vec3 light_vector_worldspace = normalize(viewspace_to_worldspace(vec4(light_vector, 0.0)).xyz);

    float alpha = max(dot(eye_vector, light_vector_worldspace), 0.0);

    float rayleigh_factor = phase(alpha, -0.01) * RAYLEIGH_BRIGHTNESS;
    float mie_factor = phase(alpha, MIE_DISTRIBUTION) * MIE_BRIGHTNESS;
    float spot = smoothstep(0.0, 15.0, phase(alpha, 0.9995)) * light_intensity;

    vec3 eye_position = vec3(0.0, SURFACE_HEIGHT, 0.0);
    float eye_depth = atmospheric_depth(eye_position, eye_vector);
    float step_length = eye_depth / STEP_COUNT;

    float eye_extinction = horizon_extinction(eye_position, eye_vector, SURFACE_HEIGHT - 0.15);

    vec3 rayleigh_collected = vec3(0);
    vec3 mie_collected = vec3(0);

    for(int i = 0; i < STEP_COUNT; i++) {
        float sample_distance = step_length * float(i);
        vec3 position = eye_position + eye_vector * sample_distance;
        float extinction = horizon_extinction(position, light_vector_worldspace, SURFACE_HEIGHT - 0.35);
        float sample_depth = atmospheric_depth(position, light_vector_worldspace);

        vec3 influx = absorb(sample_depth, vec3(light_intensity), SCATTER_STRENGTH) * extinction;

        // rayleigh will make the nice blue band around the bottom of the sky
        rayleigh_collected += absorb(sample_distance, Kr * influx, RAYLEIGH_STRENGTH);
        mie_collected += absorb(sample_distance, influx, MIE_STRENGTH);
    }

    rayleigh_collected = (rayleigh_collected * eye_extinction * pow(eye_depth, RAYLEIGH_COLLECTION_POWER)) / STEP_COUNT;
    mie_collected = (mie_collected * eye_extinction * pow(eye_depth, MIE_COLLECTION_POWER)) / STEP_COUNT;

    vec3 color = (spot * mie_collected) + (mie_factor * mie_collected) + (rayleigh_factor * rayleigh_collected);

    return color * 7;
}

float get_brownian_noise(in vec2 orig_coord) {
    float noise_accum = 0;
    noise_accum += texture2D(noisetex, orig_coord * vec2(3, 1)).b * 0.5;
    noise_accum += texture2D(noisetex, orig_coord * 2).g * 0.25;
    //noise_accum += texture2D(noisetex, orig_coord * 8).g * 0.125;
    //noise_accum += texture2D(noisetex, orig_coord * 16).g * 0.0625;

    return pow(noise_accum, 2);
}

vec3 calc_clouds(in vec3 eye_vector) {
    // Project the eye vector against the cloud plane, then use that position to draw a red/green stiped band

    float num_steps_to_clouds = CLOUDS_START / eye_vector.y;
    vec3 clouds_start_pos = eye_vector * num_steps_to_clouds;
    if(length(clouds_start_pos) > 10000 || num_steps_to_clouds < 0.0f) {
        return vec3(0);
    }

    vec3 color = vec3(get_brownian_noise(clouds_start_pos.xz * 0.00001));

    return color;
}

float luma(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec3 enhance(in vec3 color) {
    color *= vec3(0.85, 0.7, 1.2);

    vec3 intensity = vec3(luma(color));

    return mix(intensity, color, SKY_SATURATION);
}

vec3 calculate_stars(vec2 coord) {
    float noise = max(0, get_3d_noise(coord).x);
    float stars = pow(noise, 100) * 35;
    return vec3(stars);
}

void main() {
    vec3 gi = vec3(0);

    vec2 gi_coord = coord * 2.0;
    if(gi_coord.x < 1 && gi_coord.y < 1) {
    	vec4 position_viewspace = get_viewspace_position(gi_coord);
        vec3 normal_viewspace = get_normal(gi_coord);
        gi = calculate_gi(gi_coord, position_viewspace, normal_viewspace);
    }

    vec3 sky_color = vec3(0);
    vec3 eye_vector = get_eye_vector(coord).xzy;
    sky_color += get_sky_color(eye_vector, normalize(sunPosition), SUNSPOT_BRIGHTNESS);    // scattering from sun
    sky_color += get_sky_color(eye_vector, normalize(moonPosition), MOONSPOT_BRIGHTNESS);        // scattering from moon
    //sky_color += calc_clouds(eye_vector) * SUNSPOT_BRIGHTNESS;
    sky_color += calculate_stars(coord);

    sky_color = enhance(sky_color);

    gl_FragData[0] = vec4(sky_color, 1.0);
    gl_FragData[1] = vec4(gi, 1.0);
}
