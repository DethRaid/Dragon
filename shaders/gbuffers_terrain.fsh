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

varying float isEmissive;

float luma( in vec3 color ) {
    return dot( color, vec3( 0.2126, 0.7152, 0.0722 ) );
}

void main() {
    //color
    vec4 texColor = texture2D( texture, uv ) * color;
    //decrease contrast
    texColor.rgb = mix( vec3( 0.5 ), texColor.rgb, 0.95 );

    //get data from specular texture
    vec4 sData = texture2D( specular, uv );
    float smoothness = sData.g;
    float emission = min(sData.a + isEmissive, 1.0);
    float metalness = sData.r;

    float lumac = min( luma( texColor.rgb ), 1.0 );
    texColor += texColor * (1.0 - lumac) * 0.5;
    texColor /= 1.1;

    gl_FragData[0] = texColor;

    //skipLighting, torch lighting, metlness, smoothness
    gl_FragData[5] = vec4( emission, uvLight.r, metalness, smoothness );

    //sky lighting, 0, 0, 1
    gl_FragData[1] = vec4( uvLight.g, 0, 0, 1 );

    vec3 texnormal = texture2D( normals, uv ).xyz * 2.0 - 1.0;
    texnormal = tbnMatrix * texnormal;
    //normal, junk
    gl_FragData[2] = vec4( texnormal * 0.5 + 0.5, 0.0 );
}
