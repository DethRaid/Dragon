#version 120

#include "/lib/texturepack_reading.glsl"

#line 5

#define OFF             0
#define ON              1

#define POM             OFF
#define TEXTURE_RES     1

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

#if POM == ON
// taken from http://sunandblackcat.com/tipFullView.php?topicid=28
vec2 parallaxMapping(in vec3 V, in vec2 T, out float parallaxHeight) {
   // determine optimal number of layers
   const float minLayers = 10;
   const float maxLayers = 15;
   float numLayers = mix(maxLayers, minLayers, abs(dot(vec3(0, 0, 1), V)));

   // height of each layer
   float layerHeight = 1.0 / numLayers;
   // current depth of the layer
   float curLayerHeight = 0;
   // shift of texture coordinates for each layer
   vec2 dtex = TEXTURE_RES * V.xy / V.z / numLayers;

   // current texture coordinates
   vec2 currentTextureCoords = T;

   // depth from heightmap
   float heightFromTexture = texture2D(normals, currentTextureCoords).a;

   // while point is above the surface
   while(heightFromTexture > curLayerHeight) {
      // to the next layer
      curLayerHeight += layerHeight;
      // shift of texture coordinates
      currentTextureCoords -= dtex;
      // new depth from heightmap
      heightFromTexture = texture2D(normals, currentTextureCoords).a;
   }

   ///////////////////////////////////////////////////////////

   // previous texture coordinates
   vec2 prevTCoords = currentTextureCoords + dtex;

   // heights for linear interpolation
   float nextH	= heightFromTexture - curLayerHeight;
   float prevH	= texture2D(normals, prevTCoords).a - curLayerHeight + layerHeight;

   // proportions for linear interpolation
   float weight = nextH / (nextH - prevH);

   // interpolation of texture coordinates
   vec2 finalTexCoords = prevTCoords * weight + currentTextureCoords * (1.0-weight);

   // interpolation of depth values
   parallaxHeight = curLayerHeight + prevH * weight + nextH * (1.0 - weight);

   // return result
   return finalTexCoords;
}
#endif

void main() {
    vec2 coord = uv;

    #if POM == ON
    float parallax_height;
    coord = parallaxMapping(view_vector, uv, parallax_height);
    #endif

    texture_data data = get_texture_data(coord);

    data.color *= color;
    float lumac = min(luma(data.color.rgb), 1.0);
    data.color += data.color * (1.0 - lumac) * 0.5;
    data.color /= 1.1;

    gl_FragData[0] = data.color;

    //sky lighting, isSky, is_leaf, isWater
    gl_FragData[6] = vec4(uvLight.g, 0, is_leaf, 0);

    data.normal = normalize(tbnMatrix * data.normal);

    //normal, junk
    gl_FragData[7] = vec4(data.normal * 0.5 + 0.5, 0.0);

    //skipLighting, torch lighting, metalness, smoothness
    //float lighting = length(texture2D(lighting. sData.gb).rgb);
    gl_FragData[5] = vec4(data.is_emissive, uvLight.r, data.metalness, clamp(data.smoothness, 0.01, 0.95));
}
