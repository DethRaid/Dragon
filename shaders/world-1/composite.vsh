#version 120

varying vec4 texcoord;
varying float handItemLight;

uniform int heldItemId;
varying float eyeAdapt;

varying vec3 upVec;

uniform vec3 upPosition;

uniform ivec2 eyeBrightnessSmooth;
uniform mat4 gbufferModelView;

varying vec3 colorTorchlight;

uniform int worldTime;

void main() {
	gl_Position = ftransform();

	handItemLight = 0.0;
	if (heldItemId == 50) {
		// torch
		handItemLight = 0.5;
	}

	else if (heldItemId == 76 || heldItemId == 94) {
		// active redstone torch / redstone repeater
		handItemLight = 0.1;
	}

	else if (heldItemId == 89) {
		// lightstone
		handItemLight = 1.0;
	}

	else if (heldItemId == 10 || heldItemId == 11 || heldItemId == 51) {
		// lava / lava / fire
		handItemLight = 0.5;
	}

	else if (heldItemId == 91) {
		// jack-o-lantern
		handItemLight = 0.7;
	}

	else if (heldItemId == 327) {
		//lava bucket
		handItemLight = 1.5;
	}

		else if (heldItemId == 385) {
		//fire charger
		handItemLight = 0.2;
	}

		else if (heldItemId == 138) {
		//Beacon
		handItemLight = 1.0;
	}

		else if (heldItemId == 169) {
		//Sea lantern
		handItemLight = 1.0;
	}
	
	upVec = normalize(upPosition);

	vec3 wUp = (gbufferModelView * vec4(vec3(0.0,1.0,0.0),0.0)).rgb;
	vec3 wS1 = (gbufferModelView * vec4(normalize(vec3(3.5,1.0,3.5)),0.0)).rgb;
	vec3 wS2 = (gbufferModelView * vec4(normalize(vec3(-3.5,1.0,3.5)),0.0)).rgb;
	vec3 wS3 = (gbufferModelView * vec4(normalize(vec3(3.5,1.0,-3.5)),0.0)).rgb;
	vec3 wS4 = (gbufferModelView * vec4(normalize(vec3(-3.5,1.0,-3.5)),0.0)).rgb;

	eyeAdapt = 1.0;
	eyeAdapt = (2.0-min(length(((wUp) + (wS1) + (wS2) + (wS3) + (wS4))*2.)/sqrt(3.)*2.,eyeBrightnessSmooth.y/255.0*0.2));
	
		//Torchlight color
	float torchWhiteBalance = 0.02f;
	colorTorchlight = vec3(1.00f, 0.22f, 0.00f);
	colorTorchlight = mix(colorTorchlight, vec3(1.0f), vec3(torchWhiteBalance));

	colorTorchlight = pow(colorTorchlight, vec3(0.99f));

	texcoord = gl_MultiTexCoord0;
}
