#version 120
varying vec4 color;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

uniform int fogMode;

void main() {

	//albedo
	gl_FragData[0] = color;
	//depth
	gl_FragData[1] = vec4(0.0f, 0.0f, 1.0f, 0.0f);

	gl_FragData[2] = vec4(0.0f, 0.0f, 0.0f, 0.0f);

	//matIDs, lightmap.r, lightma.b
	gl_FragData[3] = vec4(0.0f, 0.0f, 0.0f, 0.0f);

	if (fogMode == GL_EXP) {
		gl_FragData[0].rgb = mix(gl_FragData[0].rgb, (gl_Fog.color.rgb * 1.0), 1.0 - clamp(exp(-gl_Fog.density * gl_FogFragCoord), 0.0, 1.0));
	} else if (fogMode == GL_LINEAR) {
		gl_FragData[0].rgb = mix(gl_FragData[0].rgb, (gl_Fog.color.rgb * 1.0), clamp((gl_FogFragCoord - gl_Fog.start) * gl_Fog.scale, 0.0, 1.0));
	}
}
