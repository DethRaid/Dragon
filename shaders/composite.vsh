#version 450 compatibility

uniform float rainStrength;

uniform int worldTime;
uniform vec3 sunPosition;
uniform vec3 moonPosition;

out vec2 coord;
out vec3 lightVector;
out vec3 lightColor;

out vec3 fogColor;

struct main_light {
    vec3 direction;
    vec3 color;
};


main_light get_main_light(in int world_time, in vec3 sun_position, in vec3 moon_position) {
    main_light light_params;

    if(world_time < 12700 && world_time > 23250) {
        light_params.direction = normalize(sun_position);
        light_params.color = vec3(1.0, 0.98, 0.95) * 1000;
    } else {
        light_params.direction = normalize(moon_position);
        light_params.color = vec3(1.0);
    }

    return light_params;
}

void main() {
    gl_Position = ftransform();
    coord = gl_MultiTexCoord0.st;

    main_light light = get_main_light(worldTime, sunPosition, moonPosition);

    if(rainStrength > 0.1) {
        //load up the rain fog profile
        fogColor = vec3(0.5, 0.5, 0.5);
    } else {
        fogColor = vec3(1);
    }

    lightVector = light.direction;
    lightColor = light.color;
}
