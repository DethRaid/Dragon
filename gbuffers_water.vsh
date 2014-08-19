#version 120

uniform int worldTime;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 normal;

vec3 getGerstnerDisplacement( in vec3 pos ) {
    float waveTime = float( worldTime ) / 10;
    float sharpness = 0.2;
    float amplitude = 0.05;
    vec2 direction = vec2( 10, 0 );
    float w = 10;

    float qi = sharpness / (amplitude * w * 2);
    float qia = qi * amplitude;
    vec2 wd = w * direction;
    float dwd = dot( wd, pos.xz );

    vec3 displacement = pos;
    displacement.x += qia * direction.x * cos( dwd + waveTime );
    displacement.z += qia * direction.y * cos( dwd + waveTime );
    displacement.y -= amplitude * sin( dwd + waveTime ); 

    /*amplitude = 0.025;
    direction = vec2( 9, 1 );
    w = 5;

    qi = sharpness / (amplitude * w * 2);
    qia = qi * amplitude;
    wd = w * direction;
    dwd = dot( wd, pos.xz );

    displacement.x += qia * direction.x * cos( dwd + waveTime );
    displacement.z += qia * direction.y * cos( dwd + waveTime );
    displacement.y -= amplitude * sin( dwd + waveTime );*/

    return displacement;
}

vec3 getGerstnerNormal( in vec3 pos ) {
    float waveTime = float( worldTime ) / 10;
    float sharpness = 0.2;
    float amplitude = 0.05;
    vec2 direction = vec2( 10, 0 );
    float w = 10;

    float qi = sharpness / (amplitude * w * 2);
    float wa = w * amplitude;
    float s = sin( dot( w * direction, pos.xz ) + waveTime );
    float c = cos( dot( w * direction, pos.xz ) + waveTime );
    
    vec3 normalOut;
    normalOut.x = -(direction.x * wa * c);
    normalOut.y = -(direction.y * wa * c);
    normalOut.z = 1 - (qi * wa * s);
    
    return normalOut;
}

void main() {
    color = gl_Color;

    uv = gl_MultiTexCoord0.st;
    uvLight = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;

    vec3 viewPos = (gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex).xyz;
   
    vec3 gerstnerPos = getGerstnerDisplacement( viewPos );

    gl_Position = gl_ProjectionMatrix * (gbufferModelView * vec4( gerstnerPos, 1 ));
    
    normal = getGerstnerNormal( viewPos );
}
