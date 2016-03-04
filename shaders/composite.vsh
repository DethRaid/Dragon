#version 450 compatibility

#define VERTEX_SCALE 0.5

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelViewInverse;

uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform vec3 previousCameraPosition;

uniform float rainStrength;
uniform float sunAngle;
uniform float far;

out vec3 lightVector;

out vec2 texcoord;

out float fogEnabled;

const float sunPathRotation = -40.0;


void main() {
	texcoord = gl_MultiTexCoord0.st;
	gl_Position		= ftransform();

	gl_Position.xy = ((gl_Position.xy * 0.5 + 0.5) * VERTEX_SCALE) * 2.0 - 1.0;

	fogEnabled = float(gl_Fog.start / far < 0.65);
}
