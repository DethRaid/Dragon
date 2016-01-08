#version 120

varying vec4 texcoord;

uniform sampler2D gcolor;


void convertToHDR(inout vec3 color) {
	float contrast = 1.05;

	vec3 overExposed = color / 4.0;
	vec3 normalExposed = color;
	vec3 underExposed = color * 2.0;

	color = mix(overExposed, underExposed, normalExposed);

	color = ((color - vec3(0.5)) * max(contrast, 0.0)) + 0.5;

}

void main() {

	vec3 color = texture2D(gcolor, texcoord.st).rgb;

	convertToHDR(color);
	
	color = clamp(color,0.0,1.0);


	gl_FragColor = vec4(color.rgb, 1.0);
}
