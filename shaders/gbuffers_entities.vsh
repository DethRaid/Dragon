#version 120

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;


attribute vec4 mc_Entity;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

varying vec3 normal;

varying float distance;

varying mat3 tbnMatrix;

void main() {

	texcoord = gl_MultiTexCoord0;

	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

	vec4 viewpos = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	vec4 position = viewpos;

	vec4 locposition = gl_ModelViewMatrix * gl_Vertex;

	distance = sqrt(locposition.x * locposition.x + locposition.y * locposition.y + locposition.z * locposition.z);

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;

	color = gl_Color;

	gl_FogFragCoord = gl_Position.z;


	normal = normalize(gl_NormalMatrix * gl_Normal);

}
