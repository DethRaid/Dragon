#version 120

#include "/lib/texturepack_reading.glsl"

#line 5

uniform sampler2D lightmap;

uniform mat4 gbufferModelView;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 normal;
varying mat3 tbnMatrix;
varying vec3 view_vector;

varying float is_leaf;
varying float is_emissive;

float luma(in vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

/*!
 * \brief Computes lighting for leaves
 *
 * Following the advice of http://filmicworlds.com/blog/materials-that-need-forward-shading/, I use a specialized BRDF 
 * for leaves
 */
vec3 leaf_brdf() {
    return vec3(0);
}

void main() {
    vec2 coord = uv;

    texture_data data = get_texture_data(coord);

    data.color *= color;
    float lumac = min(luma(data.color.rgb), 1.0);
    data.color += data.color * (1.0 - lumac) * 0.5;
    data.color /= 1.1;

    gl_FragData[0] = data.color;

    data.normal = normalize(tbnMatrix * data.normal);

    //skipLighting, torch lighting, metalness, smoothness
    //float lighting = length(texture2D(lighting. sData.gb).rgb);
    gl_FragData[5] = vec4(max(data.is_emissive, is_emissive), uvLight.r, data.metalness, clamp(data.smoothness, 0.01, 0.95));

    //sky lighting, isSky, is_leaf, isWater
    gl_FragData[6] = vec4(uvLight.g, 0, is_leaf, 0);
    
    //normal, junk
    gl_FragData[7] = vec4(data.normal * 0.5 + 0.5, 0.0);
}
