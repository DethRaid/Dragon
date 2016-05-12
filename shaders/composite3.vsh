#version 120

#define REFLECTION_FILTER_SIZE 5

varying vec2 coord;

varying vec2 reflection_filter_coords[REFLECTION_FILTER_SIZE * REFLECTION_FILTER_SIZE];

void main() {
    gl_Position = ftransform();
    coord = gl_MultiTexCoord0.st;

    int offset = REFLECTION_FILTER_SIZE / 2;
    for(int y = 0; y < REFLECTION_FILTER_SIZE; y++) {
        for(int x = 0; x < REFLECTION_FILTER_SIZE; x++) {
            reflection_filter_coords[x + y * REFLECTION_FILTER_SIZE] = coord + vec2(x - offset, y - offset);
        }
    }
}
