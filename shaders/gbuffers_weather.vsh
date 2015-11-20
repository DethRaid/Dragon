#version 120

/*

This code is from Chocapic13' shaders


*/

varying vec4 color;
varying vec3 fragpos;
varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;

attribute vec4 mc_midTexCoord;

varying vec3 sky1;
varying vec3 sky2;

varying vec3 nsunlight;

varying float SdotU;
varying float MdotU;
varying float sunVisibility;
varying float moonVisibility;
varying float skyMult;

varying vec4 texcoord;
varying vec4 lmcoord;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform int worldTime;
uniform int heldItemId;
uniform int heldBlockLightValue;
uniform float rainStrength;
uniform float wetness;
uniform ivec2 eyeBrightnessSmooth;
uniform float viewWidth;
uniform float viewHeight;

uniform vec3 cameraPosition;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform float frameTimeCounter;
const vec3 ToD[25] = vec3[25](vec3(200.0,110.0,65.0), //hour,r,g,b
								vec3(200.0,110.0,65.0),
								vec3(200.0,110.0,65.0),
								vec3(200.0,110.0,65.0),
								vec3(200.0,110.0,65.0),
								vec3(200.0,110.0,65.0),
								vec3(200.0,110.0,65.0),
								vec3(200.0,150.0,80.0),
								vec3(200.0,180.0,110.0),
								vec3(200.0,195.0,145.0),
								vec3(200.0,199.0,157.0),
								vec3(200.0,200.0,170.0),
								vec3(200.0,200.0,180.0),
								vec3(200.0,200.0,170.0),
								vec3(200.0,199.0,157.0),
								vec3(200.0,195.0,145.0),
								vec3(200.0,180.0,110.0),
								vec3(200.0,150.0,80.0),
								vec3(200.0,110.0,65.0),
								vec3(200.0,110.0,65.0),
								vec3(200.0,110.0,65.0),
								vec3(200.0,110.0,65.0),
								vec3(200.0,110.0,65.0),
								vec3(200.0,110.0,65.0),
								vec3(200.0,110.0,65.0));
const float PI48 = 150.796447372;
float pi2wt = PI48*frameTimeCounter;


vec3 calcWave(in vec3 pos, in float fm, in float mm, in float ma, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5) {

    float magnitude = sin(dot(vec4(pi2wt*fm, pos.x, pos.z, pos.y),vec4(0.5))) * mm + ma;
	vec3 d012 = sin(pi2wt*vec3(f0,f1,f2)*3.0);
	vec3 ret = sin(pi2wt*vec3(f3,f4,f5) + vec3(d012.x + d012.y,d012.y + d012.z,d012.z + d012.x) - pos) * magnitude;
	
    return ret;
}

vec3 calcMove(in vec3 pos, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5, in vec3 amp1, in vec3 amp2) {
    vec3 move1 = calcWave(pos      , 0.0054, 0.0400, 0.0400, 0.0127, 0.0089, 0.0114, 0.0063, 0.0224, 0.0015) * amp1;
	vec3 move2 = calcWave(pos+move1, 0.07, 0.0400, 0.0400, f0, f1, f2, f3, f4, f5) * amp2;
    return move1+move2;
}					
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	
	sunVec = normalize(sunPosition);
	moonVec = normalize(-sunPosition);
	upVec = normalize(upPosition);
	
	bool istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t;
	
	SdotU = dot(sunVec,upVec);
	MdotU = dot(moonVec,upVec);
	sunVisibility = pow(clamp(SdotU+0.15,0.0,0.15)/0.15,3.0);
	moonVisibility = pow(clamp(MdotU+0.15,0.0,0.15)/0.15,3.0);
	

float cosS = SdotU;
float mcosS = max(cosS*0.7+0.3,0.0);				


	const vec3 moonlight = vec3(0.5, 0.9, 1.4) * 0.001;
	
	float hour = worldTime/1000.0+6.0;
	float cmpH = mod(floor(hour),24.0);
	vec3 temp = ToD[int(cmpH)];
	vec3 temp2 = ToD[int(mod(floor(hour) + 1.0,24.0))];
	
	vec3 sunlight = mix(temp,temp2,fract(hour))/255.0;
	
	sunlight = pow(sunlight,vec3(2.2));
	const vec3 rainC = vec3(0.25,0.3,0.4);
	nsunlight = mix(sunlight,rainC*pow(sunlight,vec3(0.4))*0.035,rainStrength);
	
	vec3 sky_color = vec3(0.1, 0.35, 1.);
	sky_color = normalize(mix(sky_color,vec3(0.3,0.32,0.4)*length(sunlight),rainStrength)); //normalize colors in order to don't change luminance
	
	sky1 = sky_color;
	sky2 = mix(sky_color,mix(nsunlight,sky_color,rainStrength*0.7),1.0-mcosS);
	skyMult = max(SdotU*0.1+0.1,0.0)/0.2*(1.0-rainStrength*0.6);

	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
		vec3 worldpos = position.xyz + cameraPosition;
	if (!istopv) position.xz += vec2(3.0,1.0)+sin(frameTimeCounter)*sin(frameTimeCounter)*sin(frameTimeCounter)*vec2(2.1,0.6);
	position.xz -= (vec2(3.0,1.0)+sin(frameTimeCounter)*sin(frameTimeCounter)*sin(frameTimeCounter)*vec2(2.1,0.6))*0.5;
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;	
	
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	color = gl_Color;

	
	//gl_Position = ftransform();
	
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	

}