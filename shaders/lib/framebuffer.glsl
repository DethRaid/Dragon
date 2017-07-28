#line 3001

#include "/lib/encoding.glsl"

/*!
 * \brief Holds a bunch of defines to give semantic names to all the framebuffer attachments
 */

uniform sampler2D gcolor;
uniform sampler2D gdepthtex;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;

#define COLOR_SAMPLE(coord, lod)        texture2DLod(gcolor, coord, lod)
#define DEPTH_SAMPLE(coord, lod)        texture2DLod(gdepthtex, coord, lod)
#define NORMAL_SAMPLE(coord, lod)       texture2DLod(gnormal, coord, lod)
#define MATERIAL_SAMPLE(coord, lod)     texture2DLod(gaux2, coord, lod)
#define SKY_PARAMS_SAMPLE(coord, lod)   texture2DLod(gaux3, coord, lod)
#define LIGHT_SAMPLE(coord, lod)        texture2DLod(composite, coord, lod)
#define GI_SAMPLE(coord, lod)           texture2DLod(gaux4, coord, lod)
#define SKY_SAMPLE(coord, lod)          texture2DLod(gdepth, coord, lod)
#define VL_SAMPLE(coord, lod)           texture2DLod(gaux1, coord, lod)

#define COLOR_SAMPLE(coord)             COLOR_SAMPLE(coord, 0)
#define DEPTH_SAMPLE(coord)             DEPTH_SAMPLE(coord, 0)
#define NORMAL_SAMPLE(coord)            NORMAL_SAMPLE(coord, 0)
#define MATERIAL_SAMPLE(coord)          MATERIAL_SAMPLE(coord, 0)
#define SKY_PARAMS_SAMPLE(coord)        SKY_PARAMS_SAMPLE(coord, 0)
#define LIGHT_SAMPLE(coord)             LIGHT_SAMPLE(coord, 0)
#define GI_SAMPLE(coord)                GI_SAMPLE(coord, 0)
#define SKY_SAMPLE(coord)               SKY_SAMPLE(coord, 0)
#define VL_SAMPLE(coord)                VL_SAMPLE(coord, 0)

#define COLOR_OUT                       gl_FragData[0]
#define SKY_OUT                         gl_FragData[1]
#define NORMAL_OUT                      gl_FragData[2]
#define LIGHT_OUT                       gl_FragData[3]
#define VL_OUT                          gl_FragData[4]
#define MATERIAL_OUT                    gl_FragData[5]
#define SKY_PARAMS_OUT                  gl_FragData[6]
#define GI_OUT                          gl_FragData[7]

struct Fragment {
    vec3 albedo;
    vec3 specular_color;
    vec3 normal;
    float roughness;
    float ao;
    float emission;
    bool is_metal;
    bool skip_lighting;
    bool is_sky;
    bool is_water;
}

#define METALLIC_BIT        0
#define SKIP_LIGHTING_BIT   1
#define SKY_BIT             2
#define WATER_BIT           3

void write_to_buffers(vec4 color, vec3 normal, float roughness, float ao, float metalness, float emission, 
    bool skip_lighting, bool is_sky, is_water)  {
    gl_FragData[0] = color; 
    gl_FragData[5].r = Encode16(EncodeNormal(normal)); 
    gl_FragData[5].g = Encode16(roughness, ao); 

    int masks = 0;
    masks |= (metalness > 0.5 ? 1 : 0)  << METALLIC_BIT;
    masks |= skip_lighting ? 1 : 0      << SKIP_LIGHTING_BIT;
    masks |= is_sky ? 1 : 0             << SKY_BIT;
    masks |= is_water ? 1 : 0           << WATER_BIT;
    gl_FragData[5].b = Encode16(vec2(emission, intBitsToFloat(masks & 0xFF)));
}

Fragment get_fragment(vec2 coord) {
    vec3 color_sample = texture2D(colortex0, coord).rgb;
    vec3 data_sample = texture2D(colortex5, coord).rgb;
    vec2 roughness_and_ao = Decode16(data_sample.g);
    vec2 emission_and_masks = Decode16(data_sample.b);
    int masks = floatBitsToInt(emission_and_masks.y);

    Fragment fragment;
    fragment.normal         = DecodeNormal(Decode16(data.x));
    fragment.roughness      = roughness_and_ao.x;
    fragment.ao             = roughness_and_ao.y;
    fragment.emission       = emission_and_masks.x;
    fragment.is_metal       = (masks & (1 << METALLIC_BIT)) > 0;
    fragment.skip_lighting  = (masks & (1 << SKIP_LIGHTING_BIT)) > 0;
    fragment.is_sky         = (masks & (1 << SKY_BIT)) > 0;
    fragment.is_water       = (masks & (1 << WATER_BIT)) > 0;

    if(fragment.is_metal) {
        fragment.albedo = vec3(0.02);
        fragment.specular_color = color_sample;
    } else {
        fragment.albedo = color_sample;
        fragment.specular_color = vec3(0.014);
    }

    return fragment;
}
