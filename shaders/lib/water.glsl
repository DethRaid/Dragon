vec3 get_wave_displacement(in vec3 pos, in float steepness, in float amplitude, in vec2 direction, in float frequency, in float phase, in float frameTimeCounter) {
    float qa = steepness * amplitude;
    float dot_factor = dot(frequency * direction, pos.xz) + phase * frameTimeCounter;
    float cos_factor = cos(dot_factor) * qa;
    float x = direction.x * cos_factor;
    float z = direction.y * cos_factor;
    float y = amplitude * sin(dot_factor);

    return vec3(x, y, z);
}

vec3 get_wave_normal(in vec3 pos, in float steepness, in float amplitude, in vec2 direction, in float frequency, in float phase, in float frameTimeCounter) {
    float c = cos(frequency * dot(direction, pos.xz) + phase * frameTimeCounter);
    float s = cos(frequency * dot(direction, pos.xz) + phase * frameTimeCounter);
    float wa = frequency * amplitude;

    float x = direction.x * wa * c;
    float z = direction.y * wa * c;
    float y = steepness * wa * s;

    return vec3(x, y, z);
}

void do_water_vertex_simulation(in vec3 world_position)
