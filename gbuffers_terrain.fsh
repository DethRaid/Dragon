#version 120

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D lightmap;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 normal;
varying mat3 tbnMatrix;

varying float smoothness_in;
varying float reflectivity_in;

void main() {
    //color
    gl_FragData[0] = texture2D( texture, uv ) * color;

    //determine material reflectivity and smoothness
    float smoothness = smoothness_in;
    float reflectivity = max( reflectivity_in, texture2D( specular, uv ).r ); 

    //skipLighting, torch lighting, isWater, smoothness
    gl_FragData[5] = vec4( 0, texture2D( lightmap, uvLight ).r, 0, smoothness );

    vec3 texnormal = texture2D( normals, uv ).xyz;
    texnormal = tbnMatrix * texnormal;
    //normal, reflectivity
    gl_FragData[2] = vec4( normal * 0.5 + 0.5, reflectivity );
}
