#ifndef NOISE_GLSL
#define NOISE_GLSL

#line 6005

const int noiseTextureResolution = 64;

uniform sampler2D noisetex;

// From Ebin
float get3DNoise(vec3 pos) {
	vec3 part  = floor(pos);
	vec3 whole = fract(pos);

	vec2 zscale = vec2(17.0, 0.0);

	vec4 coord = part.xyxy + whole.xyxy + part.z * zscale.x + zscale.yyxx + 0.5;
	     coord /= noiseTextureResolution;

	float Noise1 = texture(noisetex, coord.xy).x;
	float Noise2 = texture(noisetex, coord.zw).x;

	return mix(Noise1, Noise2, whole.z);
}

#endif