#version 120

#define WAVING_WATER

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 worldPosition;
varying vec4 vertexPos;

uniform float rainStrength;

varying vec3 normal;
varying vec3 globalNormal;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 viewVector;
varying float distance;

uniform float frameTimeCounter;
attribute vec4 mc_Entity;

varying float iswater;
varying float isice;

const float PI = 3.1415927;

void main() {
	iswater = 0.0f;
	isice = 0.0f;

	if (mc_Entity.x == 79) {
		isice = 1.0f;
	}

	if (mc_Entity.x == 95 || mc_Entity.x == 160) {
		isice = 0.5f;
	}

	if (mc_Entity.x == 1971.0f) {
		iswater = 1.0f;
	}

	if (mc_Entity.x == 8 || mc_Entity.x == 9) {
		iswater = 1.0f;
	}

	vec4 positions = gl_ModelViewMatrix * gl_Vertex;
	float displacement = 0.0;

	vec4 viewposition = gbufferModelViewInverse * positions;
	vec3 worldpos = viewposition.xyz + cameraPosition;

	if(mc_Entity.x == 8.0 || mc_Entity.x == 9.0) {
		iswater = 1.0;
		float fy = fract(worldpos.y + 0.001);

		#ifdef WAVING_WATER
			float wave = 0.05 * sin(2 * PI * (frameTimeCounter*0.75 - worldpos.x /  7.0 - worldpos.z / 13.0))
                 + 0.05 * sin(2 * PI * (frameTimeCounter*0.6 - worldpos.x / 11.0 - worldpos.z /  5.0));
			displacement = clamp(wave, -fy, 1.0-fy);
			viewposition.y += displacement * 1.0;
			viewposition.y += displacement * 1.8 * rainStrength;
		#endif
	}

	vec4 viewPos = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	vec4 position = viewPos;

	viewposition = gbufferModelView * viewposition;
	worldPosition.xyz = viewPos.xyz + cameraPosition.xyz;


	gl_Position = gl_ProjectionMatrix * (gbufferModelView * position);
	gl_Position += gl_ProjectionMatrix * viewposition;

	color = gl_Color;
	vertexPos = gl_Vertex;

	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

	gl_FogFragCoord = gl_Position.z;

	normal = normalize(gl_NormalMatrix * gl_Normal);
	globalNormal = normalize(gl_Normal);

	if (gl_Normal.x > 0.5) {
		//  1.0,  0.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0, -1.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.x < -0.5) {
		// -1.0,  0.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.y > 0.5) {
		//  0.0,  1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	} else if (gl_Normal.y < -0.5) {
		//  0.0, -1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	} else if (gl_Normal.z > 0.5) {
		//  0.0,  0.0,  1.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.z < -0.5) {
		//  0.0,  0.0, -1.0
		tangent  = normalize(gl_NormalMatrix * vec3(-1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	}

	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
		 										tangent.y, binormal.y, normal.y,
												tangent.z, binormal.z, normal.z);

	viewVector = (gl_ModelViewMatrix * gl_Vertex).xyz;
	viewVector = normalize(tbnMatrix * viewVector);
}
