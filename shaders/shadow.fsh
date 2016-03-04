#version 120

uniform sampler2D tex;

varying vec4 texcoord;
varying vec4 color;
varying vec3 normal;

varying float materialIDs;
varying float iswater;

void main() {

	vec4 tex = texture2D(tex, texcoord.st, 0) * color;

	if (iswater > 0.5) {
		vec4 albedo = tex;
		float lum = albedo.r + albedo.g + albedo.b;
		lum /= 3.0f;

		lum = pow(lum, 1.0f) * 1.0f;
		lum += 0.0f;

		vec3 waterColor = color.rgb;

		waterColor = normalize(waterColor);

		tex = vec4(0.1f, 0.7f, 1.0f, 210.0f/255.0f);
		tex.rgb *= 0.4f * waterColor.rgb;
		tex.rgb *= vec3(lum);
	}

	float NdotL = pow(max(0.0f, mix(dot(normal.rgb, vec3(0.0f, 0.0f, 1.0f)), 1.0f, 0.0f)), 1.0f / 2.2f);

	vec3 toLight = normal.xyz;

	vec3 shadowNormal = normal.xyz;

	bool isTranslucent = abs(materialIDs - 3.0f) < 0.1f || abs(materialIDs - 4.0f) < 0.1f;

	if (isTranslucent) {
		shadowNormal = vec3(0.0f, 0.0f, 0.0f);
		NdotL = 1.0f;
	}

	bool isGlassFix = abs(materialIDs - 89114.0f) < 0.1f;

	if (isGlassFix) {
		discard;
	}

	gl_FragData[0] = vec4(tex.rgb, tex.a);
	gl_FragData[1] = vec4(shadowNormal.xyz * 0.5 + 0.5, 1.0f);
}
