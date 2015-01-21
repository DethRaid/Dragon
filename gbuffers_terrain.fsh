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

varying float depth;
varying float matID;

float luma( in vec3 color ) {
    return dot( color, vec3( 0.2126, 0.7152, 0.0722 ) );
}

void main() {
    //color
    vec4 texColor = texture2D( texture, uv ) * color;

    //get data from specular texture
    vec3 sData = texture2D( specular, uv ).rgb;
    float smoothness = sData.r;
    float emission = sData.g;
    float metalness = sData.b;
    
    // color
    gl_FragData[0] = texColor;

    vec3 texnormal = texture2D( normals, uv ).xyz * 2.0 - 1.0; 
    texnormal = tbnMatrix * texnormal;
    //normal
    gl_FragData[1] = vec4( texnormal * 0.5 + 0.5, gl_FragCoord.z );
    
    // R0, smoothness, metalness, 1.0
    gl_FragData[4] = vec4( 0.5, smoothness, metalness, 1.0 );
    
    // torch light, ambient light, emission, 1.0
    gl_FragData[5] = vec4( uvLight.r, uvLight.g, emission, 1.0 );
    
    // water depth
    gl_FragData[6] = vec4( 0.0, 0.0, 0.0, 1.0 );
}
