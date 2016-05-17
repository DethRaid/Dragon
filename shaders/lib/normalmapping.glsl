mat3 calculate_tbn_matrix(in vec3 normal) {
    vec3 tangent = vec3(0);
    vec3 binormal = vec3(0);
    //We're working in a cube world. If one component of the normal is
    //greater than all the others, we know what direction the surface is
    //facing in
    if(normal.x > 0.5) {
        face_id = 1.0;
        tangent = vec3(0, 0, -1);
        binormal = vec3(0, 1, 0);
    } else if(normal.x < -0.5) {
        face_id = 1.0;
        tangent = vec3(0, 0, 1);
        binormal = vec3(0, 1, 0);
    } else if(normal.y > 0.5 ) {
        face_id = 2.0;
        tangent = vec3(1, 0, 0);
        binormal = vec3(0, 0, 1);
    } else if(normal.y < -0.5) {
        face_id = 2.0;
        tangent = vec3(1, 0, 0);
        binormal = vec3(0, 0, -1);
    } else if(normal.z > 0.5) {
        face_id = 1.0;
        tangent = vec3(1, 0, 0);
        binormal = vec3(0, 1, 0);
    } else if(normal.z < -0.5) {
        face_id = 1.0;
        tangent = vec3(-1, 0, 0);
        binormal = vec3(0, 1, 0);
    }

    //binormal = cross(gl_Normal, tangent);

    tangent = normalize(gl_NormalMatrix * tangent);
    binormal = normalize(gl_NormalMatrix * binormal);

    return mat3(tangent, binormal, normal);
}
