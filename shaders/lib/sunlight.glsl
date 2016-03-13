/*!
 * \brief Defines some functions to get the current light color and direction
 */

struct main_light {
    vec3 direction;
    vec3 color;
};

main_light get_main_light(in int world_time, in vec3 sun_position, in vec3 moon_position) {
    main_light light_params;

    if(world_time > 100 && world_time < 13000) {
        light_params.direction = normalize(sun_position);
        light_params.color = vec3(1, 0.98, 0.95) * 8.0;
    }
    if(world_time < 100 || world_time > 13000) {
        light_params.direction = normalize(moon_position);
        light_params.color = vec3(1, 0.98, 0.95) * 0.25;
    }

    return light_params
}
