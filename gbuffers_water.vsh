#version 120

uniform float frameTimeCounter;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;
varying vec3 pos;

varying vec3 normal;
varying vec3 normal_raw;
varying mat3 normalMatrix;

vec3 getGerstnerDisplacement( in vec3 pos ) {
    float waveTime = frameTimeCounter;
    float sharpness = 0.2;
    float amplitude = 0.05;
    vec2 direction = vec2( 10, 0 );
    float w = 10;

    float qi = sharpness / (amplitude * w);
    float qia = qi * amplitude;
    vec2 wd = w * direction;
    float dwd = dot( wd, pos.xz );

    vec3 displacement = vec3( 0 );
    displacement.x += qia * direction.x * cos( dwd + waveTime );
    displacement.z += qia * direction.y * cos( dwd + waveTime );
    displacement.y -= amplitude * sin( dwd + waveTime ); 

    amplitude = 0.035;
    direction = vec2( 9, 1 );
    w = 5;

    qi = sharpness / (amplitude * w * 2);
    qia = qi * amplitude;
    wd = w * direction;
    dwd = dot( wd, pos.xz );

    displacement.x += qia * direction.x * cos( dwd + waveTime );
    displacement.z += qia * direction.y * cos( dwd + waveTime );
    displacement.y -= amplitude * sin( dwd + waveTime );

    return displacement;
}

vec3 getGerstnerNormal( in vec3 pos ) {
    float waveTime = frameTimeCounter;
    float sharpness = 0.2;
    float amplitude = 0.05;
    vec2 direction = vec2( 10, 0 );
    float w = 10;

    float qi = sharpness / (amplitude * w);
    float wa = w * amplitude;
    float s = sin( dot( w * direction, pos.xz ) + waveTime );
    float c = cos( dot( w * direction, pos.xz ) + waveTime );
    
    vec3 normalOut = vec3( 0 );
    normalOut.x -= direction.x * wa * c;
    normalOut.z -= direction.y * wa * c;
    normalOut.y += qi * wa * s;
    
    amplitude = 0.035;
    direction = vec2( 9, 1 );
    w = 5;

    qi = sharpness / (amplitude * w);
    wa = w * amplitude;
    s = sin( dot( w * direction, pos.xz ) + waveTime );
    c = cos( dot( w * direction, pos.xz ) + waveTime );
    
    normalOut.x -= direction.x * wa * c;
    normalOut.z -= direction.y * wa * c;
    normalOut.y += qi * wa * s;

    normalOut.xz *= 0.05;
    normalOut.y = 1.0 - normalOut.y;
    
    return normalize( normalOut );
}

void main() {
    color = gl_Color;

    uv = gl_MultiTexCoord0.st;
    uvLight = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
  
    //Water position determination comes from chocapic13's shaderpack, available from
    //http://www.minecraftforum.net/forums/mapping-and-modding/minecraft-mods/1293898-chocapic13s-shaders
    vec4 position = gl_ModelViewMatrix * gl_Vertex;
    vec4 viewPos = gbufferModelViewInverse * position;
    vec3 worldPos = viewPos.xyz + cameraPosition;
    pos = worldPos;

    //vec3 gerstnerDisp = getGerstnerDisplacement( worldPos.xyz );

    //gl_Position = gl_ProjectionMatrix * (gbufferModelView * (viewPos + vec4( gerstnerDisp, 0 )));
    gl_Position = ftransform();

    //vec3 gerstNormal = getGerstnerNormal( worldPos.xyz );// * 2.0 - 1.0;
    
    //normal = gl_NormalMatrix * gerstNormal;
   
    normal = gl_NormalMatrix * gl_Normal;
    normal_raw = gl_Normal;
    normalMatrix = gl_NormalMatrix;
}
