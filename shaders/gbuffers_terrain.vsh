#version 120

attribute vec4 mc_Entity;

varying vec4 color;
varying vec2 uv;
varying vec2 uvLight;

varying vec3 normal;
varying mat3 tbnMatrix;
varying vec3 view_vector;

varying float is_leaf;
varying float is_lava;

void main() {
    color = gl_Color;
    uv = gl_MultiTexCoord0.st;// + vec2( 0.005, 0 );
    uvLight = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;

    gl_Position = ftransform();

    normal = normalize(gl_NormalMatrix * gl_Normal);

    is_leaf = 0;
    if(mc_Entity.x == 18) {
        is_leaf = 1.0;
    }

    is_lava = 0;
    if(mc_Entity.x == 10 || mc_Entity.x == 11) {
        is_lava = 1.0;
    }

    vec3 tangent = vec3( 0 );
    vec3 binormal = vec3( 0 );
    //We're working in a cube world. If one component of the normal is
    //greater than all the others, we know what direction the surface is
    //facing in
    if(gl_Normal.x > 0.5) {
        tangent = vec3(0, -1, 0);
    } else if(gl_Normal.x < -0.5) {
        tangent = vec3(0, 1, 0);
    } else if(gl_Normal.y > 0.5 ) {
        tangent = vec3(-1, 0, 0);
    } else if(gl_Normal.y < -0.5) {
        tangent = vec3(1, 0, 0);
    } else if(gl_Normal.z > 0.5) {
        tangent = vec3(1, 0, 0);
    } else if(gl_Normal.z < -0.5) {
        tangent = vec3(1, 0, 0);
    }

    binormal = cross(gl_Normal, tangent);

    tangent = normalize(gl_NormalMatrix * tangent);
    binormal = normalize(gl_NormalMatrix * binormal);

    tbnMatrix = mat3( tangent,
                      binormal,
                      normal );

    // Calculate the view vector for POM
    view_vector = normalize(tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz);
}
