#line 2001

// From https://raw.githubusercontent.com/BruceKnowsHow/Ebin-Shaders/master/shaders/lib/Utility/Default/encoding.glsl

float Encode4x8F(in vec4 a) {
	uvec4 v = uvec4(round(clamp01(a) * 255.0)) << uvec4(0, 8, 16, 24);
	
	return uintBitsToFloat(sum4(v));
}

vec4 Decode4x8F(in float encodedbuffer) {
	uvec4 decode     = uvec4(floatBitsToUint(encodedbuffer));
	      decode.yzw = decode.yzw >> uvec3(8, 16, 24);
	      decode.xyz = decode.xyz & 255;
	
	return vec4(decode) / 255.0;
}

float Encode2x16F(in vec2 a) {
	uvec2 v = uvec2(round(clamp01(a) * 65535.0)) << uvec2(0, 16);
	
	return uintBitsToFloat(v.x + v.y);
}

vec2 Decode2x16(in float encodedbuffer) {
	uvec2 decode   = uvec2(floatBitsToUint(encodedbuffer));
	      decode.y = decode.y >> 16;
	      decode.x = decode.x & 65535;
	
	return vec2(decode) / 65535.0;
}

float Encode16(vec2 encodedBuffer) {
	cvec2 encode = vec2(1.0, exp2(8.0));
	
	encodedBuffer = round(encodedBuffer * 255.0);
	
	return dot(encodedBuffer, encode) / (exp2(16.0) - 1.0);
}

vec2 Decode16(float encodedBuffer) {
	cvec2 decode = 1.0 / (exp2(8.0) - 1.0) / vec2(1.0, exp2(8.0));
	
	vec2 decoded;
	
	encodedBuffer *= exp2(16.0) - 1.0;
	
	decoded.r = mod(encodedBuffer, exp2(8.0));
	decoded.g = encodedBuffer - decoded.r;
	
	return decoded * decode;
}

#define EncodeColor(color) powf(color, 1.0 / 2.2) // Prepares the color to be sent through a limited dynamic range pipeline
#define DecodeColor(color) powf(color, 2.2)

vec2 EncodeNormal(vec3 normal) {
    return vec2(normal.xy * inversesqrt(normal.z * 8.0 + 8.0) + 0.5);
}

vec3 DecodeNormal(vec2 encodedNormal) {
	encodedNormal = encodedNormal * 4.0 - 2.0;
	float f = length2(encodedNormal);
	float g = sqrt(1.0 - f * 0.25);
	return vec3(encodedNormal * g, 1.0 - f * 0.5);
}

float EncodeNormal(vec3 normal, cfloat bits) {
	normal    = clamp(normal, -1.0, 1.0);
	normal.xy = vec2(atan(normal.x, normal.z), acos(normal.y)) / PI;
	normal.x += 1.0;
	normal.xy = round(normal.xy * exp2(bits));
	
	return normal.x + normal.y * exp2(bits + 2.0);
}

vec3 DecodeNormal(float enc, cfloat bits) {
	vec4 normal;
	
	normal.y    = exp2(bits + 2.0) * floor(enc / exp2(bits + 2.0));
	normal.x    = enc - normal.y;
	normal.xy  /= exp2(vec2(bits, bits * 2.0 + 2.0));
	normal.x   -= 1.0;
	normal.xy  *= PI;
	normal.xwzy = vec4(sin(normal.xy), cos(normal.xy));
	normal.xz  *= normal.w;
	
	return normal.xyz;
}

float EncodeNormalU(vec3 normal) {
	normal = clamp(normal, -1.0, 1.0);
	normal.xy = vec2(atan(normal.x, normal.z), acos(normal.y)) / PI;
	normal.x += 1.0;
	normal.xy = round(normal.xy * 2048.0);
	normal.y = min(normal.y, 2047.0);
	
	uvec2 enc = uvec2(normal.xy);
	enc.x = enc.x & 4095;
	enc.y = enc.y << uint(12);
	
	return uintBitsToFloat(enc.x + enc.y);
}

float EncodeNormalU(vec3 normal, float water) {
	normal = clamp(normal, -1.0, 1.0);
	normal.xy = vec2(atan(normal.x, normal.z), acos(normal.y)) / PI;
	normal.x += 1.0;
	normal.xy = round(normal.xy * 2048.0);
	normal.y = min(normal.y, 2047.0);
	
	uvec3 enc = uvec3(normal.xy, water);
	enc.x = enc.x & 4095;
	enc.yz = enc.yz << uvec2(12, 24);
	
	return uintBitsToFloat(enc.x + enc.y + (1<<23) + enc.z);
}

float ReEncodeNormal(float enc, cfloat bits) {
	uvec2 e = uvec2(floatBitsToUint(enc));
	e.y = e.y >> 12;
	e.xy = e.xy & uvec2(4095, 2047);
	
	vec2 normal    = e.xy;
	     normal.xy = round(normal.xy / 2048.0 * exp2(bits));
	
	return normal.x + normal.y * exp2(bits + 2.0);
}

vec3 DecodeNormalU(float enc) {
	uvec3 e = uvec3(floatBitsToUint(enc));
	e.y = e.y >> 12;
	e.xy = e.xy & uvec2(4095, 2047);
	
	vec4 normal;
	
	normal.xy   = e.xy;
	normal.xy  /= 2048.0;
	normal.x   -= 1.0;
	normal.xy  *= PI;
	normal.xwzy = vec4(sin(normal.xy), cos(normal.xy));
	normal.xz  *= normal.w;
	
	return normal.xyz;
}

float DecodeWater(float enc) {
	return float(floatBitsToUint(enc) >> 24);
}
