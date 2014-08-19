#version 120

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 normal;
varying mat3 tbnMatrix;

void main() {
    color = gl_Color;
    uv = gl_MultiTexCoord0.st;
    uvLight = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;

    gl_Position = ftransform();

    normal = normalize( gl_NormalMatrix * gl_Normal );

    vec3 tangent = vec3( 0 );
    vec3 binormal = vec3( 0 );
    //We're working in a cube world. If one component of the normal is
    //greater than all the others, we know what direction the surface is
    //facing in
    if( gl_Normal.x > 0.5 ) {
        tangent  = normalize( gl_NormalMatrix * vec3( 0,  0, 1 ) );
        binormal = normalize( gl_NormalMatrix * vec3( 0, -1, 0 ) );
    } else if( gl_Normal.x < -0.5 ) {
        tangent  = normalize( gl_NormalMatrix * vec3( 0,  0, 1 ) );
        binormal = normalize( gl_NormalMatrix * vec3( 0, -1, 0 ) );
    } else if( gl_Normal.y > 0.5 ) {
        tangent  = normalize( gl_NormalMatrix * vec3( 1,  0, 0 ) );
        binormal = normalize( gl_NormalMatrix * vec3( 0,  0, 1 ) );
    } else if( gl_Normal.y < -0.5 ) {
        tangent  = normalize( gl_NormalMatrix * vec3( 1,  0, 0 ) );
        binormal = normalize( gl_NormalMatrix * vec3( 0,  0, 1 ) );
    } else if( gl_Normal.z > 0.5 ) {
        tangent  = normalize( gl_NormalMatrix * vec3( 1,  0, 0 ) );
        binormal = normalize( gl_NormalMatrix * vec3( 0, -1, 0 ) );
    } else if( gl_Normal.z < -0.5 ) {
        tangent  = normalize( gl_NormalMatrix * vec3( 1,  0, 0 ) );
        binormal = normalize( gl_NormalMatrix * vec3( 0, -1, 0 ) );
    }

    tbnMatrix = mat3( tangent.x, binormal.x, normal.x,
                      tangent.y, binormal.y, normal.y,
                      tangent.z, binormal.z, normal.z );
}
