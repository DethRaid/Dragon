#version 120

uniform sampler2D texture;

varying vec4 color;
varying vec4 texcoord;

void main() {
	gl_FragData[0] = vec4(texture2D(texture, texcoord.st).rgb, texture2D(texture, texcoord.st).a * 1.0f) * color;
	gl_FragData[1] = vec4(1.0f, 0.0f, 1.0f, 0.51f);

	gl_FragData[2] = vec4(0.0f);
	gl_FragData[3] = vec4(0.0f);
}
