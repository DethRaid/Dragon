#ifndef NORMALMAPPING_GLSL
#define NORMALMAPPING_GLSL

#line 5005

/*!
 * \brief Calculates the TBN matrix from gl_Normal
 */
mat3 calculate_tbn_matrix(in vec3 orig_normal, in mat3 normal_matrix) {
    vec3 tangent = vec3(0);
    vec3 binormal = vec3(0);
    //We're working in a cube world. If one component of the normal is
    //greater than all the others, we know what direction the surface is
    //facing in
    if(orig_normal.x > 0.5) {
        tangent = vec3(0, 0, -1);
        binormal = vec3(0, -1, 0);
    } else if(orig_normal.x < -0.5) {
        tangent = vec3(0, 0, 1);
        binormal = vec3(0, -1, 0);
    } else if(orig_normal.y > 0.5 ) {
        tangent = vec3(1, 0, 0);
        binormal = vec3(0, 0, 1);
    } else if(orig_normal.y < -0.5) {
        tangent = vec3(1, 0, 0);
        binormal = vec3(0, 0, -1);
    } else if(orig_normal.z > 0.5) {
        tangent = vec3(1, 0, 0);
        binormal = vec3(0, -1, 0);
    } else if(orig_normal.z < -0.5) {
        tangent = vec3(-1, 0, 0);
        binormal = vec3(0, -1, 0);
    }

    tangent = normalize(normal_matrix * tangent);
    binormal = normalize(normal_matrix * binormal);
    vec3 normal = normalize(normal_matrix * orig_normal);

    return mat3(tangent, binormal, normal);
}

#endif
