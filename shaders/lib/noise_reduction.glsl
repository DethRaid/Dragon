#ifndef NOISE_REDUCTION_GLSL
#define NOISE_REDUCTION_GLSL

#include "/lib/space_conversion.glsl"

#line 3007

/*!
 * \brief A collection of function to impliment various ways to reduce noise
 */

/*! 
 * \brief Retrieves a dither value (0 - 1) from a 8x8 ordered dithering pattern (from Wikipedia)
 */
float get_dither_8x8(in vec2 coord) {
    const int[64] ditherPattern = int[64] ( 1, 49, 13, 61,  4, 52, 16, 64,
                                           33, 17, 45, 29, 36, 20, 48, 32,
                                            9, 57,  5, 53, 12, 60,  8, 56,
                                           41, 25, 37, 21, 44, 28, 40, 24,
                                            3, 51, 15, 63,  2, 50, 14, 62,
                                           35, 19, 47, 31, 34, 18, 46, 30,
                                           11, 59,  7, 55, 10, 58,  6, 54,
                                           43, 27, 39, 23, 42, 26, 38, 22);

    vec2 count = vec2(0.0f);
    count.x = floor(mod(coord.s * viewWidth, 8.0f));
    count.y = floor(mod(coord.t * viewHeight, 8.0f));

    int dither = ditherPattern[int(count.x) + int(count.y) * 8];

    return float(dither) / 64.0f;
}

#endif
