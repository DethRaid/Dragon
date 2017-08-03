#line 4001

/*!
 * \brief Defines functions for use in generating the TSM matrix for use in shadowing
 */

struct Camera {
    mat4 worldspace_to_viewspace;   // Camera view matrix (I assume)
    mat4 viewspace_to_clipspace;   // Camera projection matrix (I assume)
    vec4 vt_vertices[8];
    vec4 vt_vertices_transformed[8];

    float f_left;
    float f_right;
    float f_bottom;
    float f_top;
    float f_near;
    float f_far;
    float fov_y;

    vec3 position;
    vec3 center;
    vec3 up;
    vec3 line_of_sight;

    bool projection_init;
}

void compute_tsm_matrix(mat4 N_T, Camera eye, Camera light, float tsm_distance, float percentage, int shadowmap_height) {
    Camera vis_eye = eye;
    set_far_plane_distance(vis_eye, tsm_distance);

    vec2 eye_trans[8];
    vec2 eye_vis_trans[8];

    mat4 l = light.viewspace_to_clipspace * light.worldspace_to_viewspace;

    for(int i = 0; i < 8; i++) {
        vec4 v = l * eye.vt_vertices_transformed[i];
        eye_trans[i].xy = v.xy / v.w;

        v = l * vis_eye.vt_vertices_transformed[i];
        eye_vis_trans[i].xy = v.xy / v.w;
    }
}