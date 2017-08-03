const float PI  = radians(180.0);
const float HPI = radians( 90.0);
const float TAU = radians(360.0);
const float RAD = radians(  1.0); // Degrees per radian
const float DEG = degrees(  1.0); // Radians per degree

//#define FREEZE_TIME
#ifdef FREEZE_TIME
	#define TIME 0.0
#else
	#define TIME frameTimeCounter
#endif

const vec4 swizzle = vec4(1.0, 0.0, -1.0, 0.5);

#define sum4(v) (((v).x + (v).y) + ((v).z + (v).w))

#define diagonal2(mat) vec2((mat)[0].x, (mat)[1].y)
#define diagonal3(mat) vec3((mat)[0].x, (mat)[1].y, mat[2].z)

#define transMAD(mat, v) (     mat3(mat) * (v) + (mat)[3].xyz)
#define  projMAD(mat, v) (diagonal3(mat) * (v) + (mat)[3].xyz)

#define textureRaw(samplr, coord) texelFetch(samplr, ivec2((coord) * vec2(viewWidth, viewHeight)), 0)
#define ScreenTex(samplr) texelFetch(samplr, ivec2(gl_FragCoord.st), 0)

#if !defined gbuffers_shadow
	#define cameraPos (cameraPosition + gbufferModelViewInverse[3].xyz)
#else
	#define cameraPos (cameraPosition)
#endif

#define rcp(x) (1.0 / (x))


#include "/lib/Utility/Default/pow.glsl"
#include "/lib/Utility/Default/lengthDotNormalize.glsl"
#include "/lib/Utility/Default/clamping.glsl"
#include "/lib/Utility/Default/encoding.glsl"


// Applies a subtle S-shaped curve, domain [0 to 1]
#define cubesmooth_(type) type cubesmooth(type x) { return (x * x) * (3.0 - 2.0 * x); }
DEFINE_genFType(cubesmooth_)

vec2 rotate(in vec2 vector, float radians) {
	return vector *= mat2(
		cos(radians), -sin(radians),
		sin(radians),  cos(radians));
}

vec2 clampScreen(vec2 coord, vec2 pixel) {
	return clamp(coord, pixel, 1.0 - pixel);
}

const vec3 lumaCoeff = vec3(0.2125, 0.7154, 0.0721);
vec3  SetSaturationLevel(vec3 color, float level) {
	color = clamp01(color);
	
	float luminance = dot(color, lumaCoeff);
	
	return mix(vec3(luminance), color, level);
}

vec3 hsv(vec3 c) {
	const vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 rgb(vec3 c) {
	const vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	
	return c.z * mix(K.xxx, clamp01(p - K.xxx), c.y);
}