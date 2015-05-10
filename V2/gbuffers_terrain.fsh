#version 120

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

varting vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 normal;
varying mat3 tbnMatrix;

varying float depth;
varying float matID;

void main() {
    // Mostly, grab the data from the textures and write it to the gbuffers
    
    // specular data
    vec3 sData = texture2D( specaular, uv ).rgb;
    float smoothness = sData.r;
    float emission = sData.g;
    float metalness = sData.b;
    
    // color
    gl_FragColor[0] = texture2D( texture, uv ) * color;
    
    // normal
    vec3 texnormal = texture2D( normals, uv ).xyz * 2.0 - 1.0;
    texnormal = tbnMatrix * texnormal;
    gl_FragData[1] = vec4( texnormal * 0.5 + 0.5, smoothness );
    
    // specular data
    gl_FragData[4] = vec4( emission, metalness, depth, 1.0 );
    
    // Ensure that the other framebuffer attachments have real data
    
    gl_FragColor[5] = vec4( 0.0 );
}