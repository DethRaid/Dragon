#version 120

#define PI 3.14159

uniform float rainStrength;

uniform int worldTime;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float viewWidth;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

varying vec2 coord;
varying vec3 lightVector;
varying vec3 lightColor;

varying vec3 fogColor;
varying vec3 skyColor;

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

    skyColor = vec3(0.18867780436772762, 0.4978442963618773, 0.6616065586417131);

    main_light light = get_main_light(worldTime, sunPosition, moonPosition);

    if(rainStrength > 0.1) {
        //load up the rain fog profile
        fogColor = vec3(0.5, 0.5, 0.5);
        lightColor *= 0.3;
    }
    if(worldTime < 100 || worldTime > 13000) {
        fogColor = vec3(0.103, 0.103, 0.105);
        skyColor *= 0.0025;
    }

    lightVector = light.direction;
    lightColor = light.color;
}
