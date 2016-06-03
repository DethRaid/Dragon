/*!
 * \brief Calculates the TBN matrix from gl_Normal
 */
mat3 calculate_tbn_matrix() {
    vec3 tangent = vec3(0);
    vec3 binormal = vec3(0);
    //We're working in a cube world. If one component of the normal is
    //greater than all the others, we know what direction the surface is
    //facing in
    if(gl_Normal.x > 0.5) {
        tangent = vec3(0, 0, -1);
        binormal = vec3(0, -1, 0);
    } else if(gl_Normal.x < -0.5) {
        tangent = vec3(0, 0, 1);
        binormal = vec3(0, -1, 0);
    } else if(gl_Normal.y > 0.5 ) {
        tangent = vec3(1, 0, 0);
        binormal = vec3(0, 0, 1);
    } else if(gl_Normal.y < -0.5) {
        tangent = vec3(1, 0, 0);
        binormal = vec3(0, 0, -1);
    } else if(gl_Normal.z > 0.5) {
        tangent = vec3(1, 0, 0);
        binormal = vec3(0, -1, 0);
    } else if(gl_Normal.z < -0.5) {
        tangent = vec3(-1, 0, 0);
        binormal = vec3(0, -1, 0);
    }

    tangent = normalize(gl_NormalMatrix * tangent);
    binormal = normalize(gl_NormalMatrix * binormal);
    vec3 normal = normalize(gl_NormalMatrix * gl_Normal);

    return mat3(tangent, binormal, normal);
}
