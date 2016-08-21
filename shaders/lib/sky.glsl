#ifndef SKY_GLSL
#define SKY_GLSL

#include "/lib/space_conversion.glsl"

#line 4007

#define PI 3.14159265

vec2 get_sky_coord(in vec3 direction) {
    float lon = atan(direction.z, direction.x);
    if(direction.z < 0) {
        lon = 2 * PI - atan(-direction.z, direction.x);
    }

    float lat = acos(direction.y);

    const vec2 rads = vec2(1.0 / (PI * 2.0), 1.0 / PI);
    vec2 sphereCoords = vec2(lon, lat) * rads;
    sphereCoords.y = 1.0 - sphereCoords.y;

    return sphereCoords;
}

#endif
