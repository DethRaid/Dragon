#line 1001

/*!
 * \brief Contains functions to abstract away reading data from a texturepack
 */

#define CHROMA_HILLS    1
#define PULCHRA         2
#define RIKAI           3
#define R3D             4
#define DRAGON_DATA     5

#define RESOURCE_PACK   RIKAI    // [CHROMA_HILLS PULCHRA RIKAI R3D DRAOGN_DATA]

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

struct texture_data {
    vec4 color;
    vec3 normal;
    float height;
    float metalness;
    float smoothness;
    float ao;
    float is_emissive;
};

texture_data read_chroma_hills_data(vec2 coord) {
    vec4 texture_sample     = texture2D(texture, coord);
    vec4 normal_sample      = texture2D(normals, coord);
    vec4 specular_sample    = texture2D(specular, coord);

    texture_data data;

    data.color          = texture_sample;
    data.normal         = normal_sample.rgb * 2.0 - 1.0;
    data.height         = normal_sample.a;
    data.smoothness     = specular_sample.b;
    data.metalness      = specular_sample.r;
    data.is_emissive    = 0;

    return data;
}

texture_data read_pulchra_data(vec2 coord) {
    vec4 texture_sample     = texture2D(texture, coord);
    vec4 normal_sample      = texture2D(normals, coord);
    vec4 specular_sample    = texture2D(specular, coord);

    texture_data data;

    data.color          = texture_sample;
    data.normal         = normalize(normal_sample.rgb) * 2.0 - 1.0;
    data.height         = normal_sample.a;
    data.smoothness     = specular_sample.b;
    data.metalness      = specular_sample.r;
    data.is_emissive    = 1 - specular_sample.a;
    data.ao             = length(normal_sample.xyz);

    return data;
}

texture_data read_rikai_data(vec2 coord) {
    vec4 texture_sample     = texture2D(texture, coord);
    vec4 normal_sample      = texture2D(normals, coord);
    vec4 specular_sample    = texture2D(specular, coord);

    texture_data data;

    data.color          = texture_sample;
    data.normal         = normal_sample.rgb * 2.0 - 1.0;
    data.height         = normal_sample.a;
    data.smoothness     = 0;
    data.metalness      = 0;
    data.is_emissive    = specular_sample.b;

    return data;
}

texture_data read_r3d_data(vec2 coord) {
    vec4 texture_sample     = texture2D(texture, coord);
    vec4 normal_sample      = texture2D(normals, coord);
    vec4 specular_sample    = texture2D(specular, coord);

    texture_data data;

    data.color          = texture_sample;
    data.normal         = normal_sample.rgb * 2.0 - 1.0;
    data.height         = normal_sample.a;
    data.smoothness     = specular_sample.r;
    data.metalness      = specular_sample.g;
    data.is_emissive    = 0;

    return data;
}

texture_data read_dragon_data(vec2 coord) {
    vec4 texture_sample     = texture2D(texture, coord);
    vec4 normal_sample      = texture2D(normals, coord);
    vec4 specular_sample    = texture2D(specular, coord);

    texture_data data;

    data.color          = texture_sample;
    data.normal         = normal_sample.rgb * 2.0 - 1.0;
    data.height         = normal_sample.a;
    data.smoothness     = specular_sample.r;
    data.is_emissive    = specular_sample.g;
    data.metalness      = specular_sample.b;

    return data;
}

texture_data get_texture_data(vec2 coord) {
    #if RESORUCE_PACK == CHROMA_HILLS
    return read_chroma_hills_data(coord);

    #elif RESOURCE_PACK == PULCHRA
    return read_pulchra_data(coord);

    #elif RESOURCE_PACK == RIKAI
    return read_rikai_data(coord);

    #elif RESOURCE_PACK == R3D
    return read_r3d_data(coord);

    #elif RESORUCE_PACK == DRAOGN_DATA
    return read_dragon_data(coord);

    #endif
}
